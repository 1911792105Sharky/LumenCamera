//
//  Services/Camera/CameraEngine.swift
//  LumenCamera
//
//  相机引擎：封装 AVCaptureSession，提供拍照、录像、前后切换、闪光灯、对焦、缩放
//  实时预览通过 AVCaptureVideoDataOutput 回调输出 CIImage，供上层应用滤镜后显示
//

import Foundation
import AVFoundation
import UIKit
import Photos
import CoreImage

/// 相机引擎状态
enum CameraEngineState {
    case idle
    case running
    case takingPhoto
    case recording
    case error(Error)
}

/// 相机引擎
final class CameraEngine: NSObject, ObservableObject {

    // MARK: - 公开状态
    @Published private(set) var state: CameraEngineState = .idle
    @Published var mode: CameraMode = .photo
    @Published var position: CameraPosition = .back
    @Published var flashMode: FlashMode = .off
    @Published var isRecording: Bool = false
    @Published var capturedPhoto: UIImage?

    /// 预览帧回调（处理前的原始 CIImage），由上层（FilterEngine）应用滤镜
    var onPreviewFrame: ((CIImage) -> Void)?

    // MARK: - 私有属性
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.lumencamera.sessionQueue")
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?

    /// 照片输出
    private let photoOutput = AVCapturePhotoOutput()
    /// 视频文件输出（录像）
    private let movieFileOutput = AVCaptureMovieFileOutput()
    /// 视频数据输出（实时预览帧，供滤镜处理）
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataQueue = DispatchQueue(label: "com.lumencamera.videoDataQueue")

    /// Core Image 上下文（用于拍照时渲染，预览渲染交由 UI 层 Metal 视图）
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// 当前缩放因子
    private var currentZoomFactor: CGFloat = 1.0

    // MARK: - 生命周期

    /// 配置并启动 session
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSessionIfNeeded()
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.state = .running
                }
            }
        }
    }

    /// 停止 session
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.state = .idle
                }
            }
        }
    }

    // MARK: - Session 配置

    private func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // 视频输入
        do {
            let videoDevice = Self.captureDevice(for: position)
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                videoDeviceInput = videoInput
            }
        } catch {
            DispatchQueue.main.async { self.state = .error(error) }
            session.commitConfiguration()
            return
        }

        // 音频输入
        do {
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    audioDeviceInput = audioInput
                }
            }
        } catch {
            // 音频失败不阻塞相机
            print("Audio input error: \(error)")
        }

        // 照片输出
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        }

        // 录像输出
        if session.canAddOutput(movieFileOutput) {
            session.addOutput(movieFileOutput)
        }

        // 视频数据输出（用于实时滤镜预览）
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
                connection.isVideoMirrored = (position == .front)
            }
        }

        session.commitConfiguration()
    }

    // MARK: - 获取摄像头设备

    private static func captureDevice(for position: CameraPosition) -> AVCaptureDevice {
        let avPosition: AVCaptureDevice.Position = (position == .back) ? .back : .front
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInDualCamera,
            .builtInTrueDepthCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: avPosition
        )
        return discovery.devices.first ?? AVCaptureDevice.default(for: .video)!
    }

    // MARK: - 拍照

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async { self.state = .takingPhoto }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = self.avFlashMode()
            if let previewType = settings.availablePreviewPhotoPixelFormatTypes.first {
                settings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey as String: previewType
                ]
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func avFlashMode() -> AVCaptureDevice.FlashMode {
        switch flashMode {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        case .torch: return .off // 常亮模式拍照不闪光
        }
    }

    // MARK: - 录像

    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self, !self.movieFileOutput.isRecording else { return }
            let connection = self.movieFileOutput.connection(with: .video)
            connection?.videoOrientation = .portrait
            connection?.isVideoMirrored = (self.position == .front)

            let url = Self.temporaryMovieURL()
            self.movieFileOutput.startRecording(to: url, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
                self.state = .recording
            }
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.movieFileOutput.isRecording else { return }
            self.movieFileOutput.stopRecording()
        }
    }

    private static func temporaryMovieURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        let name = UUID().uuidString + ".mov"
        return dir.appendingPathComponent(name)
    }

    // MARK: - 前后摄像头切换

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let newPosition: CameraPosition = (self.position == .back) ? .front : .back
            guard let currentInput = self.videoDeviceInput else { return }

            self.session.beginConfiguration()
            self.session.removeInput(currentInput)

            do {
                let newDevice = Self.captureDevice(for: newPosition)
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoDeviceInput = newInput
                    DispatchQueue.main.async { self.position = newPosition }
                } else {
                    self.session.addInput(currentInput)
                }
            } catch {
                self.session.addInput(currentInput)
                print("Switch camera error: \(error)")
            }

            // 更新视频数据输出方向与镜像
            if let connection = self.videoDataOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
                connection.isVideoMirrored = (newPosition == .front)
            }

            self.session.commitConfiguration()
        }
    }

    // MARK: - 闪光灯 / 手电筒

    func toggleFlash() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let modes: [FlashMode] = [.off, .on, .auto, .torch]
            guard let idx = modes.firstIndex(of: self.flashMode) else { return }
            let next = modes[(idx + 1) % modes.count]
            DispatchQueue.main.async { self.flashMode = next }

            // 手电筒（持续亮）
            if let device = self.videoDeviceInput?.device,
               device.hasTorch, device.isTorchAvailable {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = (next == .torch) ? .on : .off
                    device.unlockForConfiguration()
                } catch {
                    print("Torch error: \(error)")
                }
            }
        }
    }

    // MARK: - 对焦与曝光

    func focusAndExpose(at pointInPreview: CGPoint, in previewSize: CGSize) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            // 将预览坐标转换为设备坐标
            let devicePoint = CGPoint(
                x: pointInPreview.y / previewSize.height,
                y: 1.0 - pointInPreview.x / previewSize.width
            )
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                print("Focus error: \(error)")
            }
        }
    }

    // MARK: - 缩放

    func zoom(to factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoDeviceInput?.device else { return }
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = device.maxAvailableVideoZoomFactor
            let clamped = max(minZoom, min(maxZoom, factor))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                self.currentZoomFactor = clamped
            } catch {
                print("Zoom error: \(error)")
            }
        }
    }

    func zoomBy(delta: CGFloat) {
        zoom(to: currentZoomFactor * delta)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate（实时预览帧）

extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // 回调到主线程由上层处理
        DispatchQueue.main.async { [weak self] in
            self?.onPreviewFrame?(ciImage)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate（拍照）

extension CameraEngine: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            print("Photo capture error: \(error)")
            DispatchQueue.main.async { self.state = .running }
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.state = .running }
            return
        }
        // 修正方向
        let orientedImage = Self.fixOrientation(image, position: position)
        // 保存原图到相册（满足 AC-2）
        PhotoLibraryManager.saveImage(orientedImage)
        DispatchQueue.main.async {
            self.capturedPhoto = orientedImage
            self.state = .running
        }
    }

    private static func fixOrientation(_ image: UIImage, position: CameraPosition) -> UIImage {
        // 前置摄像头需要镜像
        if position == .front {
            return image.withHorizontallyFlippedOrientation()
        }
        return image
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate（录像保存）

extension CameraEngine: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if let error {
            print("Recording error: \(error)")
            DispatchQueue.main.async {
                self.isRecording = false
                self.state = .running
            }
            return
        }
        // 保存到相册
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            }) { _, _ in
                // 清理临时文件
                try? FileManager.default.removeItem(at: outputFileURL)
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.state = .running
                }
            }
        }
    }
}
