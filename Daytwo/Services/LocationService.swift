import Foundation
import CoreLocation
import Observation

/// 定位服务：获取当前位置并逆地理编码为可读地名。
/// 只在用户主动添加位置时调用，结果仅保存在本地。
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private(set) var currentLocation: CLLocation?
    private(set) var placemark: CLPlacemark?
    private(set) var isLocating = false
    private(set) var statusText: String?

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - 对外接口

    func captureCurrentLocation() {
        statusText = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocating()
        case .denied, .restricted:
            isLocating = false
            statusText = "未获得定位权限，请到系统设置中开启"
        @unknown default:
            break
        }
    }

    func clear() {
        currentLocation = nil
        placemark = nil
        statusText = nil
        isLocating = false
        geocoder.cancelGeocode()
    }

    /// 可展示的位置名："城市 · 区县"，拿不到时退化为坐标
    var locationName: String? {
        if let p = placemark {
            var parts: [String] = []
            if let locality = p.locality { parts.append(locality) }
            if let subLocality = p.subLocality, subLocality != p.locality { parts.append(subLocality) }
            if parts.isEmpty, let area = p.administrativeArea { parts.append(area) }
            if parts.isEmpty, let name = p.name { parts.append(name) }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        if let coordinate = currentLocation?.coordinate {
            return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
        }
        return nil
    }

    /// 用于位置分组的主地名
    var localityGroup: String? {
        placemark?.locality ?? placemark?.administrativeArea
    }

    // MARK: - 私有

    private func startLocating() {
        isLocating = true
        manager.requestLocation()
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN")) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLocating = false
                if let error {
                    self.statusText = "地点解析失败：\(error.localizedDescription)"
                    self.placemark = nil
                } else {
                    self.placemark = placemarks?.first
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if isLocating { startLocating() }
        case .denied, .restricted:
            isLocating = false
            statusText = "未获得定位权限，请到系统设置中开启"
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        statusText = "定位失败：\(error.localizedDescription)"
    }
}
