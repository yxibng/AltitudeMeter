//
//  CameraView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/5.
//

import SwiftUI

enum Theme {
    static let previewAspectRatio: CGFloat = 3 / 4.0
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
        static let watermarkHorizontalPadding: CGFloat = 20
        static let watermarkBottomPadding: CGFloat = 8
        static let watermarkMaxWidth: CGFloat = 340
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
                        .padding()
                }
                .disabled(cameraViewModel.isRecording)

                Spacer().frame(width: 32)
                Button {
                    cameraViewModel.setCameraType(.video)
                } label: {
                    Text("视频")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle( cameraViewModel.cameraType == .video ? .white : .white.opacity(0.5))
                        .padding()
                }
                .disabled(cameraViewModel.isRecording)
            }

            if cameraViewModel.cameraType == .video {
                HStack {
                    if !cameraViewModel.isRecording {
                        makeButton(imageName: "arrowshape.turn.up.backward") {
                            dismiss()
                        }
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
                    if !cameraViewModel.isRecording {
                        makeButton(
                            imageName: "arrow.trianglehead.2.clockwise.rotate.90.camera"
                        ) {
                            cameraViewModel.switchCamera()
                        }
                    }
                }
                .padding(EdgeInsets(
                    top: 0,
                    leading: 32,
                    bottom: 0,
                    trailing: 32
                )).offset(y: -8)
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
                )).offset(y: -8)
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

    private var watermarkMaxWidth: CGFloat {
        min(
            Layout.watermarkMaxWidth,
            max(180, videoSizeOnScreen.width - Layout.watermarkHorizontalPadding * 2)
        )
    }

    private var altitudeAndPressureLine: String {
        "海拔 \(altitudeDataMode.altitude)\(altitudeDataMode.altitudeModel.preferences.altitudeUnit.title) · 气压 \(altitudeDataMode.pressure)"
    }

    @ViewBuilder
    private var watermarkContent: some View {
        switch altitudeDataMode.altitudeModel.preferences.watermarkStyle {
        case .card:
            watermarkCardContent
        case .compact:
            watermarkCompactContent
        case .minimal:
            watermarkMinimalContent
        }
    }

    private var watermarkRenderContent: some View {
        watermarkContent
            .frame(maxWidth: watermarkMaxWidth, alignment: .leading)
    }

    private var watermarkCardContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 5) {
                Image(.launchIcon)
                    .resizable()
                    .frame(width: 36, height: 36)
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(altitudeDataMode.geocodeLocation)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 3)
    }

    private var watermarkCompactContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(.launchIcon)
                    .resizable()
                    .frame(width: 22, height: 22)
                Text(altitudeAndPressureLine)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(altitudeDataMode.coordinate)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(altitudeDataMode.geocodeLocation)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.black.opacity(0.30))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
        }
    }

    private var watermarkMinimalContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("海拔 \(altitudeDataMode.altitude)\(altitudeDataMode.altitudeModel.preferences.altitudeUnit.title)")
                .font(.system(size: 15, weight: .bold))
            Text(altitudeDataMode.coordinate)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
        }
    }

    var watermark: some View {
        Color.clear.overlay(alignment: .bottomLeading) {
            watermarkRenderContent
                .background(content: {
                    GeometryReader { proxy in
                        Color.clear.task(id: proxy.size) {
                            watermarkSize = proxy.size
                            print("water mark size = \(proxy.size)")
                        }
                    }
                })
                .padding(.leading, Layout.watermarkHorizontalPadding)
                .padding(.bottom, Layout.watermarkBottomPadding)
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
            .aspectRatio(aspectRatio, contentMode: .fit)
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

            if cameraViewModel.isRecording {
                Color.clear.aspectRatio(aspectRatio, contentMode: .fit)
                    .overlay(alignment: .topTrailing) {
                        Text(cameraViewModel.recordingDuration.durationString)
                            .padding(4)
                            .background(Color.red).cornerRadius(2)
                            .foregroundStyle(.white)
                    }
            }
            if showZoomFactorView {
                Color.clear.aspectRatio(aspectRatio, contentMode: .fit).overlay {
                    VStack {
                        Spacer()
                        Text("\(String(format: "%.1fX", zoomFactor * gestureScale))")
                            .foregroundStyle(.red)
                            .task {
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                showZoomFactorView = false
                            }
                    }
                }
            }
        }
    }

    @State private var zoomFactor: CGFloat = 1.0
    @GestureState private var gestureScale: CGFloat = 1.0
    @State private var showFocusIndicator = false
    @State private var focusSpot: FocusLocation?
    @State private var showZoomFactorView = false
    @State private var showVideoEditor = false
    @State private var outpuURL: URL?

    var magnificationGesture: some Gesture {
        MagnificationGesture()
              .updating($gestureScale) { value, state, _ in
                // 计算预期缩放比例
                let newScale = zoomFactor * value

                // 在 updating 中应用边界限制
                  if newScale <= Theme.minZoomFactor {
                    // 达到最小缩放时，反推手势值
                    state = Theme.minZoomFactor / zoomFactor
                } else if newScale >= cameraViewModel.maxZoomFactor {
                    // 达到最大缩放时，反推手势值
                    state = cameraViewModel.maxZoomFactor / zoomFactor
                } else {
                    // 正常范围内使用原始值
                    state = value
                }
                  cameraViewModel.setZoomFactor(zoomFactor * state)
                  showZoomFactorView = true
              }
            .onEnded { value in
                // 应用最终缩放值（带边界限制）
                let newScale = zoomFactor * value
                zoomFactor = max(1.0, min(newScale, cameraViewModel.maxZoomFactor))
                cameraViewModel.setZoomFactor(zoomFactor)
            }
    }

    var contentView: some View {
        ZStack {
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
            }.onChange(of: altitudeDataMode.altitudeModel.preferences.watermarkStyle) { _ in
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
            .fullScreenCover(isPresented: $showVideoEditor) {
                if let url = outpuURL {
                    VideoEditorView(url: url)
                }
            }
            .onChange(of: cameraViewModel.photo) { newValue in
                if showSnapshot { return }
                guard let sourceImage = newValue else { return }
                generateSnapshot(sourceImage: sourceImage)
            }
            .onChange(of: cameraViewModel.cameraType) { _ in
                zoomFactor = Theme.minZoomFactor
                cameraViewModel.setZoomFactor(zoomFactor)
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
        // Keep photo output framing consistent with the preview before placing watermark.
        let targetAspectRatio = aspectRatio
        let croppedSourceImage = sourceImage.cropToAspectRatio(targetAspectRatio)

        let watermark = generateSnapshot(sourceImageSize: croppedSourceImage.extent.size)
        let watermarkImage = watermark.image
            .transformed(by: CGAffineTransform(translationX: watermark.position.x, y: watermark.position.y))

        let watermarkFilter = CIFilter(name: "CISourceOverCompositing")!
        watermarkFilter.setValue(
            croppedSourceImage.correctedExtent,
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
        let referenceSize = videoSizeOnScreen.width > 0 ? videoSizeOnScreen : sourceImageSize
        let scale = CGFloat(sourceImageSize.width / referenceSize.width)

        let offsetX = Layout.watermarkHorizontalPadding * scale
        // CI coordinates start at bottom-left. Use bottom padding to match preview's bottomLeading placement.
        let offsetY = Layout.watermarkBottomPadding * scale

        let watermarkImage = watermarkRenderContent
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
