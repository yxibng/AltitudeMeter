//
//  CameraView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/5.
//

import SwiftUI

enum Theme {
    static let previewAspectRatio: CGFloat = 3 / 4.0
    static let maxZoomFactor: CGFloat = 5.0
    static let minZoomFactor: CGFloat = 1.0
}

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var altitudeDataMode: AltitudeDataModel
    @StateObject var cameraViewModel = CameraViewModel()

    @State var snpashot: UIImage?
    @State var showSnapshot = false
    @State var showNoAuthAlert = false

    @StateObject private var orientationManager = OrientationManager()

    private var aspectRatio: CGFloat {
        if orientationManager.deviceOrientation.isLandscape {
            return 1.0 / Theme.previewAspectRatio
        }
        return Theme.previewAspectRatio
    }

    @State private var rotationAngle: Angle = .zero

    struct Layout {
        static let bottomHeight: CGFloat = 62
        static let buttonWidth: CGFloat = 32
        static let takePhotoButtonWidth: CGFloat = 50
        static let takePhotoButtonInnerWidth: CGFloat = 40
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
        HStack {
            makeButton(imageName: "arrowshape.turn.up.backward") {
                dismiss()
            }
            Spacer()
            Button {
                cameraViewModel.camera.takePhoto()
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
                cameraViewModel.camera.switchCaptureDevice()
            }
        }
        .padding(EdgeInsets(top: 10, leading: 32, bottom: 0, trailing: 32))
    }

    var snapshotSize: CGSize {
        let width = UIScreen.main.bounds.size.width
        let height =
        UIScreen.main.bounds.size.height - Layout.bottomHeight
        - UIScreen.safeAreaInsets.bottom - UIScreen.safeAreaInsets.top
        return CGSize(width: width, height: height)
    }

    var watermark: some View {
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
                Spacer()
            }
            Text(altitudeDataMode.coordinate)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(altitudeDataMode.geocodeLocation).font(
                .system(size: 14, weight: .bold)
            )
            .foregroundColor(.white)

            Spacer()
        }
        .padding().background(Color.clear)
    }

    var previewWithLabels: some View {
        GeometryReader { geometry in
            ZStack {
                AVCaptureVideoPreviewView(session: self.cameraViewModel.camera.captureSession,
                                          videoOrientation: .portrait) { tapPoint, focusPoint in
                    print("tapPoint: \(tapPoint), focusPoint: \(focusPoint)")
                    self.focusSpot = FocusLocation(position: tapPoint)
                    self.cameraViewModel.camera.setFocusPoint(focusPoint)
                    self.showFocusIndicator = true
                }
                FixedPositionRotatedView(angle: self.rotationAngle.degrees) {
                    watermark
                }.frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
            }

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
        .background(Color.black)
    }

    @State private var zoomFactor: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showFocusIndicator = false

    @State private var focusSpot: FocusLocation?

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
                cameraViewModel.camera.setZoomFactor(zoomFactor)
            }
            .onEnded { _ in
                // 重置参考值
                lastScale = 1.0
            }
    }

    var contentView: some View {
        VStack(spacing: 0) {
            Spacer()

            previewWithLabels
                .aspectRatio(Theme.previewAspectRatio, contentMode: .fit)
                .background(Color.gray)
                .clipped()
                .gesture(magnificationGesture)
                .onAppear {
                    print("CameraView onAppear")
                    orientationManager.start(interval: 1 / 30.0)
                    Task {
                        await cameraViewModel.camera.start()
                    }
                }
                .onDisappear {
                    print("CameraView onDisappear")
                    orientationManager.stop()
                    cameraViewModel.camera.stop()
                }
                .onChange(of: orientationManager.deviceOrientation) { newValue in

                    if newValue == .portrait {
                        self.rotationAngle = .zero
                    } else if newValue == .landscapeLeft {
                        self.rotationAngle = .degrees(90)
                    } else if newValue == .landscapeRight {
                        self.rotationAngle = .degrees(270)
                    } else if newValue == .portraitUpsideDown {
                        self.rotationAngle = .degrees(180)
                    } else {
                        self.rotationAngle = .zero
                    }
                }

            bottomView
                .frame(maxWidth: .infinity, maxHeight: Layout.bottomHeight)
            Spacer()
        }
    }

    var body: some View {
        contentView
            .background(Color.black)
            .ignoresSafeArea(edges: [.top, .bottom])
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
            }.onChange(of: cameraViewModel.photo) { newValue in
                if self.showSnapshot { return }
                guard let photo = newValue else { return }
                let sourceImage = photo.cropToAspectRatio(
                    aspectRatio
                )
                var width: CGFloat {
                    if orientationManager.deviceOrientation.isLandscape {
                        return UIScreen.screenSize.width * aspectRatio
                    } else {
                        return UIScreen.screenSize.width
                    }
                }

                var height: CGFloat {
                    if orientationManager.deviceOrientation.isLandscape {
                        return UIScreen.screenSize.width
                    } else {
                        return UIScreen.screenSize.width / aspectRatio
                    }
                }

                let watermarkImage = watermark.asImage(
                    size: CGSize(
                        width: width,
                        height: height
                    ),
                    scale: sourceImage.correctedExtent.extent.size.width
                    / width
                ).asCIImage()

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

                self.snpashot = image
                self.showSnapshot = true
            }
    }
}

#Preview {
    CameraView(altitudeDataMode: AltitudeDataModel())
}
