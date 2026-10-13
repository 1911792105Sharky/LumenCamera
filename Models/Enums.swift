//
//  Models/Enums.swift
//  LumenCamera
//
//  全局枚举与常量定义
//

import Foundation
import UIKit

// MARK: - 相机模式
enum CameraMode: String, CaseIterable, Identifiable {
    case photo = "拍照"
    case video = "录像"
    var id: String { rawValue }
}

// MARK: - 摄像头位置
enum CameraPosition {
    case front
    case back
}

// MARK: - 闪光灯模式
enum FlashMode: String, CaseIterable, Identifiable {
    case off = "关闭"
    case on = "打开"
    case auto = "自动"
    case torch = "常亮"
    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        case .torch: return "flashlight.on.fill"
        }
    }
}

// MARK: - 裁剪比例
enum CropAspectRatio: String, CaseIterable, Identifiable {
    case free = "自由"
    case square = "1:1"
    case fourThree = "4:3"
    case threeTwo = "3:2"
    case sixteenNine = "16:9"

    var id: String { rawValue }

    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .square: return 1.0
        case .fourThree: return 4.0 / 3.0
        case .threeTwo: return 3.0 / 2.0
        case .sixteenNine: return 16.0 / 9.0
        }
    }
}

// MARK: - 编辑工具分类
enum EditorTool: String, CaseIterable, Identifiable {
    case crop = "裁剪"
    case adjust = "调整"
    case filter = "滤镜"
    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .crop: return "crop"
        case .adjust: return "slider.horizontal.3"
        case .filter: return "camera.filters"
        }
    }
}

// MARK: - 调整参数项
enum AdjustmentParameter: String, CaseIterable, Identifiable {
    case exposure = "曝光"
    case contrast = "对比度"
    case saturation = "饱和度"
    case warmth = "色温"
    case sharpness = "锐度"

    var id: String { rawValue }

    /// 默认值（中性值：contrast/saturation 为 1.0，其余为 0）
    var defaultValue: Float {
        switch self {
        case .exposure: return 0
        case .contrast: return 1.0
        case .saturation: return 1.0
        case .warmth: return 0
        case .sharpness: return 0
        }
    }
    /// 取值范围
    var range: ClosedRange<Float> {
        switch self {
        case .exposure: return -1.0...1.0
        case .contrast: return 0.0...2.0
        case .saturation: return 0.0...2.0
        case .warmth: return -100...100
        case .sharpness: return 0.0...1.0
        }
    }
}
