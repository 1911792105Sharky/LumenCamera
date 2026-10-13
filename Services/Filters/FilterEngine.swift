//
//  Services/Filters/FilterEngine.swift
//  LumenCamera
//
//  滤镜引擎：管理当前选中的滤镜与强度，提供统一的应用入口。
//  支持滤镜列表的动态注册，新增滤镜无需修改本类。
//

import Foundation
import CoreImage
import UIKit
import Metal

/// 滤镜引擎
final class FilterEngine: ObservableObject {

    /// 所有可用滤镜（按注册顺序）
    @Published private(set) var availableFilters: [FilterProtocol]

    /// 当前选中的滤镜
    @Published var currentFilter: FilterProtocol {
        didSet { objectWillChange.send() }
    }

    /// 当前滤镜强度 0.0 ~ 1.0
    @Published var intensity: Float = 1.0 {
        didSet { objectWillChange.send() }
    }

    /// Core Image 上下文（基于 Metal，高性能）
    private let ciContext: CIContext

    init() {
        // 注册所有内置滤镜
        let filters: [FilterProtocol] = [
            NoneFilter(),
            FilmFilter(),
            SoftGlowFilter(),
            SoftFocusFilter(),
            CineBloomFilter(),
            MonoFilter(),
            VintageFilter(),
            CoolFilter()
        ]
        self.availableFilters = filters
        self.currentFilter = filters[0]

        // 使用 Metal 设备创建 CIContext，无 Metal 时回退到默认
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: metalDevice,
                                       options: [.useSoftwareRenderer: false])
        } else {
            self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
        }
    }

    /// 选中指定索引的滤镜
    func selectFilter(at index: Int) {
        guard index >= 0, index < availableFilters.count else { return }
        currentFilter = availableFilters[index]
    }

    /// 注册新滤镜（运行时扩展，无需修改核心代码）
    func register(_ filter: FilterProtocol) {
        // 避免重复注册
        guard !availableFilters.contains(where: { $0.identifier == filter.identifier }) else { return }
        availableFilters.append(filter)
    }

    /// 将当前滤镜应用到 CIImage
    func apply(to image: CIImage) -> CIImage {
        currentFilter.apply(to: image, intensity: intensity)
    }

    // MARK: - 渲染工具

    /// 将 CIImage 渲染为 UIImage
    func renderUIImage(from image: CIImage, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let extent = image.extent.integral
        guard let cgImage = ciContext.createCGImage(image, from: extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    /// 将 UIImage 转为 CIImage
    static func ciImage(from uiImage: UIImage) -> CIImage? {
        if let cgImage = uiImage.cgImage {
            return CIImage(cgImage: cgImage)
        }
        if let ciImage = uiImage.ciImage {
            return ciImage
        }
        return nil
    }
}
