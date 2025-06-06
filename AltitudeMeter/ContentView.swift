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

    @State private var degree: Double = 0
    
    @StateObject private var dataModel = AltitudeDataModel()
    
    var body: some View {
        
        NavigationView {
            
            ZStack {
                
                LinearGradient(
                    gradient: Gradient(colors: [.orange.opacity(0.5), .blue.opacity(0.5)]),
                          startPoint: .top,
                          endPoint: .bottom
                      )
                
                VStack {
                    Spacer()
                    VStack {
                        Text(dataModel.pressure)
                        Text(dataModel.altitudeAccuracy)
                    }
                    Spacer()
                    
                    Compass(degrees: dataModel.degrees) {
                        VStack(alignment: .center) {
                            Text("当前海拔")
                            Text(dataModel.altitude)
                                .font(.system(size: 40, weight: .bold))
                            Text("当前速度\(dataModel.speed)")
                        }.background(Color.red.opacity(0.8))
                    }
                    
                    Text(dataModel.bottomContent)
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
