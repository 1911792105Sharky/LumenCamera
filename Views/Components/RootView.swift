//
//  Views/Components/RootView.swift
//  LumenCamera
//
//  根视图：检查相机权限，根据状态显示相机界面或权限引导
//

import SwiftUI
import UIKit

struct RootView: View {

    @State private var cameraPermission: PermissionStatus = .notDetermined
    @State private var isRequesting = false

    var body: some View {
        Group {
            switch cameraPermission {
            case .authorized:
                CameraView()
            case .denied:
                PermissionGuideView(
                    onOpenSettings: { openSystemSettings() },
                    onRequest: { requestCameraPermission() }
                )
            case .notDetermined:
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
        }
        .onAppear {
            cameraPermission = PermissionManager.cameraStatus
            if cameraPermission == .notDetermined {
                requestCameraPermission()
            }
        }
    }

    private func requestCameraPermission() {
        guard !isRequesting else { return }
        isRequesting = true
        PermissionManager.requestCamera { granted in
            cameraPermission = granted ? .authorized : .denied
            isRequesting = false
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
