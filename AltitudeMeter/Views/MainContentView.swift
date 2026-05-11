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

    private func blend(
        _ start: (Double, Double, Double),
        _ end: (Double, Double, Double),
        ratio: Double
    ) -> Color {
        let r = start.0 + (end.0 - start.0) * ratio
        let g = start.1 + (end.1 - start.1) * ratio
        let b = start.2 + (end.2 - start.2) * ratio
        return Color(red: r, green: g, blue: b)
    }

    private var backgroundTop: Color {
        blend((0.40, 0.25, 0.18), (0.16, 0.27, 0.43), ratio: dataModel.altitudeToneRatio)
    }

    private var backgroundBottom: Color {
        blend((0.05, 0.30, 0.53), (0.02, 0.22, 0.46), ratio: dataModel.altitudeToneRatio)
    }

    private var ringColor: Color {
        blend((0.89, 0.85, 0.79), (0.84, 0.90, 0.96), ratio: dataModel.altitudeToneRatio)
            .opacity(0.74)
    }

    private var centerTop: Color {
        blend((0.79, 0.59, 0.45), (0.54, 0.66, 0.82), ratio: dataModel.altitudeToneRatio)
    }

    private var centerBottom: Color {
        blend((0.24, 0.52, 0.82), (0.18, 0.46, 0.76), ratio: dataModel.altitudeToneRatio)
    }

    private var northMarker: Color {
        blend((0.93, 0.63, 0.26), (0.85, 0.56, 0.30), ratio: dataModel.altitudeToneRatio)
    }

    private var southMarker: Color {
        blend((0.24, 0.66, 0.93), (0.26, 0.72, 0.96), ratio: dataModel.altitudeToneRatio)
    }

    private var altitudeFontSize: CGFloat {
        let value = dataModel.altitude
        let integerPart = value.split(separator: ".").first.map(String.init) ?? value
        let digits = integerPart.filter { $0.isNumber }.count

        switch digits {
        case 0...2:
            return 200
        case 3:
            return 182
        case 4:
            return 162
        default:
            return 146
        }
    }

    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                backgroundTop,
                backgroundBottom,
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var atmosphericOverlay: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.0),
                ],
                center: .top,
                startRadius: 30,
                endRadius: 480
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear,
                    Color.black.opacity(0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                for index in 0..<220 {
                    let xSeed = sin(Double(index) * 12.9898) * 43758.5453
                    let ySeed = sin(Double(index) * 78.233) * 24634.6345
                    let x = (xSeed - floor(xSeed)) * size.width
                    let y = (ySeed - floor(ySeed)) * size.height
                    let radius = CGFloat(0.45 + (Double(index % 4) * 0.18))
                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(0.065))
                    )
                }
            }
            .blendMode(.softLight)
        }
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
        Compass(
            degrees: $dataModel.degrees,
            outerRingColor: ringColor,
            centerGradientTop: centerTop,
            centerGradientBottom: centerBottom,
            northMarkerColor: northMarker,
            southMarkerColor: southMarker
        ) {
            VStack(alignment: .center, spacing: 0) {
                Text(dataModel.altitudePrompt)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                Text(dataModel.altitude)
                    .font(.system(size: altitudeFontSize, weight: .bold))
                    .monospacedDigit()
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
            gradientBackground
                .overlay { atmosphericOverlay }
                .edgesIgnoringSafeArea(.all)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                        .tint(.white)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCamera.toggle()
                } label: {
                    Image(systemName: "camera")
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                        .tint(.white)
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("实时海拔表")
                .navigationBarTitleDisplayMode(.inline)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(dataModel: dataModel)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(altitudeDataMode: dataModel)
        }.alert("没有定位权限", isPresented: $showNoLocationAuthAlert) {
            Button("取消", role: .cancel) {}
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
            Button("取消", role: .cancel) {}
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
