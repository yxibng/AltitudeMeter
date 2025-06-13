//
//  CameraViewModel.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/11.
//


import SwiftUI
import AVFoundation

class CameraViewModel: ObservableObject {
    let camera = Camera()
    @Published var videoFrame: Image?
    @Published var showNoAuthorizationAlert = false
    init() {
        Task {
            await handleCameraPreviews()
        }
    }
    func handleCameraPreviews() async {        
        let authorizationStatus = await AVCaptureDevice.requestAccess(for: .video)
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
}

fileprivate struct PhotoData {
    var thumbnailImage: Image
    var thumbnailSize: (width: Int, height: Int)
    var imageData: Data
    var imageSize: (width: Int, height: Int)
}

fileprivate extension CIImage {
    var image: Image? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}

fileprivate extension Image.Orientation {

    init(_ cgImageOrientation: CGImagePropertyOrientation) {
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
