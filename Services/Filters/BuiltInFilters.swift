//
//  Services/Filters/BuiltInFilters.swift
//  LumenCamera
//
//  8 种内置滤镜实现：原图、胶片、柔光、柔焦、CineBloom、黑白、复古、冷色
//  所有滤镜均实现 FilterProtocol，并支持 intensity（0~1）强度调节
//

import Foundation
import CoreImage

// MARK: - 强度混合辅助

extension FilterProtocol {
    /// 将原图与处理后的图像按强度混合
    /// - Parameters:
    ///   - original: 原图
    ///   - processed: 应用完整效果后的图
    ///   - intensity: 强度 0~1
    func blend(original: CIImage, processed: CIImage, intensity: Float) -> CIImage {
        guard intensity < 1.0 else { return processed }
        guard intensity > 0 else { return original }
        // CIMix 通过 inputAmount 控制两张图的混合比例
        if let mix = CIFilter(name: "CIMix", parameters: [
            kCIInputImageKey: processed,
            kCIInputBackgroundImageKey: original,
            kCIInputAmountKey: intensity
        ]), let output = mix.outputImage {
            return output.cropped(to: original.extent)
        }
        return processed
    }
}

// MARK: - 1. 原图

final class NoneFilter: FilterProtocol {
    let identifier = "none"
    let name = "原图"
    func apply(to image: CIImage, intensity: Float) -> CIImage { image }
}

// MARK: - 2. 胶片感 Film

final class FilmFilter: FilterProtocol {
    let identifier = "film"
    let name = "胶片"

    func apply(to image: CIImage, intensity: Float) -> CIImage {
        // 胶片效果：提高对比度、降低饱和度、添加暖色倾向
        var result = image

        // CIPhotoEffectProcess 提供类似胶片的色调
        if let photoEffect = CIFilter(name: "CIPhotoEffectProcess", parameters: [
            kCIInputImageKey: image
        ]), let output = photoEffect.outputImage {
            result = output
        }

        // 降低饱和度，增加对比度
        if let controls = CIFilter(name: "CIColorControls", parameters: [
            kCIInputImageKey: result,
            kCIInputSaturationKey: 0.85,
            kCIInputContrastKey: 1.15
        ]), let output = controls.outputImage {
            result = output
        }

        return blend(original: image, processed: result, intensity: intensity)
    }
}

// MARK: - 3. 柔光 Soft Glow

final class SoftGlowFilter: FilterProtocol {
    let identifier = "softglow"
    let name = "柔光"

    func apply(to image: CIImage, intensity: Float) -> CIImage {
        // 柔光：对图像高斯模糊后与原图以 "屏幕" 方式混合，产生柔和发光
        guard let blur = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: image,
            kCIInputRadiusKey: 12
        ]), let blurred = blur.outputImage?.cropped(to: image.extent) else {
            return image
        }
        // 屏幕混合：result = 1 - (1 - a) * (1 - b)
        guard let blendFilter = CIFilter(name: "CIScreenBlendMode", parameters: [
            kCIInputImageKey: blurred,
            kCIInputBackgroundImageKey: image
        ]), let output = blendFilter.outputImage else {
            return image
        }
        return blend(original: image, processed: output, intensity: intensity)
    }
}

// MARK: - 4. 柔焦 Soft Focus

final class SoftFocusFilter: FilterProtocol {
    let identifier = "softfocus"
    let name = "柔焦"

    func apply(to image: CIImage, intensity: Float) -> CIImage {
        // 柔焦：轻微模糊后与原图半透明混合，模拟柔焦镜头
        guard let blur = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: image,
            kCIInputRadiusKey: 4
        ]), let blurred = blur.outputImage?.cropped(to: image.extent) else {
            return image
        }
        // 以一定不透明度叠加模糊层
        guard let overlay = CIFilter(name: "CISourceOverCompositing", parameters: [
            kCIInputImageKey: blurred,
            kCIInputBackgroundImageKey: image
        ]) else {
            return image
        }
        // 调整模糊层的不透明度
        guard let opacity = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: blurred,
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.5)
        ]), let opacityOutput = opacity.outputImage else {
            return image
        }
        overlay.setValue(opacityOutput, forKey: kCIInputImageKey)
        guard let output = overlay.outputImage else { return image }
        return blend(original: image, processed: output, intensity: intensity)
    }
}

