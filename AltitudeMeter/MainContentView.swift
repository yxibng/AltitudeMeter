//
//  MainContentView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/5.
//

import SwiftUI

struct MainContentView: View {
    
    @State private var showSettings = false
    @State private var showCamera = false
    
    @State private var degree: Double = 0
    
    @StateObject private var dataModel = AltitudeDataModel()
    
    
    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [.orange.opacity(0.5), .blue.opacity(0.5)]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
        
    private var topContent: some View {
        VStack {
            Text(dataModel.pressure)
            Text(dataModel.altitudeAccuracy)
        }
    }
    

    private var compass: some View {
        Compass(degrees: dataModel.degrees) {
            VStack(alignment: .center) {
                Text("当前海拔")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                Text(dataModel.altitude)
                    .font(.system(size: 200, weight: .bold))
                    .minimumScaleFactor(0.1)
                    .lineLimit(1)
                    .foregroundColor(.white)
                Text("当前速度\(dataModel.speed)")
                    .font(.system(size: 30, weight: .bold))
                    .minimumScaleFactor(0.1)
                    .lineLimit(1)
                    .foregroundColor(.white)
            }.padding(5)
        }
    }

    private var bottomContent: some View {
        Text(dataModel.bottomContent)
    }
    
    private var contentView: some View {
        ZStack {
            gradientBackground.edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                topContent
                Spacer()
                compass
                bottomContent.padding(.bottom, 20)
            }.toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button {
                        showCamera.toggle()
                    } label: {
                        Image(systemName: "camera")
                    }
                }
            }
        }
    }
        
    
    
    var body: some View {
        
        CustomNavigationView(title: "Altitude Meter") {
            contentView
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(dataModel: dataModel)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(altitudeDataMode: dataModel)
        }
    }
    
}


#Preview {
    MainContentView()
}
