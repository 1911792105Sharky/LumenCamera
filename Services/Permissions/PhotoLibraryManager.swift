//
//  Services/Permissions/PhotoLibraryManager.swift
//  LumenCamera
//
//  统一管理相册权限请求与照片/视频保存
//

import Foundation
import Photos
import UIKit

enum PhotoLibraryManager {

    /// 请求相册写入权限
    static func requestAddPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    /// 保存图片到相册
    static func saveImage(_ image: UIImage, completion: ((Bool, Error?) -> Void)? = nil) {
        requestAddPermission { granted in
            guard granted else {
                completion?(false, NSError(domain: "PhotoLibrary", code: -1,
                                           userInfo: [NSLocalizedDescriptionKey: "未授予相册权限"]))
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    completion?(success, error)
                }
            }
        }
    }

    /// 保存视频文件到相册
    static func saveVideo(at url: URL, completion: ((Bool, Error?) -> Void)? = nil) {
        requestAddPermission { granted in
            guard granted else {
                completion?(false, NSError(domain: "PhotoLibrary", code: -1,
                                           userInfo: [NSLocalizedDescriptionKey: "未授予相册权限"]))
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { success, error in
                DispatchQueue.main.async {
                    completion?(success, error)
                }
            }
        }
    }
}