// MARK: - 5. CineBloom

final class CineBloomFilter: FilterProtocol {
    let identifier = "cinebloom"
    let name = "CineBloom"

    func apply(to image: CIImage, intensity: Float) -> CIImage {
        // CineBloom：提取高光区域，模糊后与原图屏幕混合，产生电影感光晕
        // 1. 提取高光（亮度阈值）
        guard let threshold = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: image,
            "inputRVector": CIVector(x: 0.3, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0.59, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0.11, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]), let luminance = threshold.outputImage else {
            return image
        }
        // 2. 用 CIColorCube 或简单方式：提高高光，压暗非高光
        // 使用 CIGammaAdjust 提亮，再用 CIColorControls 提升亮度
        guard let gamma = CIFilter(name: "CIGammaAdjust", parameters: [
            kCIInputImageKey: luminance,
            "inputPower": 0.3
        ]), let highlit = gamma.outputImage else { return image }

        // 3. 模糊高光
        guard let blur = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: highlit,
            kCIInputRadiusKey: 20
        ]), let blurred = blur.outputImage?.cropped(to: image.extent) else {
            return image
        }

        // 4. 屏幕混合到原图
        guard let blendFilter = CIFilter(name: "CIScreenBlendMode", parameters: [
            kCIInputImageKey: blurred,
            kCIInputBackgroundImageKey: image
        ]), let output = blendFilter.outputImage else {
            return image
        }
        return blend(original: image, processed: output, intensity: intensity)
    }
}

// MARK: - 6. 黑白 Mono

final class MonoFilter: FilterProtocol {
    let identifier = "mono"
    let name = "黑白"

    func apply(to image: CIImage, intensity: Float) -> CIImage {
        guard let mono = CIFilter(name: "CIPhotoEffectMono", parameters: [
            kCIInputImageKey: image
        ]), let output = mono.outputImage else { return image }
        return blend(original: image, processed: output, intensity: intensity)
    }
}

// MARK: - 7. 复古 Vintage

final class VintageFilter: FilterProtocol {
    let identifier = "vintage"
    let name = "复古"

    func apply(to image: CIImage, intensity: Float) -> CIImage {
        var result = image
        // 棕褐色调
        if let sepia = CIFilter(name: "CISepiaTone", parameters: [
            kCIInputImageKey: result,
            kCIInputIntensityKey: 0.8
        ]), let output = sepia.outputImage {
            result = output
        }
        // 降低亮度、增加对比
        if let controls = CIFilter(name: "CIColorControls", parameters: [
            kCIInputImageKey: result,
            kCIInputBrightnessKey: -0.05,
            kCIInputContrastKey: 1.1,
            kCIInputSaturationKey: 0.7
        ]), let output = controls.outputImage {
            result = output
        }
        // 暗角效果
        if let vignette = CIFilter(name: "CIVignette", parameters: [
            kCIInputImageKey: result,
            kCIInputIntensityKey: 1.0,
            kCIInputRadiusKey: 1.5
        ]), let output = vignette.outputImage {
            result = output
        }
        return blend(original: image, processed: result, intensity: intensity)
    }
}

// MARK: - 8. 冷色调 Cool

final class CoolFilter: FilterProtocol {
    let identifier = "cool"
    let name = "冷色"

    func apply(to image: CIImage, intensity: Float) -> CIImage {
        // 冷色调：通过 CITemperatureAndTint 降低色温（偏蓝）
        guard let temp = CIFilter(name: "CITemperatureAndTint", parameters: [
            kCIInputImageKey: image,
            "inputNeutral": CIVector(x: 5000, y: 0),
            "inputTargetNeutral": CIVector(x: 7000, y: -100)
        ]), let output = temp.outputImage else { return image }
        return blend(original: image, processed: output, intensity: intensity)
    }
}
