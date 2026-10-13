//
//  Views/Camera/CameraView.swift
//  LumenCamera
//
//  相机主界面：预览、滤镜选择条、快门/录制、模式切换、前后摄像头、闪光灯
//

import SwiftUI

struct CameraView: View {

    @StateObject private var camera = CameraEngine()
    @StateObject private var filterEngine = FilterEngine()

    /// 拍照完成后的回调（传递照片给编辑页）
    var onPhotoCaptured: ((UIImage) -> Void)?

    @State private var showEditor = false
    @State private var capturedImage: UIImage?
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 预览层
                CameraPreviewView(camera: camera, filterEngine: filterEngine)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { event in
                                camera.focusAndExpose(at: event.location, in: geo.size)
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                camera.zoomBy(delta: delta)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            }
                    )

                // 顶部控制栏
                VStack {
                    topBar
                    Spacer()

                    // 底部控制区
                    VStack(spacing: 16) {
                        filterStrip
                        bottomControls
                    }
                    .padding(.bottom, 24)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .background(Color.black)
        }
        .onAppear { camera.startSession() }
        .onDisappear { camera.stopSession() }
        .onChange(of: camera.capturedPhoto) { newPhoto in
            if let photo = newPhoto {
                // 应用当前滤镜后传递给编辑页
                if let ci = FilterEngine.ciImage(from: photo) {
                    let filtered = filterEngine.apply(to: ci)
                    if let final = filterEngine.renderUIImage(from: filtered) {
                        capturedImage = final
                        showEditor = true
                    } else {
                        capturedImage = photo
                        showEditor = true
                    }
                } else {
                    capturedImage = photo
                    showEditor = true
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let image = capturedImage {
                EditorView(image: image)
            }
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            // 闪光灯
            Button {
                camera.toggleFlash()
            } label: {
                Image(systemName: camera.flashMode.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(camera.flashMode == .off ? .white : .yellow)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // 模式切换
            Picker("模式", selection: $camera.mode) {
                Text("拍照").tag(CameraMode.photo)
                Text("录像").tag(CameraMode.video)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Spacer()

            // 前后摄像头切换
            Button {
                camera.switchCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - 滤镜选择条

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(filterEngine.availableFilters.enumerated()), id: \.offset) { index, filter in
                    filterThumbnail(filter: filter, index: index)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterThumbnail(filter: FilterProtocol, index: Int) -> some View {
        let isSelected = filterEngine.currentFilter.identifier == filter.identifier
        return VStack(spacing: 4) {
            Circle()
                .fill(isSelected ? Color.white : Color.white.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(filter.name)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
        }
        .frame(width: 56)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
        )
        .onTapGesture {
            filterEngine.selectFilter(at: index)
        }
    }

    // MARK: - 底部控制栏

    private var bottomControls: some View {
        HStack {
            // 滤镜强度滑块（仅在非原图时显示）
            if filterEngine.currentFilter.identifier != "none" {
                VStack(spacing: 4) {
                    Text("强度")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                    Slider(value: $filterEngine.intensity, in: 0...1)
                        .tint(.white)
                        .frame(width: 120)
                }
                .transition(.opacity)
            } else {
                Spacer().frame(width: 120)
            }

            Spacer()

            // 快门 / 录制按钮
            shutterButton

            Spacer()

            // 右侧占位保持对称
            Color.clear.frame(width: 120)
        }
        .padding(.horizontal, 20)
    }

    private var shutterButton: some View {
        Button {
            switch camera.mode {
            case .photo:
                camera.capturePhoto()
            case .video:
                if camera.isRecording {
                    camera.stopRecording()
                } else {
                    camera.startRecording()
                }
            }
        } label: {
            ZStack {
                if camera.mode == .video {
                    // 录像模式
                    if camera.isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.red)
                            .frame(width: 56, height: 56)
                    } else {
                        Circle()
                            .stroke(.red, lineWidth: 4)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle().fill(.red).frame(width: 58, height: 58)
                            )
                    }
                } else {
                    // 拍照模式
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle().fill(.white).frame(width: 60, height: 60)
                        )
                }
            }
        }
    }
}
