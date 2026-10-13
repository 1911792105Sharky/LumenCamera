//
//  Services/Permissions/PermissionManager.swift
//  LumenCamera
//
//  统一管理相机、麦克风、相册权限
//

import Foundation
import AVFoundation
import Photos

enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
}

enum PermissionManager {

    /// 相机权限状态
    static var cameraStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    /// 请求相机权限
    static func requestCamera(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// 麦克风权限状态
    static var microphoneStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    /// 请求麦克风权限
    static func requestMicrophone(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// 相册权限状态
    static var photoLibraryStatus: PermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited: return .authorized
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }
}
