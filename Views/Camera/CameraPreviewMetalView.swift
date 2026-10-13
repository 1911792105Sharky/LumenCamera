//
//  Views/Camera/CameraPreviewMetalView.swift
//  LumenCamera
//
//  基于 Metal 的实时预览视图，接收滤镜处理后的 CIImage 并渲染
//

import SwiftUI
import MetalKit
import CoreImage

/// Metal 预览视图（UIKit）
final class CameraPreviewMetalView: MTKView {

    private let ciContext: CIContext
    private let commandQueue: MTLCommandQueue
    private var currentImage: CIImage?

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        let metalDevice = device ?? MTLCreateSystemDefaultDevice()
        let resolvedDevice = metalDevice ?? MTLCreateSystemDefaultDevice()!
        self.ciContext = CIContext(mtlDevice: resolvedDevice)
        self.commandQueue = resolvedDevice.makeCommandQueue()!
        super.init(frame: frameRect, device: metalDevice)
        self.framebufferOnly = false
        self.enableSetNeedsDisplay = true
        self.isPaused = true
        self.delegate = self
    }

    required init(coder: NSCoder) {
        let metalDevice = MTLCreateSystemDefaultDevice()!
        self.ciContext = CIContext(mtlDevice: metalDevice)
        self.commandQueue = metalDevice.makeCommandQueue()!
        super.init(coder: coder)
        self.device = metalDevice
        self.framebufferOnly = false
        self.enableSetNeedsDisplay = true
        self.isPaused = true
        self.delegate = self
    }

    /// 更新要显示的图像
    func update(image: CIImage) {
        currentImage = image
        draw()
    }
}

// MARK: - MTKViewDelegate

extension CameraPreviewMetalView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let image = currentImage,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        let drawableSize = drawableSize
        // 将图像缩放到视图大小并居中（保持比例）
        let scaleX = drawableSize.width / image.extent.width
        let scaleY = drawableSize.height / image.extent.height
        let scale = max(scaleX, scaleY) // 填满（类似 resizeAspectFill）
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let drawableRect = CGRect(origin: .zero, size: drawableSize)
        let originX = (drawableRect.width - scaled.extent.width) / 2
        let originY = (drawableRect.height - scaled.extent.height) / 2
        let positioned = scaled.transformed(by: CGAffineTransform(translationX: originX, y: originY))

        ciContext.render(positioned,
                         to: drawable.texture,
                         commandBuffer: commandBuffer,
                         bounds: drawableRect,
                         colorSpace: CGColorSpaceCreateDeviceRGB())
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - SwiftUI 包装

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var camera: CameraEngine
    @ObservedObject var filterEngine: FilterEngine

    func makeUIView(context: Context) -> CameraPreviewMetalView {
        let view = CameraPreviewMetalView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        // 设置预览帧回调：接收原始 CIImage → 应用滤镜 → 渲染
        camera.onPreviewFrame = { [weak filterEngine, weak view] image in
            guard let filterEngine else { return }
            let filtered = filterEngine.apply(to: image)
            view?.update(image: filtered)
        }
        return view
    }

    func updateUIView(_ uiView: CameraPreviewMetalView, context: Context) {}
}
