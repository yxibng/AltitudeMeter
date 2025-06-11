//
//  CameraView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/5.
//

import SwiftUI
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
    
    
    struct Layout {
        static let bottomHeight: CGFloat = 62
        static let buttonWidth: CGFloat = 32
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
            makeButton(imageName: "arrow.triangle.2.circlepath") {
                print("switch position")
            }
            Spacer()
            Button {
                cameraViewModel.camera.takePhoto()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: 50, height: 50)
                    Circle()
                        .fill(.white)
                        .frame(width: 40, height: 40)
                }
            }
            Spacer()
            makeButton(imageName: "safari") {
                print("show gps")
            }
            Spacer()
            makeButton(imageName: "barometer") {
                print("show barometer")
                
            }
        }.padding(.horizontal, 20)
            
    }

    @StateObject var cameraViewModel = CameraViewModel()
    var body: some View {
        VStack(spacing: 0) {
            CameraPreview(videoFrame: $cameraViewModel.videoFrame).task {
                await cameraViewModel.camera.start()
            }
            bottomView
                .frame(maxWidth: .infinity, maxHeight: Layout.bottomHeight)
                .background(Color.black.opacity(0.5))
        }
    }
}

#Preview {
    CameraView()
}
