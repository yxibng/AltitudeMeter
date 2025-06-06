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

extension CLLocationCoordinate2D {
    private func convertToDMS(decimal: Double) -> String {
        let absoluteLatitude = abs(decimal)
        let degrees = Int(absoluteLatitude)
        let minutesDecimal = (absoluteLatitude - Double(degrees)) * 60
        let minutes = Int(minutesDecimal)
        let seconds = (minutesDecimal - Double(minutes)) * 60
        let direction = decimal >= 0 ? "N" : "S"
        
        // 格式化输出（秒保留1位小数，可调整）
        return String(format: "%d°%d′%.1f″%@", degrees, minutes, seconds, direction)
    }
    var latitudeDMS: String {
        self.convertToDMS(decimal: latitude)
    }
    var longitudeDMS: String {
        self.convertToDMS(decimal: longitude)
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
    
    var altitude: String {
        guard let altitude = altitudeModel.altitude else {
            return "N/A"
        }
        switch altitudeModel.preferences.altitudeUnit {
        case .meter:
            return String(format: "%.2f m", altitude)
        case .feet:
            return String(format: "%.2f ft", altitude * 3.28084)
        }
    }
    
    var speed: String {
        guard let speed = altitudeModel.speed else {
            return "N/A"
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
}


class AltitudeDataModel: ObservableObject {
    @Published var altitudeModel = AltitudeModel()
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
        self.altitudeModel.altitude = location.altitude
        self.altitudeModel.altitudeAccuracy = location.verticalAccuracy
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
        locationManager.$location.sink {[weak self] location in
            self?.onLocationUpdate(location: location)
        }
        .store(in: &cancellables)
        
        locationManager.$pressure.sink { [weak self] pressure in
            self?.altitudeModel.pressure = pressure
        }.store(in: &cancellables)
        
        locationManager.$heading.sink { [weak self] heading in
            self?.altitudeModel.heading = heading
            // 处理方向数据（如果需要）
        }.store(in: &cancellables)
    }
}

