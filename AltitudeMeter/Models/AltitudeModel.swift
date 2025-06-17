//
//  AltitudeModel.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/6.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI
import SwiftSunriseSunset

// 经纬度格式化工具类
fileprivate class CoordinateFormatter {
    // 将十进制经纬度转换为度分秒字符串
    static func formatToDMS(latitude: Double, longitude: Double) -> (String, String) {
        let latitudeStr = formatCoordinate(value: latitude, isLatitude: true)
        let longitudeStr = formatCoordinate(value: longitude, isLatitude: false)
        return (latitudeStr, longitudeStr)
    }
    
    // 格式化单个坐标（纬度/经度）
    private static func formatCoordinate(value: Double, isLatitude: Bool) -> String {
        // 确定方向（N/S 或 E/W）
        let direction: String
        let absValue = abs(value)
        
        if isLatitude {
            direction = value >= 0 ? "N" : "S"
        } else {
            direction = value >= 0 ? "E" : "W"
        }
        
        // 提取度、分、秒
        let degrees = Int(absValue)
        let minutes = Int((absValue - Double(degrees)) * 60)
        let seconds = (absValue - Double(degrees) - Double(minutes) / 60) * 3600
        
        // 格式化字符串（保留两位小数）
        return "\(degrees)°\(minutes)'\(String(format: "%.2f", seconds))\"\(direction)"
    }
    
    // 将度分秒字符串转回十进制（可选）
    static func dmsToDecimal(degrees: Int, minutes: Int, seconds: Double, direction: String) -> Double {
        let decimal = Double(degrees) + Double(minutes) / 60 + seconds / 3600
        if #available(iOS 16.0, *) {
            return direction.contains(["S", "W"]) ? -decimal : decimal
        } else {
            // Fallback on earlier versions
            return direction == "S" || direction == "W" ? -decimal : decimal
        }
    }
}



extension CLLocationCoordinate2D {
    var latitudeDMS: String {
        CoordinateFormatter.formatToDMS(latitude: latitude, longitude: longitude).0
    }
    var longitudeDMS: String {
        CoordinateFormatter.formatToDMS(latitude: latitude, longitude: longitude).1
    }
}

enum AltitudeUnitType : String, CaseIterable, Identifiable, Codable {
    case meter
    case feet
    var id: String { self.rawValue }
}

enum GpsDisplayType: String, CaseIterable, Identifiable, Codable {
    //度分秒
    case dms
    //小数
    case decimal
    
    var id: String { self.rawValue }
}


enum PressureUnitType: String, CaseIterable, Identifiable,Codable {
    case kPa // 千帕
    case mBar // 毫巴 1 kPa = 10 mbar
    case atm // 大气压 1atm=101325Pa=101.325kPa
    case mmHg //毫米汞柱 1 kPa ≈ 7.5006 mmHg
    var id: String { self.rawValue }
}

enum BottomConentType: String, CaseIterable, Identifiable, Codable {
    case gps
    case sunrise
    case geocodeLocation
    var id: String { self.rawValue }
    var title: String {
        switch self {
        case .gps:
            return "GPS"
        case .sunrise:
            return "日出日落"
        case .geocodeLocation:
            return "地理位置"
        }
    }
}

struct AltitudeModel {
    var altitude: Double? // 海拔高度，单位为米
    var altitudeAccuracy: Double? // 海拔高度精度，单位为米
    var pressure: Double? // 气压值，单位为千帕（kPa）
    var speed: Double? // 速度，单位为米/秒
    var location: CLLocationCoordinate2D? // 位置数据，包括经纬度等信息
    var geocodeLocation: String? // 位置描述
    var sunrise: Date? // 日出时间
    var sunset: Date? // 日落时间
    var heading: CLHeading? // 方向数据
    var preferences: Preferences = .init()
}

struct Preferences: Codable {
    static let key = "com.yxibng.altitudeMeter.preferences"
    var altitudeUnit: AltitudeUnitType = .meter {
        didSet {
            save()
        }
    }
    var gpsDisplayType: GpsDisplayType = .dms {
        didSet {
            save()
        }
    }
    var pressureUnit: PressureUnitType = .kPa {
        didSet {
            save()
        }
    }
    var bottomContentType: BottomConentType = .gps {
        didSet {
            save()
        }
    }
    
    init() {
        if let data = UserDefaults.standard.string(forKey: Self.key),
           let preferences = try? JSONDecoder().decode(Preferences.self, from: Data(data.utf8)) {
           self = preferences
        }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(String(data: data, encoding: .utf8), forKey: Self.key)
        }
    }
    
}


extension AltitudeDataModel {
    
    var pressure: String {
        guard let pressure = altitudeModel.pressure else {
            return "N/A"
        }
        switch altitudeModel.preferences.pressureUnit {
        case .kPa:
            return String(format: "%.2f kPa", pressure)
        case .mBar:
            return String(format: "%.2f mBar", pressure * 10)
        case .atm:
            return String(format: "%.4f atm", pressure / 101.325)
        case .mmHg:
            return String(format: "%.2f mmHg", pressure * 7.5006)
        }
    }
    
