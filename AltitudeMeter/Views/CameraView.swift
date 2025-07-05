//
//  CameraView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/5.
//

import SwiftUI

enum Theme {
    static let previewAspectRatio: CGFloat = 9 / 16.0
    static let maxZoomFactor: CGFloat = 5.0
    static let minZoomFactor: CGFloat = 1.0
}

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var altitudeDataMode: AltitudeDataModel
    @StateObject private var cameraViewModel = CameraViewModel()

    @State private var snpashot: UIImage?
    @State private var showSnapshot = false
    @State private var showNoAuthAlert = false

    private var aspectRatio: CGFloat {
        if cameraViewModel.deviceOrientation.isLandscape {
            return 1.0 / Theme.previewAspectRatio
        }
        return Theme.previewAspectRatio
    }

    @State private var watermarkSize: CGSize = .zero
    @State private var videoSizeOnScreen: CGSize = .zero

    @State private var rotationAngle: Angle = .zero

    struct Layout {
        static let bottomHeight: CGFloat = 62
        static let buttonWidth: CGFloat = 32
        static let takePhotoButtonWidth: CGFloat = 50
        static let takePhotoButtonInnerWidth: CGFloat = 40
        static let watermarkPadding: CGFloat = 20
    }

    func makeButton(imageName: String, action: @escaping () -> Void)
    -> some View {
        Button(action: action) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
        }.tint(.white)
            .frame(height: Layout.buttonWidth)
    }

    var bottomView: some View {
        VStack {
            HStack {
                Button {
                    cameraViewModel.setCameraType(.photo)
                } label: {
                    Text("照片")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle( cameraViewModel.cameraType == .photo ? .white : .white.opacity(0.5))
                }
                Spacer().frame(width: 32)
                Button {
                    cameraViewModel.setCameraType(.video)
                } label: {
                    Text("视频")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle( cameraViewModel.cameraType == .video ? .white : .white.opacity(0.5))
                }
            }

            if cameraViewModel.cameraType == .video {
                HStack {
                    makeButton(imageName: "arrowshape.turn.up.backward") {
                        dismiss()
                    }
                    Spacer()
                    Button {
                        if cameraViewModel.isRecording {
                            cameraViewModel.stopRecording()
                        } else {
                            cameraViewModel.startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                                .frame(
                                    width: Layout.takePhotoButtonWidth,
                                    height: Layout.takePhotoButtonWidth
                                )

                            if cameraViewModel.isRecording {
                                Rectangle()
                                    .fill(.red)
                                    .frame(
                                        width: Layout.takePhotoButtonInnerWidth * sqrt(2) / 3,
                                        height: Layout.takePhotoButtonInnerWidth * sqrt(2) / 3
                                    )
                            } else {
                                Circle()
                                    .fill(.red)
                                    .frame(
                                        width: Layout.takePhotoButtonInnerWidth,
                                        height: Layout.takePhotoButtonInnerWidth
                                    )
                            }
                        }
                    }
                    Spacer()
                    makeButton(
                        imageName: "arrow.trianglehead.2.clockwise.rotate.90.camera"
                    ) {
                        cameraViewModel.switchCamera()
                    }
                }
                .padding(EdgeInsets(
                    top: 0,
                    leading: 32,
                    bottom: 0,
                    trailing: 32
                ))
            } else {
                HStack {
                    makeButton(imageName: "arrowshape.turn.up.backward") {
                        dismiss()
                    }
                    Spacer()
                    Button {
                        cameraViewModel.takePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                                .frame(
                                    width: Layout.takePhotoButtonWidth,
                                    height: Layout.takePhotoButtonWidth
                                )
                            Circle()
                                .fill(.white)
                                .frame(
                                    width: Layout.takePhotoButtonInnerWidth,
                                    height: Layout.takePhotoButtonInnerWidth
                                )
                        }
                    }
                    Spacer()
                    makeButton(
                        imageName: "arrow.trianglehead.2.clockwise.rotate.90.camera"
                    ) {
                        cameraViewModel.switchCamera()
                    }
                }
                .padding(EdgeInsets(
                    top: 0,
                    leading: 32,
                    bottom: 0,
                    trailing: 32
                ))
            }
        }
    }

    var snapshotSize: CGSize {
        let width = UIScreen.main.bounds.size.width
        let height =
        UIScreen.main.bounds.size.height - Layout.bottomHeight
        - UIScreen.safeAreaInsets.bottom - UIScreen.safeAreaInsets.top
        return CGSize(width: width, height: height)
    }

    private var watermarkContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 5) {
                Image(.launchIcon)
                    .resizable()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 0) {
                    Text("海拔：")
                        .font(.system(size: 14, weight: .medium))
                    + Text(altitudeDataMode.altitude)
                        .font(.system(size: 15, weight: .bold))
                    + Text(altitudeDataMode.altitudeModel.preferences.altitudeUnit.title)
                        .font(.system(size: 14, weight: .medium))

                    Spacer().frame(height: 3)

                    Text("气压：")
                        .font(.system(size: 14))
                    + Text(altitudeDataMode.pressure)
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
            }
            Text(altitudeDataMode.coordinate)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(altitudeDataMode.geocodeLocation).font(
                .system(size: 14, weight: .bold)
            )
            .foregroundColor(.white)
        }
    }

    var watermark: some View {
        Color.clear.overlay(alignment: .topLeading) {
            watermarkContent
                .offset(x: Layout.watermarkPadding, y: Layout.watermarkPadding)
                .background(content: {
                    GeometryReader { proxy in
                        Color.clear.task(id: proxy.size) {
                            watermarkSize = proxy.size
                            print("water mark size = \(proxy.size)")
                        }
                    }
                })
        }
    }

    let videoViewId = UUID()
    let watermarkViewId = UUID()

    var previewWithLabels: some View {
        ZStack(alignment: .center) {
            AVCaptureVideoPreviewView(session: cameraViewModel.session,
                                      videoOrientation: .portrait) { tapPoint, focusPoint in
                print("tapPoint: \(tapPoint), focusPoint: \(focusPoint)")
                focusSpot = FocusLocation(position: tapPoint)
                cameraViewModel.setFocusPoint(focusPoint)
                showFocusIndicator = true
            }
            FixedPositionRotatedView(angle: rotationAngle.degrees) {
                watermark
            }
            .aspectRatio(cameraViewModel.aspectRatio, contentMode: .fit)
            .background(content: {
                GeometryReader { proxy in
                    Color.clear.task(id: proxy.size) {
                        videoSizeOnScreen = proxy.size
                        print("video size on screen = \(proxy.size)")
                    }
                }
            })
            if let focusSpot {
                FocusIndicator()
                    .frame(width: 64, height: 64)
                    .position(focusSpot.position)
                    .id(focusSpot.id)  // 强制重新创建视图:cite[3]
                    .task {
                        // 延时1秒后自动消失
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        self.focusSpot = nil  // 自动消失
                    }
            }
        }
    }

    @State private var zoomFactor: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showFocusIndicator = false
    @State private var focusSpot: FocusLocation?
    @State private var showVideoEditor = false
    @State private var outpuURL: URL?

    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { newScale in
                // 计算从上次状态到现在的缩放变化
                let delta = newScale / lastScale
                let newZoomFactor = zoomFactor * delta
                zoomFactor = min(
                    max(newZoomFactor, Theme.minZoomFactor),
                    Theme.maxZoomFactor
                )
                lastScale = zoomFactor
                cameraViewModel.setZoomFactor(zoomFactor)
            }
            .onEnded { _ in
                // 重置参考值
                lastScale = 1.0
            }
    }

    var contentView: some View {
        ZStack(alignment: .top) {
            previewWithLabels
                .aspectRatio(Theme.previewAspectRatio, contentMode: .fit)
                .gesture(magnificationGesture)
                .onAppear {
                    print("CameraView onAppear")
                    Task {
                        await cameraViewModel.start()
                    }
                }
                .onDisappear {
                    print("CameraView onDisappear")
                    cameraViewModel.stop()
                }
                .onChange(of: cameraViewModel.deviceOrientation) { newValue in
                    cameraViewModel.setDeviceOrientation(newValue)
                    if newValue == .portrait {
                        rotationAngle = .zero
                    } else if newValue == .landscapeLeft {
                        rotationAngle = .degrees(90)
                    } else if newValue == .landscapeRight {
                        rotationAngle = .degrees(270)
                    } else if newValue == .portraitUpsideDown {
                        rotationAngle = .degrees(180)
                    } else {
                        rotationAngle = .zero
                    }
                }
            VStack {
                Spacer()
                bottomView
                    .frame(maxWidth: .infinity, maxHeight: Layout.bottomHeight)
            }
        }
    }

    var body: some View {
        contentView
            .background(Color.black)
            .fullScreenCover(isPresented: $showSnapshot) {
                if let snapshot = snpashot {
                    SnapshotView(
                        image: snapshot,
                        coordinate: altitudeDataMode.altitudeModel.location
                    )
                } else {
                    Text("Snapshot not available")
                }
            }.onChange(of: cameraViewModel.showNoAuthorizationAlert) {
                newValue in
                showNoAuthAlert = newValue
            }.alert("没有相机权限", isPresented: $showNoAuthAlert) {
                Button("取消", role: .cancel) {}
                Button("去设置") {
                    if let url = URL(
                        string: UIApplication.openSettingsURLString
                    ) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("请在设置中开启相机权限")
            }.throttleChange(of: $altitudeDataMode.altitudeModel, duration: 0.5, action: { _ in
                updateWatermarkForVideoRecording()
            })
            .onChange(of: cameraViewModel.deviceOrientation) { _ in
                updateWatermarkForVideoRecording()
            }
            .onChange(of: cameraViewModel.videoSize) { _ in
                updateWatermarkForVideoRecording()
            }.onChange(of: cameraViewModel.isRecording) { _ in
                updateWatermarkForVideoRecording()
            }
            .onReceive(cameraViewModel.eventPublisher) { event in
                switch event {
                case .didStopRecording(let url):
                    guard let url else {
                        print("Recording stopped but URL is nil")
                        return
                    }
                    outpuURL = url
                    showVideoEditor = true
                default:
                    break
                }
            }
            .sheet(isPresented: $showVideoEditor) {
                if let url = outpuURL {
                    VideoEditorView(url: url)
                }
            }
            .onChange(of: cameraViewModel.photo) { newValue in
                if showSnapshot { return }
                guard let sourceImage = newValue else { return }
                generateSnapshot(sourceImage: sourceImage)
            }
    }
}

