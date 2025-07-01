//
//  CameraViewModel.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/11.
//

import AVFoundation
import SwiftUI

class CameraViewModel: ObservableObject {
    enum CameraType {
        case photo
        case video
    }

    deinit {
        camera.stop()
        print("CameraViewModel deinitialized")
    }

    private let camera = Camera()

    var session: AVCaptureSession {
        camera.captureSession
    }

    @Published var photo: CIImage?
    @Published var showNoAuthorizationAlert = false
    init() {
        Task {
            await handleVideoAuthorization()
        }
        Task {
            await handleCameraPhotos()
        }
    }

    func takePhoto() {
        self.camera.takePhoto()
    }

    func start() async {
       await self.camera.start()
    }

    func stop() {
        self.camera.stop()
    }

    func switchCamera() {
        camera.switchCaptureDevice()
    }

    func setFocusPoint(_ point: CGPoint) {
        camera.setFocusPoint(point)
    }

    func setDeviceOrientation(_ orientation: UIDeviceOrientation) {
        camera.deviceOrientation = orientation
    }

    func setZoomFactor(_ zoomFactor: CGFloat) {
        camera.setZoomFactor(zoomFactor)
    }

    private func handleVideoAuthorization() async {
        let authorizationStatus = await AVCaptureDevice.requestAccess(
            for: .video
        )
        Task { @MainActor in
            self.showNoAuthorizationAlert = !authorizationStatus
        }
    }

    private func handleCameraPhotos() async {
        let photoStream = camera.photoStream
        for await photo in photoStream {
            Task {
                @MainActor in
                self.photo = photo.ciImage
            }
        }
    }
}
