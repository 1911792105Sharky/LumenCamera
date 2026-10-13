//
//  Views/Components/PermissionGuideView.swift
//  LumenCamera
//
//  权限引导页面：在相机权限未授权时显示，引导用户去设置或重新请求
//

import SwiftUI

struct PermissionGuideView: View {

    /// 权限被拒绝时跳转系统设置
    var onOpenSettings: () -> Void
    /// 重新请求权限
    var onRequest: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)

                Text("需要相机权限")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)

                Text("Lumen Camera 需要访问相机才能拍摄照片和视频。\n请在设置中允许相机权限。")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    onOpenSettings()
                } label: {
                    Text("前往设置")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.yellow)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 40)

                Button {
                    onRequest()
                } label: {
                    Text("重新请求权限")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}