extension CameraView {
    private func updateWatermarkForVideoRecording() {
        if cameraViewModel.videoSize == .zero { return }
        if cameraViewModel.cameraType == .photo { return }
        if !cameraViewModel.isRecording { return }
        print("alitudeDataModel changed, updating watermark")
        let watermark = generateSnapshot(sourceImageSize: cameraViewModel.videoSize)
        cameraViewModel.watermark = .init(image: watermark.image, position: watermark.position)
    }

    private func generateSnapshot(sourceImage: CIImage) {
        let watermark = generateSnapshot(sourceImageSize: sourceImage.extent.size)
        let watermarkImage = watermark.image
            .transformed(by: CGAffineTransform(translationX: watermark.position.x, y: watermark.position.y))

        let watermarkFilter = CIFilter(name: "CISourceOverCompositing")!
        watermarkFilter.setValue(
            sourceImage.correctedExtent,
            forKey: kCIInputBackgroundImageKey
        )
        watermarkFilter.setValue(
            watermarkImage,
            forKey: kCIInputImageKey
        )
        guard let sourceImage = watermarkFilter.outputImage else {
            print("Failed to create watermark image")
            return
        }
        let context = CIContext()
        let cgImage = context.createCGImage(
            sourceImage,
            from: sourceImage.extent
        )
        guard let cgImage else {
            return
        }
        let image = UIImage(cgImage: cgImage)

        snpashot = image
        showSnapshot = true
    }

    private func generateSnapshot(sourceImageSize: CGSize) -> (image: CIImage, position: CGPoint) {
        let videoSizeOnScreen = cameraViewModel.deviceOrientation.isLandscape ? self.videoSizeOnScreen.revert : self.videoSizeOnScreen
        let scale = CGFloat(sourceImageSize.width / videoSizeOnScreen.width)

        let offsetX = Layout.watermarkPadding * scale
        let offsetY = (videoSizeOnScreen.height - Layout.watermarkPadding - watermarkSize.height) * scale

        let watermarkImage = watermarkContent
            .asImage(
                size: watermarkSize,
                scale: scale
            )
            .asCIImage()
        return (watermarkImage, CGPoint(x: offsetX, y: offsetY))
    }
}

#Preview {
    CameraView(altitudeDataMode: AltitudeDataModel())
}
