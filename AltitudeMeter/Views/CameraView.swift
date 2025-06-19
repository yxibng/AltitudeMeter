//
//  CameraView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/5.
//

import SwiftUI

enum Theme {
    static let imageAspectRatio: CGFloat = 3 / 4.0
}

struct CameraPreview: View {
    @Binding var videoFrame: Image?
    var body: some View {
        GeometryReader { geometry in
            if let image = videoFrame {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
            }
        }
    }
}

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var altitudeDataMode: AltitudeDataModel
    @StateObject var cameraViewModel = CameraViewModel()
    
    @State var snpashot: UIImage? = nil
    @State var showSnapshot = false
    @State var showNoAuthAlert = false
    
    struct Layout {
        static let bottomHeight: CGFloat = 62
        static let buttonWidth: CGFloat = 32
        static let takePhotoButtonWidth: CGFloat = 50
        static let takePhotoButtonInnerWidth: CGFloat = 40
    }
    
    func makeButton(imageName: String, action: @escaping () -> Void)
    -> some View
    {
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
                CameraPreview(videoFrame: $cameraViewModel.videoFrame)
                watermark
            }
        }
        .background(Color.black)
    }
    
    var contentView: some View {
        VStack(spacing: 0) {
            Spacer()
            previewWithLabels
                .aspectRatio(Theme.imageAspectRatio, contentMode: .fit)
                .background(Color.gray)
                .clipped()
                .onAppear {
                    print("CameraView onAppear")
                    Task {
                        await cameraViewModel.camera.start()
                    }
                }
                .onDisappear {
                    print("CameraView onDisappear")
                    cameraViewModel.camera.stop()
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
                    Theme.imageAspectRatio
                )
                
                let watermarkImage = watermark.asImage(
                    size: CGSize(
                        width: UIScreen.screenSize.width,
                        height: UIScreen.screenSize.width
                        / Theme.imageAspectRatio
                    ),
                    scale: sourceImage.correctedExtent.extent.size.width
                    / UIScreen.screenSize.width
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
