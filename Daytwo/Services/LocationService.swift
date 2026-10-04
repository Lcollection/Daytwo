import Foundation
import CoreLocation
import Observation

/// 定位服务：获取当前位置并逆地理编码为可读地名。
///
/// 速度优化：
/// 1. 立即采用系统缓存的最近位置（`manager.location`），地名解析并行进行；
/// 2. 同时请求一次新定位，第一个有效结果马上采用并停止；
/// 3. 地名解析带缓存：约 200 米范围内复用上一次结果，避免重复网络请求。
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    /// 当前最佳位置（可能来自缓存，随后被新定位替换）
    private(set) var currentLocation: CLLocation?
    /// 可展示的位置名："城市 · 区县"，拿不到时退化为坐标
    private(set) var locationName: String?
    /// 用于位置分组的主地名
    private(set) var localityGroup: String?
    private(set) var isLocating = false
    private(set) var statusText: String?

    private var captureStartTime: Date?
    private var lastGeocodedLocation: CLLocation?
    private var geocodeCache: [String: (name: String?, locality: String?)] = [:]
    private var timeoutTask: Task<Void, Never>?

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - 对外接口

    /// 开始定位：立刻给出缓存结果，并异步刷新更精确的定位
    func capture() {
        statusText = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginCapture()
        case .denied, .restricted:
            isLocating = false
            statusText = "未获得定位权限，请到系统设置中开启"
        @unknown default:
            break
        }
    }

    func clear() {
        currentLocation = nil
        locationName = nil
        localityGroup = nil
        statusText = nil
        isLocating = false
        captureStartTime = nil
        timeoutTask?.cancel()
        geocoder.cancelGeocode()
    }

    // MARK: - 定位流程

    private func beginCapture() {
        // 1) 系统缓存的最近位置立刻可用，先采用它
        if let cached = manager.location {
            adopt(cached)
        }
        // 2) 再请求一次新定位，第一个结果即停，保证速度
        isLocating = true
        captureStartTime = Date()
        manager.startUpdatingLocation()
        scheduleTimeout()
    }

    private func scheduleTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self, self.isLocating else { return }
            self.manager.stopUpdatingLocation()
            self.isLocating = false
            self.captureStartTime = nil
            if self.currentLocation == nil {
                self.statusText = "暂时无法获取位置，请稍后重试"
            }
        }
    }

    /// 采用一个位置并解析地名
    private func adopt(_ location: CLLocation) {
        currentLocation = location
        if resolveFromCache(location) { return }
        reverseGeocode(location)
    }

    // MARK: - 地名解析（带缓存）

    private func cacheKey(for location: CLLocation) -> String {
        // 约 0.002°（≈200 米）粒度分桶
        "\(Int(location.coordinate.latitude / 0.002))|\(Int(location.coordinate.longitude / 0.002))"
    }

    private func resolveFromCache(_ location: CLLocation) -> Bool {
        if let cached = geocodeCache[cacheKey(for: location)] {
            locationName = cached.name
            localityGroup = cached.locality
            return true
        }
        // 200 米内直接沿用上一次解析结果
        if let previous = lastGeocodedLocation,
           let name = locationName,
           previous.distance(from: location) < 200 {
            _ = name
            return true
        }
        return false
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN")) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let placemark = placemarks?.first {
                    self.lastGeocodedLocation = location
                    self.locationName = self.formatName(placemark) ?? self.formatCoordinate(location)
                    self.localityGroup = placemark.locality ?? placemark.administrativeArea
                    self.geocodeCache[self.cacheKey(for: location)] = (self.locationName, self.localityGroup)
                } else {
                    // 解析失败不阻塞：坐标兜底立即展示
                    self.locationName = self.formatCoordinate(location)
                    if let error {
                        self.statusText = "地点解析失败：\(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func formatName(_ placemark: CLPlacemark) -> String? {
        var parts: [String] = []
        if let locality = placemark.locality { parts.append(locality) }
        if let subLocality = placemark.subLocality, subLocality != placemark.locality { parts.append(subLocality) }
        if parts.isEmpty, let area = placemark.administrativeArea { parts.append(area) }
        if parts.isEmpty, let name = placemark.name { parts.append(name) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func formatCoordinate(_ location: CLLocation) -> String {
        String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if isLocating { beginCapture() }
        case .denied, .restricted:
            isLocating = false
            statusText = "未获得定位权限，请到系统设置中开启"
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let start = captureStartTime else { return }
        // 只接受本次请求之后产生的新定位，避免拿到陈旧数据
        guard let fresh = locations.last(where: { $0.timestamp >= start }) else { return }
        adopt(fresh)
        manager.stopUpdatingLocation()
        isLocating = false
        captureStartTime = nil
        timeoutTask?.cancel()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 已有缓存结果时静默忽略，不打断用户
        if currentLocation == nil {
            statusText = "定位失败：\(error.localizedDescription)"
        }
    }
}
