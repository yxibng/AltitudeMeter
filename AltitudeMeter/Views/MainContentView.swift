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
    @State private var showNoLocationAuthAlert = false
    @State private var showNoCMAuthAlert = false
    
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
                .foregroundColor(.white)
            Text(dataModel.altitudeAccuracy)
                .foregroundColor(.white)
        }
    }
    

    private var compass: some View {
        Compass(degrees: dataModel.degrees) {
            VStack(alignment: .center, spacing: 0) {
                Text("当前海拔")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                Text(dataModel.altitude)
                    .font(.system(size: 200, weight: .bold))
                    .minimumScaleFactor(0.1)
                    .lineLimit(1)
                    .foregroundColor(.white)
                Text("当前速度\(dataModel.speed)")
                    .font(.system(size: 20, weight: .bold))
                    .minimumScaleFactor(0.1)
                    .lineLimit(1)
                    .foregroundColor(.white)
            }.padding(5)
        }
    }

    private var bottomContent: some View {
        Text(dataModel.bottomContent)
            .foregroundColor(.white)
    }
    
    private var contentView: some View {
        VStack {
            Spacer()
            topContent
            Spacer()
            compass
                .padding()
            bottomContent
            Spacer()
        }.background {
            gradientBackground.edgesIgnoringSafeArea(.all)
        }
        .toolbar {
            ToolbarItem(placement:.navigationBarLeading) {
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .tint(.white)
                }
            }
            
            ToolbarItem(placement:.navigationBarTrailing) {
                Button {
                    showCamera.toggle()
                } label: {
                    Image(systemName: "camera")
                        .tint(.white)
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
        }.alert("没有定位权限", isPresented: $showNoLocationAuthAlert) {
            Button("取消", role: .cancel) { }
            Button("取消") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("请在设置中开启定位权限")
        }.onChange(of: dataModel.showNoLocationAuthAlert) { newValue in
            showNoLocationAuthAlert = newValue
        }.onChange(of: dataModel.showNoCMAuthAlert) { newValue in
            showNoCMAuthAlert = newValue
        }.alert("没有运动与健身权限，无法获取当前气压和速度", isPresented: $showNoCMAuthAlert) {
            Button("取消", role: .cancel) { }
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("请在设置中开启运动与健身权限")
        }
    }
}


#Preview {
    MainContentView()
}
