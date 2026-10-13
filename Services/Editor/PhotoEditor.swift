//
//  Services/Editor/PhotoEditor.swift
//  LumenCamera
//
//  照片编辑引擎：调整（曝光/对比度/饱和度/色温/锐度）、裁剪、滤镜、撤销重做
//

import Foundation
import CoreImage
import UIKit

/// 编辑状态快照（用于撤销/重做）
struct EditorState: Equatable {
    var adjustments: [AdjustmentParameter: Float]
    var filterIdentifier: String
    var filterIntensity: Float
    var cropRect: CGRect?
}

/// 照片编辑引擎
final class PhotoEditor: ObservableObject {

    /// 原始图片
    private let originalImage: UIImage
    private let originalCIImage: CIImage

    /// 滤镜引擎（复用滤镜系统）
    let filterEngine = FilterEngine()

    /// 各调整参数值
    @Published var adjustments: [AdjustmentParameter: Float] = [:] {
        didSet { pushUndoIfNeeded() }
    }

    /// 当前选中滤镜标识符
    @Published var filterIdentifier: String = "none" {
        didSet { pushUndoIfNeeded() }
    }

    /// 滤镜强度
    @Published var filterIntensity: Float = 1.0 {
        didSet { pushUndoIfNeeded() }
    }

    /// 裁剪区域（相对于原图 extent 的像素坐标，nil 表示不裁剪）
    @Published var cropRect: CGRect? {
        didSet { pushUndoIfNeeded() }
    }

    /// 撤销 / 重做栈
    private var undoStack: [EditorState] = []
    private var redoStack: [EditorState] = []

    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false

    /// 防止在 pushUndo 时触发递归
    private var isRestoring = false

    init(image: UIImage) {
        self.originalImage = image
        if let ci = FilterEngine.ciImage(from: image) {
            self.originalCIImage = ci
        } else {
            self.originalCIImage = CIImage(color: .clear)
        }
        // 初始化默认调整值
        for param in AdjustmentParameter.allCases {
            adjustments[param] = param.defaultValue
        }
        // 选中原图滤镜
        if let none = filterEngine.availableFilters.first(where: { $0.identifier == "none" }) {
            filterEngine.currentFilter = none
        }
        self.filterIdentifier = "none"
    }

    // MARK: - 调整

    /// 设置某个调整参数
    func setAdjustment(_ param: AdjustmentParameter, value: Float) {
        adjustments[param] = value
    }

    /// 重置所有调整为默认值
    func resetAdjustments() {
        for param in AdjustmentParameter.allCases {
            adjustments[param] = param.defaultValue
        }
    }

    // MARK: - 裁剪

    /// 设置裁剪区域（像素坐标，基于原图 extent）
    func setCropRect(_ rect: CGRect) {
        cropRect = rect
    }

    /// 清除裁剪
    func clearCrop() {
        cropRect = nil
    }

    // MARK: - 滤镜

    /// 选中滤镜
    func selectFilter(identifier: String) {
        filterIdentifier = identifier
        if let filter = filterEngine.availableFilters.first(where: { $0.identifier == identifier }) {
            filterEngine.currentFilter = filter
        }
    }

    /// 设置滤镜强度
    func setFilterIntensity(_ value: Float) {
        filterIntensity = value
        filterEngine.intensity = value
    }

    // MARK: - 撤销 / 重做

    private func pushUndoIfNeeded() {
        guard !isRestoring else { return }
        let state = currentState()
        // 避免连续相同状态入栈
        if undoStack.last != state {
            undoStack.append(state)
            redoStack.removeAll()
        }
        updateUndoRedoFlags()
    }

    func undo() {
        guard !undoStack.isEmpty else { return }
        let current = currentState()
        redoStack.append(current)
        let previous = undoStack.removeLast()
        restore(state: previous)
        updateUndoRedoFlags()
    }

    func redo() {
        guard !redoStack.isEmpty else { return }
        let current = currentState()
        undoStack.append(current)
        let next = redoStack.removeLast()
        restore(state: next)
        updateUndoRedoFlags()
    }

    private func currentState() -> EditorState {
        EditorState(
            adjustments: adjustments,
            filterIdentifier: filterIdentifier,
            filterIntensity: filterIntensity,
            cropRect: cropRect
        )
    }

    private func restore(state: EditorState) {
        isRestoring = true
        adjustments = state.adjustments
        filterIdentifier = state.filterIdentifier
        filterIntensity = state.filterIntensity
        cropRect = state.cropRect
        // 同步滤镜引擎
        if let filter = filterEngine.availableFilters.first(where: { $0.identifier == state.filterIdentifier }) {
            filterEngine.currentFilter = filter
        }
        filterEngine.intensity = state.filterIntensity
        isRestoring = false
    }

    private func updateUndoRedoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    // MARK: - 渲染

    /// 渲染当前编辑结果为 UIImage
    func render() -> UIImage? {
        var image = originalCIImage

        // 1. 调整（曝光、对比度、饱和度、色温、锐度）
        image = applyAdjustments(to: image)

        // 2. 滤镜
        filterEngine.currentFilter = filterEngine.availableFilters.first(where: { $0.identifier == filterIdentifier }) ?? filterEngine.currentFilter
        filterEngine.intensity = filterIntensity
        image = filterEngine.apply(to: image)

        // 3. 裁剪
        if let cropRect {
            image = image.cropped(to: cropRect)
        }

        return filterEngine.renderUIImage(from: image)
    }

    /// 渲染预览 CIImage（供 SwiftUI 实时显示）
    func previewCIImage() -> CIImage {
        var image = originalCIImage
        image = applyAdjustments(to: image)
        filterEngine.currentFilter = filterEngine.availableFilters.first(where: { $0.identifier == filterIdentifier }) ?? filterEngine.currentFilter
        filterEngine.intensity = filterIntensity
        image = filterEngine.apply(to: image)
        if let cropRect {
            image = image.cropped(to: cropRect)
        }
        return image
    }

    /// 应用调整参数
    private func applyAdjustments(to image: CIImage) -> CIImage {
        var result = image

        // 曝光 + 对比度 + 饱和度
        if let controls = CIFilter(name: "CIColorControls", parameters: [
            kCIInputImageKey: result,
            kCIInputBrightnessKey: adjustments[.exposure] ?? 0,
            kCIInputContrastKey: adjustments[.contrast] ?? 1.0,
            kCIInputSaturationKey: adjustments[.saturation] ?? 1.0
        ]), let output = controls.outputImage {
            result = output
        }

        // 色温
        let warmth = adjustments[.warmth] ?? 0
        // warmth: -100 ~ 100，映射到色温偏移
        let targetNeutralX: CGFloat = 6500 + CGFloat(warmth) * 10 // 偏冷=蓝，偏暖=黄
        if let temp = CIFilter(name: "CITemperatureAndTint", parameters: [
            kCIInputImageKey: result,
            "inputNeutral": CIVector(x: 6500, y: 0),
            "inputTargetNeutral": CIVector(x: targetNeutralX, y: 0)
        ]), let output = temp.outputImage {
            result = output
        }

        // 锐度
        let sharpness = adjustments[.sharpness] ?? 0
        if sharpness > 0 {
            if let sharpen = CIFilter(name: "CISharpenLuminance", parameters: [
                kCIInputImageKey: result,
                kCIInputSharpnessKey: sharpness
            ]), let output = sharpen.outputImage {
                result = output
            }
        }

        return result
    }

    /// 原始图片 extent（用于裁剪坐标计算）
    var imageExtent: CGRect { originalCIImage.extent }
}
