//
//  CameraViewModel.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/11.
//

import AVFoundation
import SwiftUI

class CameraViewModel: ObservableObject {
    static let previewImageContext = CIContext()
    
    deinit {
        camera.stop()
        print("CameraViewModel deinitialized")
    }

    let camera = Camera()
    @Published var videoFrame: Image?
    @Published var photo: CIImage?
    @Published var showNoAuthorizationAlert = false
    init() {
        Task {
            await handleCameraPreviews()
        }
        Task {
            await handleCameraPhotos()
        }
    }
    func handleCameraPreviews() async {
        let authorizationStatus = await AVCaptureDevice.requestAccess(
            for: .video
        )
        Task { @MainActor in
            self.showNoAuthorizationAlert = !authorizationStatus
        }

        let imageStream = camera.previewStream
            .map { $0.image }
        for await image in imageStream {
            Task { @MainActor in
                videoFrame = image
            }
        }
    }
    
    func handleCameraPhotos() async {
        let photoStream = camera.photoStream
        for await photo in photoStream {
            Task {
                @MainActor in
                self.photo = photo.ciImage
            }
        }
    }
}

private struct PhotoData {
    var thumbnailImage: Image
    var thumbnailSize: (width: Int, height: Int)
    var imageData: Data
    var imageSize: (width: Int, height: Int)
}

extension CIImage {
    fileprivate var image: Image? {
        let ciContext = CameraViewModel.previewImageContext
        guard let cgImage = ciContext.createCGImage(self, from: self.extent)
        else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}

extension Image.Orientation {

    fileprivate init(_ cgImageOrientation: CGImagePropertyOrientation) {
        switch cgImageOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }
}
