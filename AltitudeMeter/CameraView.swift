//
//  CameraView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/5.
//

import SwiftUI


extension UIView {
    func asImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: self.layer.bounds.size, format: format)
            .image { context in
                self.drawHierarchy(in: self.layer.bounds, afterScreenUpdates: true)
            }
    }
}

extension UIScreen {

    static var safeAreaInsets: UIEdgeInsets {
        let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first
        return keyWindow?.safeAreaInsets ?? .zero
    }
}

extension View {
    func asImage(size: CGSize) -> UIImage {
        let controller = UIHostingController(rootView: self.edgesIgnoringSafeArea(.all))
        controller.view.bounds = CGRect(origin: .zero, size: size)
        let image = controller.view.asImage()
        return image
    }
}

struct CameraPreview: View {
    @Binding var videoFrame: Image?
    var body: some View {
        GeometryReader { geometry in
            if let image = videoFrame {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width,
                           height: geometry.size.height)
            }
        }
    }
}

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var altitudeDataMode: AltitudeDataModel

    @State var snpashot: UIImage? = nil
    @State var showSnapshot = false
    @State var showNoAuthAlert = false
    
    struct Layout {
        static let bottomHeight: CGFloat = 62
        static let buttonWidth: CGFloat = 32
        static let takePhotoButtonWidth: CGFloat = 50
        static let takePhotoButtonInnerWidth: CGFloat = 40
    }
    
    
    func makeButton(imageName: String, action: @escaping () -> Void) -> some View {
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
                let snapshot = previewWithLabels.asImage(size: snapshotSize)
                self.snpashot = snapshot
                self.showSnapshot = true
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: Layout.takePhotoButtonWidth, height: Layout.takePhotoButtonWidth)
                    Circle()
                        .fill(.white)
                        .frame(width: Layout.takePhotoButtonInnerWidth, height: Layout.takePhotoButtonInnerWidth)
                }
            }
            Spacer()
            makeButton(imageName: "arrow.triangle.2.circlepath") {
                cameraViewModel.camera.switchCaptureDevice()
            }
        }
        .padding(.horizontal, 32)
    }

    @StateObject var cameraViewModel = CameraViewModel()
    
    var snapshotSize: CGSize {
        let width = UIScreen.main.bounds.size.width
        let height =  UIScreen.main.bounds.size.height - Layout.bottomHeight - UIScreen.safeAreaInsets.bottom - UIScreen.safeAreaInsets.top
        return CGSize(width: width, height: height)
    }
    
    var previewWithLabels: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(videoFrame: $cameraViewModel.videoFrame)
                    .task {
                    await cameraViewModel.camera.start()
                }
                VStack(alignment: .leading) {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 0) {
                        VStack(alignment: .leading) {
                            Text("海拔：\(altitudeDataMode.altitude)")
                                .foregroundColor(.white)
                            
                            Text("气压: \(altitudeDataMode.pressure)")
                                .foregroundColor(.white)
                            
                            Text(altitudeDataMode.coordinate)
                                .foregroundColor(.white)
                            
                            Text(altitudeDataMode.geocodeLocation)
                                .foregroundColor(.white)
                        }
                        .padding()
                        Spacer()
                    }
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: UIScreen.safeAreaInsets.top)
            previewWithLabels
                .background(Color.gray).clipped()
            bottomView
                .frame(maxWidth: .infinity, maxHeight: Layout.bottomHeight)
            Spacer()
                .frame(height: UIScreen.safeAreaInsets.bottom)
        }.background(Color.black)
        .ignoresSafeArea(edges: [.top, .bottom])
        .fullScreenCover(isPresented: $showSnapshot) {
            if let snapshot = snpashot {
                SnapshotView(image: snapshot, coordinate: altitudeDataMode.altitudeModel.location)
            } else {
                Text("Snapshot not available")
            }
        }.onChange(of: cameraViewModel.showNoAuthorizationAlert) { newValue in
            showNoAuthAlert = newValue
        }.alert("没有相机权限", isPresented: $showNoAuthAlert) {
            Button("取消", role: .cancel) { }
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("请在设置中开启相机权限")
        }
    }
}

#Preview {
    CameraView(altitudeDataMode: AltitudeDataModel())
}
