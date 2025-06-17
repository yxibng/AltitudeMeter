//
//  PhotoLibrary.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/12.
//

import Photos
import UIKit
import os.log

class PhotoLibrary {

    enum PhotoLibraryError: Error {
        case authorizationDenied
        case saveFailed
    }

    static func checkAuthorization() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized:
            logger.debug("Photo library access authorized.")
            return true
        case .notDetermined:
            logger.debug("Photo library access not determined.")
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                == .authorized
        case .denied:
            logger.debug("Photo library access denied.")
            return false
        case .limited:
            logger.debug("Photo library access limited.")
            return false
        case .restricted:
            logger.debug("Photo library access restricted.")
            return false
        @unknown default:
            return false
        }
    }

    static func saveImage(_ image: UIImage, location: CLLocationCoordinate2D?)
        async throws
    {
        if await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            == .authorized
        {
            try await withCheckedThrowingContinuation { continuation in
                PHPhotoLibrary.shared().performChanges(
                    {
                        let creationRequest =
                            PHAssetChangeRequest.creationRequestForAsset(
                                from: image
                            )
                        creationRequest.creationDate = Date()
                        if let location {
                            creationRequest.location = CLLocation(
                                latitude: location.latitude,
                                longitude: location.longitude
                            )
                        }
                    },
                    completionHandler: { success, error in
                        if success {
                            continuation.resume()
                        } else {
                            continuation.resume(
                                throwing: PhotoLibraryError.saveFailed
                            )
                        }
                    }
                )
            }
        } else {
            throw PhotoLibraryError.authorizationDenied
        }
    }
}

private let logger = Logger(
    subsystem: "com.apple.swiftplaygroundscontent.capturingphotos",
    category: "PhotoLibrary"
)
