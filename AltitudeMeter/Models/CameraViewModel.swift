//
//  CameraViewModel.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/11.
//

import AVFoundation
import Combine
import SwiftUI

class CameraViewModel: ObservableObject {
    deinit {
        camera.stop()
        orientationManager.stop()
        print("CameraViewModel deinitialized")
    }

    struct WatermarkItem {
        let image: CIImage
        let position: CGPoint
    }

    private let lock = NSLock()
    private var _watermark: WatermarkItem?
    var watermark: WatermarkItem? {
        set {
            lock.lock()
            defer { lock.unlock() }
            _watermark = newValue
        }
        get {
            lock.lock()
            defer { lock.unlock() }
            return _watermark
        }
    }

    enum DataEvent {
        case didStartRecording
        case didStopRecording(URL?)
    }

    private let eventSubject = PassthroughSubject<DataEvent, Never>()
    var eventPublisher: AnyPublisher<DataEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private lazy var camera: Camera = {
      let camera = Camera()
        camera.onCapturePhoto = { [weak self] image in
            guard let self else { return }
            Task { @MainActor in
                self.photo = image.ciImage
            }
        }
        camera.onCaptureSampleBuffer = { [weak self] sampleBuffer, type in
            guard let self else { return }
            handleSampleBuffer(sampleBuffer, type: type)
        }

        camera.$videoSize
            .receive(on: DispatchQueue.main)
            .filter({ $0 != .zero })
            .sink { [weak self] size in
                guard let self else { return }
                // Update aspect ratio based on video size
                var aspectRatio: CGFloat = size.width / size.height

                let max = max(size.width, size.height)
                let min = min(size.width, size.height)

                self.aspectRatio = min / max
                if deviceOrientation.isLandscape {
                    videoSize = CGSize(
                        width: max, height: min
                    )
                } else {
                    videoSize = CGSize(
                        width: min, height: max
                    )
                }
                print("Camera video size updated: \(size), aspect ratio: \(self.aspectRatio)")
            }
            .store(in: &cancellables)
        return camera
    }()

    private let pixelBufferFilter = PixelBufferCompositingFilter()

    private lazy var assetWriter: AssetWritter = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("output.mov")
        return AssetWritter {[weak self] pixelBuffer in
            guard let self,
                  let watermarkItem = watermark
            else { return pixelBuffer }
            // Apply watermark to the pixel buffer
            return pixelBufferFilter.composite(pixelBuffer: pixelBuffer, with: [
                .init(type: .image(watermarkItem.image, scale: 1.0), position: watermarkItem.position)
            ])
        }
    }()

    var session: AVCaptureSession {
        camera.captureSession
    }

    @Published var photo: CIImage?
    @Published var showNoAuthorizationAlert = false
    @Published var cameraType: Camera.CameraType = .photo
    @Published var deviceOrientation: UIDeviceOrientation = .portrait {
        didSet {
            let max = max(videoSize.width, videoSize.height)
            let min = min(videoSize.width, videoSize.height)
            var newSize = CGSize.zero
            if deviceOrientation.isLandscape {
                newSize = CGSize(width: max, height: min)
            } else {
                newSize = CGSize(width: min, height: max)
            }
            if newSize != self.videoSize {
                self.videoSize = newSize
            }
        }
    }
    @ObservedObject private var orientationManager = OrientationManager()
    @Published var isRecording = false // video recording state
    @Published var videoSize = CGSize.zero // output video/photo size, potrait mode is width < height, landscape mode is width > height
    @Published var aspectRatio: CGFloat = Theme.previewAspectRatio {
        didSet {
            print("aspectRatio updated: \(aspectRatio)")
        }
    } // aspect ratio for video preview
    private var cancellables = Set<AnyCancellable>()
    init() {
        Task {
            await handleVideoAuthorization()
        }
        orientationManager.start(interval: 1 / 30.0)
        orientationManager.$deviceOrientation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] orientation in
                guard let self else { return }
                if isRecording {
                    // 录制中，不允许修改方向
                    return
                }
                deviceOrientation = orientation
                camera.deviceOrientation = orientation
            }
            .store(in: &cancellables)
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

    func setCameraType(_ type: Camera.CameraType) {
        camera.cameraType = type
        self.cameraType = type
    }

    func startRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("output.mov")
        self.assetWriter.startRecording(outputURL: url, videoSize: self.videoSize)
        self.eventSubject.send(.didStartRecording)
        self.isRecording = true
    }

    func stopRecording() {
        self.assetWriter.stopRecording {[weak self] outputURL in
            guard let self else { return }
            // Handle post-recording actions, like saving the video or showing a preview
            print("Recording stopped and saved to: \(outputURL?.absoluteString ?? "Unknown URL")")
            // TOOD: report to user
            guard let outputURL else {
                print("No output URL provided")
                return
            }
            Task { @MainActor in
                self.eventSubject.send(.didStopRecording(outputURL))
            }
        }
        self.isRecording = false
    }

    private func handleVideoAuthorization() async {
        let authorizationStatus = await AVCaptureDevice.requestAccess(
            for: .video
        )
        Task { @MainActor in
            self.showNoAuthorizationAlert = !authorizationStatus
        }
    }
}

private extension CameraViewModel {
    func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer, type: Camera.BufferType) {
        if !self.isRecording {
            return
        }

        if self.watermark == nil {
            // No watermark set, just write the sample buffer directly
            print("no watermark set, ignoring sample buffer")
            return
        }

        if type == .audio {
            assetWriter.writeAudio(sampleBuffer: sampleBuffer)
        } else {
            assetWriter.writeVideo(sampleBuffer: sampleBuffer)
        }
    }
}
