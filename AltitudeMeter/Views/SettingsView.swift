//
//  SettingsView.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/5.
//

import SwiftUI

struct SettingsView: View {

    @State private var altitudeUnit: AltitudeUnitType = .meter
    @State private var gpsDisplayType: GpsDisplayType = .dms
    @State private var pressureUnit: PressureUnitType = .kPa

    @ObservedObject var dataModel: AltitudeDataModel

    @ViewBuilder
    private func makeLeadingView(imageName: String, title: String) -> some View
    {
        HStack {
            ZStack {
                Circle().fill(Color.gray.opacity(0.2))
                    .frame(width: 30, height: 30)
                Image(systemName: imageName)
            }
            Text(title)
        }
    }

    var list: some View {
        List {
            HStack {
                makeLeadingView(imageName: "compass.drawing", title: "海拔")
                Spacer()
                Picker(
                    "Select an option",
                    selection: $dataModel.altitudeModel.preferences.altitudeUnit
                ) {
                    ForEach(AltitudeUnitType.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .fixedSize()
                .pickerStyle(.segmented)
            }

            HStack {
                makeLeadingView(imageName: "safari", title: "GPS")
                Spacer()
                Picker(
                    "Select an option",
                    selection: $dataModel.altitudeModel.preferences
                        .gpsDisplayType
                ) {
                    ForEach(GpsDisplayType.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .fixedSize()
                .pickerStyle(.segmented)
            }

            HStack {
                makeLeadingView(imageName: "barometer", title: "气压")
                Spacer()
                Picker(
                    "Select an option",
                    selection: $dataModel.altitudeModel.preferences.pressureUnit
                ) {
                    ForEach(PressureUnitType.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .fixedSize()
                .pickerStyle(.segmented)
            }

            HStack {
                makeLeadingView(
                    imageName: "inset.filled.bottomthird.square",
                    title: "底部显示"
                )
                Spacer()
                Picker(
                    "Select an option",
                    selection: $dataModel.altitudeModel.preferences
                        .bottomContentType
                ) {
                    ForEach(BottomConentType.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .fixedSize()
                .pickerStyle(.segmented)
            }

            HStack {
                makeLeadingView(imageName: "bookmark.circle", title: "版本号")
                Spacer()
                Text(
                    Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                        as? String ?? "Unknown"
                )
                .fixedSize()
            }

        }
    }

    var body: some View {
        NavigationView {
            VStack {
                list
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView(dataModel: .init())
}
