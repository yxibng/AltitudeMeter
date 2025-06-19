//
//  Camera.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/11.
//https://developer.apple.com/tutorials/sample-apps/capturingphotos-camerapreview

import AVFoundation
import CoreImage
import UIKit
import os.log

class Camera: NSObject {

    deinit {
        print("Camera deinitialized")
    }
    private let captureSession = AVCaptureSession()
    private var isCaptureSessionConfigured = false
    private var deviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var sessionQueue: DispatchQueue!

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

    private var captureDevice: AVCaptureDevice? {
        didSet {
            guard let captureDevice = captureDevice else { return }
            logger.debug("Using capture device: \(captureDevice.localizedName)")
            sessionQueue.async {
                self.updateSessionForCaptureDevice(captureDevice)
            }
        }
    }

    var isRunning: Bool {
        captureSession.isRunning
    }

    var isUsingFrontCaptureDevice: Bool {
        guard let captureDevice = captureDevice else { return false }
        return frontCaptureDevices.contains(captureDevice)
    }

    var isUsingBackCaptureDevice: Bool {
        guard let captureDevice = captureDevice else { return false }
        return backCaptureDevices.contains(captureDevice)
    }

    private var addToPhotoStream: ((AVCapturePhoto) -> Void)?

    private var addToPreviewStream: ((CIImage) -> Void)?

    var isPreviewPaused = false

    lazy var previewStream: AsyncStream<CIImage> = {
        AsyncStream { continuation in
            addToPreviewStream = { ciImage in
                if !self.isPreviewPaused {
                    continuation.yield(ciImage)
                }
            }
        }
    }()

    lazy var photoStream: AsyncStream<AVCapturePhoto> = {
        AsyncStream { continuation in
            addToPhotoStream = { photo in
                continuation.yield(photo)
            }
        }
    }()

    override init() {
        super.init()
        initialize()
    }

    private func initialize() {
        sessionQueue = DispatchQueue(label: "session queue")

        captureDevice =
            availableCaptureDevices.first
            ?? AVCaptureDevice.default(for: .video)

        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateForDeviceOrientation),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
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
            let captureDevice = captureDevice,
            let deviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        else {
            logger.error("Failed to obtain video input.")
            return
        }

        let photoOutput = AVCapturePhotoOutput()

        captureSession.sessionPreset = AVCaptureSession.Preset.photo

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(
            self,
            queue: DispatchQueue(label: "VideoDataOutputQueue")
        )

