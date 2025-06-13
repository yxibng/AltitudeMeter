//
//  LocationManager.swift
//  AltitudeMeter
//
//  Created by yxibng on 2025/6/5.
//


import CoreLocation
import CoreMotion



class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()
    let aiMeter = CMAltimeter()

    @Published var location: CLLocation? // 包含经纬度、海拔等数据
    @Published var pressure: Double? // 包含气压数据，单位为千帕（kPa）
    @Published var heading: CLHeading? // 方向数据
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest // 最高精度（包含海拔）
        manager.requestWhenInUseAuthorization() // 请求权限
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // 高精度模式
        manager.distanceFilter = 1.0 // 位置变化至少1米时更新
        aiMeter.startRelativeAltitudeUpdates(to: .main) { data, error in
            self.pressure = data?.pressure.doubleValue // 获取气压数据
        }
    }
    
    func startUpdatingLocation() {
        Task {
            if CLLocationManager.locationServicesEnabled() {
                manager.startUpdatingLocation()
            }
        }
    }
    
    func startUpdatingHeading() {
        Task {
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        }
    }
    
    func reverseGeocodeLocation(CLLocation: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(CLLocation)
            guard let first = placemarks.first else {
                return nil //
            }
            return [first.country,
                    first.administrativeArea,
                    first.locality,
                    first.subLocality,
                    first.thoroughfare]
                .compactMap { $0 }
                .joined(separator: ", ") // 返回国家、行政区、城市、街道等信息
        } catch {
            print("地理编码失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.location = locations.last // 更新位置数据
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("定位失败: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.heading = newHeading
        }
    }
    
}
