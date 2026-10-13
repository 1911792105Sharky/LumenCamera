//
//  Views/Editor/EditorView.swift
//  LumenCamera
//
//  照片编辑界面：裁剪、调整、滤镜、撤销重做、保存
//

import SwiftUI

struct EditorView: View {

    @StateObject private var editor: PhotoEditor
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTool: EditorTool = .adjust
    @State private var previewImage: UIImage?
    @State private var showSavedToast = false
    @State private var selectedCropRatio: CropAspectRatio = .free
    @State private var cropRect: CGRect = .zero

    init(image: UIImage) {
        _editor = StateObject(wrappedValue: PhotoEditor(image: image))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 预览区
                ZStack {
                    Color.black
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    } else {
                        Image(uiImage: editor.render() ?? UIImage())
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    }
                }
                .frame(maxHeight: .infinity)

                // 工具条
                toolBar

                // 当前工具的参数面板
                toolPanel
                    .frame(height: 200)
                    .background(Color(UIColor.systemGray6))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            editor.undo()
                            refreshPreview()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!editor.canUndo)
                        .foregroundStyle(editor.canUndo ? .white : .gray)

                        Button {
                            editor.redo()
                            refreshPreview()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                        }
                        .disabled(!editor.canRedo)
                        .foregroundStyle(editor.canRedo ? .white : .gray)

                        Button("保存") {
                            savePhoto()
                        }
                        .foregroundStyle(.yellow)
                        .bold()
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { refreshPreview() }
            .overlay {
                if showSavedToast {
                    VStack {
                        Spacer()
                        Text("已保存到相册")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.7))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .padding(.bottom, 40)
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - 工具条

    private var toolBar: some View {
        HStack(spacing: 0) {
            ForEach(EditorTool.allCases) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.iconName)
                            .font(.system(size: 20))
                        Text(tool.rawValue)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(selectedTool == tool ? .yellow : .white)
                }
            }
        }
        .background(Color.black)
    }

    // MARK: - 参数面板

    @ViewBuilder
    private var toolPanel: some View {
        switch selectedTool {
        case .crop:
            cropPanel
        case .adjust:
            adjustPanel
        case .filter:
            filterPanel
        }
    }

    // MARK: - 裁剪面板

    private var cropPanel: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CropAspectRatio.allCases) { ratio in
                        Button {
                            selectedCropRatio = ratio
                            applyCropRatio(ratio)
                        } label: {
                            Text(ratio.rawValue)
                                .font(.caption)
                                .foregroundStyle(selectedCropRatio == ratio ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCropRatio == ratio ? Color.yellow : Color.gray.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)

            Text("选择比例后自动应用裁剪，可再次调整")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Button("重置裁剪") {
                editor.clearCrop()
                refreshPreview()
            }
            .font(.caption)
            .padding(.top, 8)
        }
        .padding(.vertical, 8)
    }

    private func applyCropRatio(_ ratio: CropAspectRatio) {
        let extent = editor.imageExtent
        guard let r = ratio.ratio else {
            editor.clearCrop()
            refreshPreview()
            return
        }
        // 按比例居中裁剪
        let imageRatio = extent.width / extent.height
        var cropW: CGFloat
        var cropH: CGFloat
        if imageRatio > r {
            cropH = extent.height
            cropW = cropH * r
        } else {
            cropW = extent.width
            cropH = cropW / r
        }
        let x = (extent.width - cropW) / 2
        let y = (extent.height - cropH) / 2
        editor.setCropRect(CGRect(x: x, y: y, width: cropW, height: cropH))
        refreshPreview()
    }

    // MARK: - 调整面板

    private var adjustPanel: some View {
        VStack(spacing: 12) {
            ForEach(AdjustmentParameter.allCases) { param in
                adjustmentSlider(param: param)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func adjustmentSlider(param: AdjustmentParameter) -> some View {
        let value = Binding(
            get: { editor.adjustments[param] ?? param.defaultValue },
            set: { newValue in
                editor.setAdjustment(param, value: newValue)
                refreshPreview()
            }
        )
        return VStack(spacing: 4) {
            HStack {
                Text(param.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: param.range)
                .tint(.yellow)
        }
    }

    // MARK: - 滤镜面板

    private var filterPanel: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(editor.filterEngine.availableFilters, id: \.identifier) { filter in
                        filterChip(filter: filter)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)

            if editor.filterIdentifier != "none" {
                HStack {
                    Text("强度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { editor.filterIntensity },
                        set: { editor.setFilterIntensity($0); refreshPreview() }
                    ), in: 0...1)
                    .tint(.yellow)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
    }

    private func filterChip(filter: FilterProtocol) -> some View {
        let isSelected = editor.filterIdentifier == filter.identifier
        return Text(filter.name)
            .font(.caption)
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.yellow : Color.gray.opacity(0.3))
            .clipShape(Capsule())
            .onTapGesture {
                editor.selectFilter(identifier: filter.identifier)
                refreshPreview()
            }
    }

    // MARK: - 预览刷新

    private func refreshPreview() {
        // 为避免频繁渲染，主线程渲染
        previewImage = editor.render()
    }

    // MARK: - 保存

    private func savePhoto() {
        guard let image = editor.render() else { return }
        PhotoLibraryManager.saveImage(image) { success, _ in
            if success {
                withAnimation { showSavedToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
}
