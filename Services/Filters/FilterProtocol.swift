//
//  Services/Filters/FilterProtocol.swift
//  LumenCamera
//
//  滤镜协议：所有滤镜均实现此协议，便于扩展。新增滤镜只需实现此协议，无需修改核心逻辑。
//

import Foundation
import CoreImage

/// 滤镜协议
protocol FilterProtocol: AnyObject {
    /// 唯一标识符
    var identifier: String { get }
    /// 显示名称
    var name: String { get }

    /// 将滤镜应用到 CIImage
    /// - Parameters:
    ///   - image: 输入图像
    ///   - intensity: 强度 0.0 ~ 1.0，0.0 表示无效果，1.0 表示完整效果
    /// - Returns: 处理后的 CIImage
    func apply(to image: CIImage, intensity: Float) -> CIImage
}

extension FilterProtocol {
    /// 默认强度为 1.0 的便捷方法
    func apply(to image: CIImage) -> CIImage {
        apply(to: image, intensity: 1.0)
    }
}
