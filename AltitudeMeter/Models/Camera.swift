//
//  Camera.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/11.
// https://developer.apple.com/tutorials/sample-apps/capturingphotos-camerapreview

import AVFoundation
import CoreImage
import os.log
import UIKit

extension AVCaptureDevice {
    var resolution: CGSize {
        let dims = CMVideoFormatDescriptionGetDimensions(activeFormat.formatDescription)
        return CGSize(width: CGFloat(dims.width), height: CGFloat(dims.height))
    }
}

class Camera: NSObject {
    enum CameraType {
        case photo
        case video
    }
    
    enum BufferType {
        case video
        case audio
    }
    

    var cameraType: CameraType = .photo {
        didSet {
            if cameraType == .video {
                self.sessionQueue.async { [weak self] in
                    guard let self else { return }
                    captureSession.beginConfiguration()
                    defer {
                        captureSession.commitConfiguration()
                        self.videoSize = self.captureDevice?.resolution ?? .zero
                    }
                    captureSession.sessionPreset = .hd1920x1080
                    // add audio input if it doesn't exist
                    if let audioDevice,
                       let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
                        if !captureSession.inputs.contains(audioInput),
                           captureSession.canAddInput(audioInput) {
                            captureSession.addInput(audioInput)
                            audioDeviceInput = audioInput
                        }
                    }
                    // remove photo output if it exists
                    if let photoOutput {
                        captureSession.removeOutput(photoOutput)
                    }
                    // add video output if it doesn't exist
                    if captureSession.canAddOutput(videoOutput) {
                        captureSession.addOutput(videoOutput)
                    }
                    // add audio output if it doesn't exist
                    if captureSession.canAddOutput(audioOutput) {
                        captureSession.addOutput(audioOutput)
                    }
                }
            } else {
                self.sessionQueue.async { [weak self] in
                    guard let self else { return }
                    captureSession.beginConfiguration()
                    defer {
                        captureSession.commitConfiguration()
                        self.videoSize = self.captureDevice?.resolution ?? .zero
                        print("type photo, videoSize = \(self.videoSize)")
                    }
                    captureSession.sessionPreset = .photo
                    // remove audio input if it exists
                    if let audioDeviceInput {
                        if captureSession.inputs.contains(audioDeviceInput) {
                            captureSession.removeInput(audioDeviceInput)
                        }
                    }
                    // remove audio video output if it exists
                    captureSession.removeOutput(videoOutput)
                    captureSession.removeOutput(audioOutput)
                    // add photo output if it doesn't exist
                    if let photoOutput {
                        if captureSession.canAddOutput(photoOutput) {
                            captureSession.addOutput(photoOutput)
                        }
                    }
                }
            }
        }
    }
    deinit {
        print("Camera deinitialized")
    }
    let captureSession = AVCaptureSession()
    private var isCaptureSessionConfigured = false
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    @Published var videoSize: CGSize = .zero
    private lazy var videoOutput: AVCaptureVideoDataOutput = {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        return videoOutput
    }()
    private lazy var audioOutput: AVCaptureAudioDataOutput = {
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "AudioDataOutputQueue"))
        return audioOutput
    }()
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var allCaptureDevices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTrueDepthCamera, .builtInDualCamera,
                .builtInDualWideCamera, .builtInWideAngleCamera,
                .builtInDualWideCamera,
            ],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    private var audioDevice: AVCaptureDevice? {
        AVCaptureDevice.default(for: .audio)
    }

    private var frontCaptureDevices: [AVCaptureDevice] {
        allCaptureDevices
            .filter { $0.position == .front }
    }

    private var backCaptureDevices: [AVCaptureDevice] {
        allCaptureDevices
            .filter { $0.position == .back }
    }

    private var captureDevices: [AVCaptureDevice] {
        var devices = [AVCaptureDevice]()
#if os(macOS) || (os(iOS) && targetEnvironment(macCatalyst))
        devices += allCaptureDevices
#else
        if let backDevice = backCaptureDevices.first {
            devices += [backDevice]
        }
        if let frontDevice = frontCaptureDevices.first {
            devices += [frontDevice]
        }
#endif
        return devices
    }

    private var availableCaptureDevices: [AVCaptureDevice] {
        captureDevices
            .filter({ $0.isConnected })
            .filter({ !$0.isSuspended })
    }

    // video capture device
    private var captureDevice: AVCaptureDevice? {
        didSet {
            guard let captureDevice else { return }
            logger.debug("Using capture device: \(captureDevice.localizedName)")
            sessionQueue.async {
                self.updateSessionForCaptureDevice(captureDevice)
            }
        }
    }

    // current device orientation
    var deviceOrientation: UIDeviceOrientation = .portrait {
        didSet {
            self.sessionQueue.async { [weak self] in
                guard let self else { return }
                // update video output connection orientation
                if let videoOutputConnection = videoOutput.connection(with: .video),
                   videoOutputConnection.isVideoOrientationSupported {
                    videoOutputConnection.videoOrientation = deviceOrientation.avCaptureVideoOrientation ?? .portrait
                }
            }
        }
    }

    var isRunning: Bool {
        captureSession.isRunning
    }

    var isUsingFrontCaptureDevice: Bool {
        guard let captureDevice else { return false }
        return frontCaptureDevices.contains(captureDevice)
    }

    var isUsingBackCaptureDevice: Bool {
        guard let captureDevice else { return false }
        return backCaptureDevices.contains(captureDevice)
    }

    var onCapturePhoto: ((AVCapturePhoto) -> Void)?
    var onCaptureSampleBuffer: ((CMSampleBuffer, BufferType) -> Void)?

    override init() {
        super.init()
        initialize()
    }

    private func initialize() {
        captureDevice =
        availableCaptureDevices.first
        ?? AVCaptureDevice.default(for: .video)
    }

    private func configureCaptureSession(
        completionHandler: (_ success: Bool) -> Void
    ) {
        var success = false

        self.captureSession.beginConfiguration()

        defer {
            self.captureSession.commitConfiguration()
            completionHandler(success)
        }

        guard
            let captureDevice,
            let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        else {
            logger.error("Failed to obtain video input.")
            return
        }

        let photoOutput = AVCapturePhotoOutput()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        guard captureSession.canAddInput(deviceInput) else {
            logger.error("Unable to add device input to capture session.")
            return
        }
        guard captureSession.canAddOutput(photoOutput) else {
            logger.error("Unable to add photo output to capture session.")
            return
        }
        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)

        self.videoDeviceInput = deviceInput
        self.photoOutput = photoOutput
        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.maxPhotoQualityPrioritization = .quality

        updateVideoOutputConnection()

        isCaptureSessionConfigured = true

        success = true
    }

    private func checkAuthorization() async -> Bool {
        func _checkAuthorization(type: AVMediaType) async -> Bool {
            switch AVCaptureDevice.authorizationStatus(for: type) {
            case .authorized:
                logger.debug("Camera access authorized.")
                return true
            case .notDetermined:
                logger.debug("Camera access not determined.")
                sessionQueue.suspend()
                let status = await AVCaptureDevice.requestAccess(for: type)
                sessionQueue.resume()
                return status
            case .denied:
                logger.debug("Camera access denied.")
                return false
            case .restricted:
                logger.debug("Camera library access restricted.")
                return false
            @unknown default:
                return false
            }
        }

        if self.cameraType == .photo {
            return await _checkAuthorization(type: .video)
        }
        _ = await _checkAuthorization(type: .audio)
        return await _checkAuthorization(type: .video)
    }

    private func deviceInputFor(device: AVCaptureDevice?)
    -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch {
            logger.error(
                "Error getting capture device input: \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func updateSessionForCaptureDevice(_ captureDevice: AVCaptureDevice) {
        guard isCaptureSessionConfigured else { return }

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        for input in captureSession.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput {
                captureSession.removeInput(deviceInput)
            }
        }

        if let deviceInput = deviceInputFor(device: captureDevice) {
            if !captureSession.inputs.contains(deviceInput),
               captureSession.canAddInput(deviceInput) {
                captureSession.addInput(deviceInput)
            }
        }
        updateVideoOutputConnection()
    }

    private func updateVideoOutputConnection() {
        if let videoOutputConnection = videoOutput.connection(with: .video) {
            if videoOutputConnection.isVideoMirroringSupported {
                videoOutputConnection.isVideoMirrored =
                isUsingFrontCaptureDevice
            }
            if videoOutputConnection.isVideoOrientationSupported {
                videoOutputConnection.videoOrientation = self.deviceOrientation.avCaptureVideoOrientation ?? .portrait
            }
        }
        self.videoSize = captureDevice?.resolution ?? .zero
    }

    func start() async {
        let authorized = await checkAuthorization()
        guard authorized else {
            logger.error("Camera access was not authorized.")
            return
        }

        if isCaptureSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async { [weak self] in
                    guard let self else { return }
                    captureSession.startRunning()
                }
            }
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            configureCaptureSession { success in
                guard success else { return }
                self.videoSize = self.captureDevice?.resolution ?? .zero
                self.captureSession.startRunning()
            }
        }
    }

    func stop() {
        guard isCaptureSessionConfigured else { return }
        if captureSession.isRunning {
            sessionQueue.async {
                self.captureSession.stopRunning()
            }
        }
    }

    func switchCaptureDevice() {
        if let captureDevice,
           let index = availableCaptureDevices.firstIndex(of: captureDevice) {
            let nextIndex = (index + 1) % availableCaptureDevices.count
            self.captureDevice = availableCaptureDevices[nextIndex]
        } else {
            self.captureDevice = AVCaptureDevice.default(for: .video)
        }
    }

    func setZoomFactor(_ zoomFactor: CGFloat) {
        guard let device = self.captureDevice else {
            return
        }
        var zoomFactor = zoomFactor
        zoomFactor = max(1.0, min(zoomFactor, device.activeFormat.videoMaxZoomFactor))
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = zoomFactor
                device.unlockForConfiguration()
            } catch {
                logger.error("Error setting zoom factor: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 设置对焦点
    func setFocusPoint(_ point: CGPoint) {
        guard let device = self.captureDevice else {
            return
        }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                logger.error("Error setting focus point: \(error.localizedDescription)")
            }
        }
    }

    func takePhoto() {
        guard let photoOutput = self.photoOutput else { return }

        sessionQueue.async {
            var photoSettings = AVCapturePhotoSettings()
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [
                    AVVideoCodecKey: AVVideoCodecType.hevc
                ])
            }

            let isFlashAvailable =
            self.videoDeviceInput?.device.isFlashAvailable ?? false
            photoSettings.flashMode = isFlashAvailable ? .auto : .off
            photoSettings.isHighResolutionPhotoEnabled = true
            if let previewPhotoPixelFormatType = photoSettings
                .availablePreviewPhotoPixelFormatTypes.first {
                photoSettings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey as String:
                        previewPhotoPixelFormatType,
                ]
            }
            photoSettings.photoQualityPrioritization = .balanced
            if let photoOutputVideoConnection = photoOutput.connection(
                with: .video
            ) {
                if photoOutputVideoConnection.isVideoOrientationSupported,
                   let videoOrientation = self.deviceOrientation.avCaptureVideoOrientation {
                    photoOutputVideoConnection.videoOrientation =
                    videoOrientation
                }

                if photoOutputVideoConnection.isVideoMirroringSupported {
                    photoOutputVideoConnection.isVideoMirrored =
                    self.isUsingFrontCaptureDevice
                }
            }

            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            logger.error("Error capturing photo: \(error.localizedDescription)")
            return
        }
        onCapturePhoto?(photo)
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if connection == self.videoOutput.connection(with: .video) {
            onCaptureSampleBuffer?(sampleBuffer, .video)
        } else if connection == self.audioOutput.connection(with: .audio) {
            onCaptureSampleBuffer?(sampleBuffer, .audio)
        } else {
            logger.error("Unexpected capture output type.")
        }
    }
}

private let logger = Logger(
    subsystem: "com.apple.swiftplaygroundscontent.capturingphotos",
    category: "Camera"
)
