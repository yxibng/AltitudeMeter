//
//  SnapshotView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/12.
//

import SwiftUI
import CoreLocation

struct SnapshotView: View {
    
    struct Layout {
        static let bottomHeight: CGFloat = 62
        static let buttonWidth: CGFloat = 32
        static let saveButtonWidth: CGFloat = 50
        static let space: CGFloat = 16
    }
    
    @Environment(\.dismiss) private var dismiss
    @State var showNoAuthAlert = false
    
    var bottomView: some View {
        ZStack {
            Button {
                //save
                Task {
                    do {
                        try await PhotoLibrary.saveImage(image, location: coordinate)
                    } catch {
                        print("Error saving image: \(error)")
                        if let error = error as? PhotoLibrary.PhotoLibraryError, error == .authorizationDenied {
                            Task { @MainActor in
                                showNoAuthAlert = true
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .resizable()
                    .scaledToFit()
                    .tint(.white)
                   
            } .frame(width: Layout.saveButtonWidth, height: Layout.saveButtonWidth)

            Button {
                dismiss()
            } label: {
                Image(systemName: "arrowshape.turn.up.backward")
                    .resizable()
                    .scaledToFit()
                    .tint(.white)
                    
            }.frame(width: Layout.buttonWidth, height: Layout.buttonWidth)
            .offset(x: -(Layout.space + Layout.saveButtonWidth/2 + Layout.buttonWidth/2))
        }
    }
    var image: UIImage
    var coordinate: CLLocationCoordinate2D?
    var body: some View {
        
        VStack(spacing: 0) {
            Spacer().frame(height: UIScreen.safeAreaInsets.top)
            Image(uiImage: image).resizable().scaledToFit()
                .background(Color.red).clipped()
            bottomView
                .frame(maxWidth: .infinity, maxHeight: Layout.bottomHeight)
            Spacer().frame(height: UIScreen.safeAreaInsets.bottom)
        }.background(Color.black)
        .ignoresSafeArea(edges: [.top, .bottom])
        .alert("没有相册权限", isPresented: $showNoAuthAlert) {
            Button("取消", role: .cancel) { }
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        } message: {
            Text("请在设置中开启相册权限")
        }
        
    }
}

