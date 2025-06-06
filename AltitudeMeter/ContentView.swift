//
//  ContentView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/5.
//

import SwiftUI



struct ContentView: View {
    
    @State private var showSettings = false
    @State private var showCamera = false

    @StateObject private var dataModel = AltitudeDataModel()
    
    var body: some View {
        
        NavigationView {
            VStack {
                Spacer()
                VStack {
//                    Text("海拔精度\(locationManager.location?.verticalAccuracy ?? 0) 米")
//                    Text("\(locationManager.location?.altitude ?? 0) 米")
                }
                Spacer()
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
            .navigationTitle("Altitude Meter")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSettings) {
                SettingsView(dataModel: dataModel)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView()
            }
        }

    }
}

#Preview {
    ContentView()
}