        guard captureSession.canAddInput(deviceInput) else {
            logger.error("Unable to add device input to capture session.")
            return
        }
        guard captureSession.canAddOutput(photoOutput) else {
            logger.error("Unable to add photo output to capture session.")
            return
        }
        guard captureSession.canAddOutput(videoOutput) else {
            logger.error("Unable to add video output to capture session.")
            return
        }

        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)
        captureSession.addOutput(videoOutput)

        self.deviceInput = deviceInput
        self.photoOutput = photoOutput
        self.videoOutput = videoOutput

        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.maxPhotoQualityPrioritization = .quality

        updateVideoOutputConnection()

        isCaptureSessionConfigured = true

        success = true
    }

    private func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            logger.debug("Camera access authorized.")
            return true
        case .notDetermined:
            logger.debug("Camera access not determined.")
            sessionQueue.suspend()
            let status = await AVCaptureDevice.requestAccess(for: .video)
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

    private func deviceInputFor(device: AVCaptureDevice?)
        -> AVCaptureDeviceInput?
    {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let error {
            logger.error(
                "Error getting capture device input: \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func updateSessionForCaptureDevice(_ captureDevice: AVCaptureDevice)
    {
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
                captureSession.canAddInput(deviceInput)
            {
                captureSession.addInput(deviceInput)
            }
        }

        updateVideoOutputConnection()
    }

    private func updateVideoOutputConnection() {
        if let videoOutput = videoOutput,
            let videoOutputConnection = videoOutput.connection(with: .video)
        {
            if videoOutputConnection.isVideoMirroringSupported {
                videoOutputConnection.isVideoMirrored =
                    isUsingFrontCaptureDevice
            }
        }
    }

    func start() async {
        let authorized = await checkAuthorization()
        guard authorized else {
            logger.error("Camera access was not authorized.")
            return
        }

        if isCaptureSessionConfigured {
            if !captureSession.isRunning {
                sessionQueue.async { [self] in
                    self.captureSession.startRunning()
                }
            }
            return
        }

        sessionQueue.async { [self] in
            self.configureCaptureSession { success in
                guard success else { return }
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
        if let captureDevice = captureDevice,
            let index = availableCaptureDevices.firstIndex(of: captureDevice)
        {
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
    
    
    

    private var deviceOrientation: UIDeviceOrientation {
        var orientation = UIDevice.current.orientation
        if orientation == UIDeviceOrientation.unknown {
            orientation = UIScreen.main.orientation
        }
        return orientation
    }

    @objc
    func updateForDeviceOrientation() {
        //TODO: Figure out if we need this for anything.
    }

    private func videoOrientationFor(_ deviceOrientation: UIDeviceOrientation)
        -> AVCaptureVideoOrientation?
    {
        switch deviceOrientation {
        case .portrait: return AVCaptureVideoOrientation.portrait
        case .portraitUpsideDown:
            return AVCaptureVideoOrientation.portraitUpsideDown
        case .landscapeLeft: return AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight: return AVCaptureVideoOrientation.landscapeLeft
        default: return nil
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
            self.deviceInput?.device.isFlashAvailable ?? false
            photoSettings.flashMode = isFlashAvailable ? .auto : .off
            photoSettings.isHighResolutionPhotoEnabled = true
            if let previewPhotoPixelFormatType = photoSettings
                .availablePreviewPhotoPixelFormatTypes.first
            {
                photoSettings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey as String:
                        previewPhotoPixelFormatType
                ]
            }
            photoSettings.photoQualityPrioritization = .balanced
            if let photoOutputVideoConnection = photoOutput.connection(
                with: .video
            ) {
                if photoOutputVideoConnection.isVideoOrientationSupported,
                   let videoOrientation = self.videoOrientationFor(
                    self.deviceOrientation
                   )
                {
                    photoOutputVideoConnection.videoOrientation =
                    videoOrientation
                }
            }
            
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {

        if let error = error {
            logger.error("Error capturing photo: \(error.localizedDescription)")
            return
        }

        addToPhotoStream?(photo)
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }

        if connection.isVideoOrientationSupported,
            let videoOrientation = videoOrientationFor(deviceOrientation)
        {
            connection.videoOrientation = videoOrientation
        }

        addToPreviewStream?(CIImage(cvPixelBuffer: pixelBuffer))
    }
}

extension Camera {
    
    // MARK: - 坐标转换 (完整方向处理)
    func convertToDevicePoint(viewPoint: CGPoint, viewSize: CGSize) -> CGPoint? {
        guard let captureDevice = captureDevice else { return nil }
        
        // 1. 获取视频尺寸（横屏自然方向）
        let videoDimensions = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
        let videoSize = CGSize(width: CGFloat(videoDimensions.width),
                               height: CGFloat(videoDimensions.height))
        let videoAspect = videoSize.width / videoSize.height
        
        // 2. 预览视图尺寸
        let viewAspect = viewSize.width / viewSize.height
        
        // 3. 计算Aspect Fill模式下的实际视频区域
        let fillScale: CGFloat
        let scaledVideoSize: CGSize
        let offset: CGPoint
        
        if viewAspect > videoAspect {
            // 视图更宽 - 裁剪垂直方向
            fillScale = viewSize.width / videoSize.width
            scaledVideoSize = CGSize(width: viewSize.width, height: videoSize.height * fillScale)
            offset = CGPoint(x: 0, y: (viewSize.height - scaledVideoSize.height) / 2)
        } else {
            // 视图更高 - 裁剪水平方向
            fillScale = viewSize.height / videoSize.height
            scaledVideoSize = CGSize(width: videoSize.width * fillScale, height: viewSize.height)
            offset = CGPoint(x: (viewSize.width - scaledVideoSize.width) / 2, y: 0)
        }
        
        // 4. 转换到视频坐标系
        let normalizedPoint = CGPoint(
            x: (viewPoint.x - offset.x) / scaledVideoSize.width,
            y: (viewPoint.y - offset.y) / scaledVideoSize.height
        )
        
        // 5. 确保点在有效范围内
        guard normalizedPoint.x >= 0, normalizedPoint.x <= 1,
              normalizedPoint.y >= 0, normalizedPoint.y <= 1 else {
            return nil
        }
        
        // 6. 处理 Zoom Factor
        let zoomFactor = captureDevice.videoZoomFactor
        let zoomAdjustedPoint = adjustPointForZoom(point: normalizedPoint, zoomFactor: zoomFactor)
        
        // 7. 完整设备方向处理
        let orientationAdjustedPoint = adjustPointForDeviceOrientation(
            point: zoomAdjustedPoint,
            orientation: self.deviceOrientation
        )
        return orientationAdjustedPoint
    }
    
    // MARK: - 完整设备方向处理
    private func adjustPointForDeviceOrientation(point: CGPoint, orientation: UIDeviceOrientation) -> CGPoint {
        /*
         摄像头传感器坐标系:
         - 原点在左上角
         - 横屏Home键在右是自然方向
         - X轴向右，Y轴向下
         
         我们需要将视图坐标系中的点转换为传感器坐标系中的点
         考虑设备当前的物理方向
         */
        
        switch orientation {
        case .portrait:
            // 设备竖立，Home键在下
            // 需要顺时针旋转90度: (x, y) -> (y, 1-x)
            return CGPoint(x: point.y, y: 1 - point.x)
            
        case .portraitUpsideDown:
            // 设备倒立，Home键在上
            // 需要逆时针旋转90度: (x, y) -> (1-y, x)
            return CGPoint(x: 1 - point.y, y: point.x)
            
        case .landscapeLeft:
            // 设备向左横置，Home键在左
            // 需要旋转180度: (x, y) -> (1-x, 1-y)
            return CGPoint(x: 1 - point.x, y: 1 - point.y)
            
        case .landscapeRight:
            // 设备向右横置，Home键在右 (自然方向)
            return point
        default:
            // 未知方向使用最后一次有效方向
            return adjustPointForDeviceOrientation(point: point, orientation: self.deviceOrientation)
        }
    }
    
    // MARK: - Zoom Factor 坐标调整
    private func adjustPointForZoom(point: CGPoint, zoomFactor: CGFloat) -> CGPoint {
        guard zoomFactor > 1.0 else { return point }
        
        // 1. 计算缩放区域大小 (归一化)
        let zoomAreaSize = 1.0 / zoomFactor
        
        // 2. 计算缩放区域原点 (居中)
        let zoomOriginX = (1.0 - zoomAreaSize) / 2.0
        let zoomOriginY = (1.0 - zoomAreaSize) / 2.0
        
        // 3. 将点映射到缩放区域内
        let zoomedX = zoomOriginX + point.x * zoomAreaSize
        let zoomedY = zoomOriginY + point.y * zoomAreaSize
        
        return CGPoint(x: zoomedX, y: zoomedY)
    }
    
    
}



extension UIScreen {
    fileprivate var orientation: UIDeviceOrientation {
        let point = coordinateSpace.convert(
            CGPoint.zero,
            to: fixedCoordinateSpace
        )
        if point == CGPoint.zero {
            return .portrait
        } else if point.x != 0 && point.y != 0 {
            return .portraitUpsideDown
        } else if point.x == 0 && point.y != 0 {
            return .landscapeRight  //.landscapeLeft
        } else if point.x != 0 && point.y == 0 {
            return .landscapeLeft  //.landscapeRight
        } else {
            return .unknown
        }
    }
}

private let logger = Logger(
    subsystem: "com.apple.swiftplaygroundscontent.capturingphotos",
    category: "Camera"
)