    var altitudeAccuracy: String {
        guard let accuracy = altitudeModel.altitudeAccuracy else {
            return "N/A"
        }
        return String(format: "海拔精度 %.2f m", accuracy)
    }
    
    var altitude: String {
        guard let altitude = altitudeModel.altitude else {
            return "N/A"
        }
        switch altitudeModel.preferences.altitudeUnit {
        case .meter:
            return String(format: "%.0f m", altitude)
        case .feet:
            return String(format: "%.0f ft", altitude / 0.3048) // 1米 = 3.28084英尺
        }
    }
    
    var speed: String {
        guard let speed = altitudeModel.speed else {
            return "N/A"
        }
        if speed > 1000 {
            return String(format: "%.1f km/h", speed / 1000.0) // 速度转换为千米每小时
        }
        return String(format: "%.2f m/s", speed)
    }
    var geocodeLocation: String {
        altitudeModel.geocodeLocation ?? "N/A"
    }
    
    var coordinate: String {
        guard let location = altitudeModel.location else {
            return "N/A"
        }
        switch altitudeModel.preferences.gpsDisplayType {
        case .dms:
            return location.latitudeDMS + "\n" + location.longitudeDMS
        case .decimal:
            return String(format: "%.6f, %.6f", location.latitude, location.longitude)
        }
    }
    
    var sunrise: String {
        guard let sunrise = altitudeModel.sunrise else {
            return "N/A"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: sunrise)
    }
    
    var sunset: String {
        guard let sunset = altitudeModel.sunset else {
            return "N/A"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: sunset)
    }
    
    var degrees: Double {
        let degree = altitudeModel.heading?.magneticHeading ?? 0.0
        return -degree // 反转方向
    }
    
    var bottomContent: String {
        switch altitudeModel.preferences.bottomContentType {
        case .gps:
            return coordinate
        case .sunrise:
            return "日出时间: \(sunrise)\n日落时间: \(sunset)"
        case .geocodeLocation:
            return geocodeLocation
        }
    }
}


class AltitudeDataModel: ObservableObject {
    @Published var altitudeModel = AltitudeModel()
    @Published var showNoLocationAuthAlert = false
    @Published var showNoCMAuthAlert = false
    private let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()
    init() {
        setup()
    }
    
    private func onLocationUpdate(location: CLLocation?) {
        guard let location = location else {
            self.altitudeModel.altitude = nil
            self.altitudeModel.altitudeAccuracy = nil
            self.altitudeModel.location = nil
            self.altitudeModel.geocodeLocation = nil
            self.altitudeModel.sunset = nil
            self.altitudeModel.sunrise = nil
            return
        }
        
        if location.verticalAccuracy > 0 {
            self.altitudeModel.altitude = location.altitude
            self.altitudeModel.altitudeAccuracy = location.verticalAccuracy
        } else {
            self.altitudeModel.altitude = nil
            self.altitudeModel.altitudeAccuracy = nil
        }
        self.altitudeModel.location = location.coordinate
        self.altitudeModel.speed = location.speed >= 0 ? location.speed : nil // 速度可能为负值，表示无效数据
        
        self.altitudeModel.sunrise = SwiftSunriseSunset.sunrise(
            for: Date.now,
            in: TimeZone.current,
            at: location.coordinate
        )
        
        self.altitudeModel.sunset = SwiftSunriseSunset.sunset(
            for: Date.now,
            in: TimeZone.current,
            at: location.coordinate
        )

        Task {
            let geocodeLocation = await locationManager.reverseGeocodeLocation(CLLocation: location)
            await MainActor.run {
                self.altitudeModel.geocodeLocation = geocodeLocation
            }
        }
    }
    
    private func setup() {
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation()
        locationManager
            .$location
            .receive(on: DispatchQueue.main)
            .sink {[weak self] location in
                self?.onLocationUpdate(location: location)
            }
            .store(in: &cancellables)
        
        locationManager
            .$pressure
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pressure in
                self?.altitudeModel.pressure = pressure
            }.store(in: &cancellables)
        
        locationManager
            .$heading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heading in
                self?.altitudeModel.heading = heading
                // 处理方向数据（如果需要）
            }.store(in: &cancellables)

        locationManager
            .$locationAuthorizationStatus
            .map { $0 == .denied || $0 == .restricted }
            .receive(on: DispatchQueue.main)
            .assign(to: \.showNoLocationAuthAlert, on: self)
            .store(in: &cancellables)

        locationManager
            .$cmAuthorizationStatus
            .map { $0 == .denied || $0 == .restricted }
            .receive(on: DispatchQueue.main)
            .assign(to: \.showNoCMAuthAlert, on: self)
            .store(in: &cancellables)
    }
}

