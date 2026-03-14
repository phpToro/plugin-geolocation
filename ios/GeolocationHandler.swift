import Foundation
import CoreLocation

final class GeolocationHandler: NSObject, AsyncHandler, CLLocationManagerDelegate {
    let namespace = "geolocation"

    var onAsyncCallback: ((String, Any?) -> Void)?

    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        return manager
    }()

    private var pendingCallbackRef: String?
    private var watchCallbackRef: String?
    private var isWatching = false

    func handle(method: String, args: [String: Any]) -> Any? {
        switch method {
        case "getCurrentPosition":
            let ref = args["_callbackRef"] as? String
            pendingCallbackRef = ref
            dbg.log("Geolocation", "getCurrentPosition, ref=\(ref ?? "nil")")
            locationManager.requestLocation()
            return ["status": "locating"]

        case "watchPosition":
            let ref = args["_callbackRef"] as? String
            watchCallbackRef = ref
            isWatching = true
            dbg.log("Geolocation", "watchPosition started, ref=\(ref ?? "nil")")
            locationManager.startUpdatingLocation()
            return ["status": "watching"]

        case "stopWatching":
            isWatching = false
            watchCallbackRef = nil
            locationManager.stopUpdatingLocation()
            dbg.log("Geolocation", "stopWatching")
            return ["status": "stopped"]

        case "requestPermission":
            let ref = args["_callbackRef"] as? String
            pendingCallbackRef = ref
            locationManager.requestWhenInUseAuthorization()
            return ["status": "requesting"]

        case "checkPermission":
            let status: String
            switch locationManager.authorizationStatus {
            case .authorizedWhenInUse: status = "whenInUse"
            case .authorizedAlways: status = "always"
            case .denied: status = "denied"
            case .restricted: status = "restricted"
            case .notDetermined: status = "notDetermined"
            @unknown default: status = "unknown"
            }
            return ["status": status]

        default:
            return ["error": "Unknown method: \(method)"]
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let data: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "altitude": location.altitude,
            "accuracy": location.horizontalAccuracy,
            "speed": location.speed,
            "heading": location.course,
            "timestamp": location.timestamp.timeIntervalSince1970
        ]

        // One-time request
        if let ref = pendingCallbackRef {
            pendingCallbackRef = nil
            onAsyncCallback?(ref, data)
        }

        // Live tracking
        if isWatching, let ref = watchCallbackRef {
            onAsyncCallback?(ref, data)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        dbg.error("Geolocation", "Location error: \(error.localizedDescription)")
        if let ref = pendingCallbackRef {
            pendingCallbackRef = nil
            onAsyncCallback?(ref, ["error": error.localizedDescription])
        }
        if isWatching, let ref = watchCallbackRef {
            onAsyncCallback?(ref, ["error": error.localizedDescription])
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let ref = pendingCallbackRef else { return }
        let status: String
        switch manager.authorizationStatus {
        case .authorizedWhenInUse: status = "whenInUse"
        case .authorizedAlways: status = "always"
        case .denied: status = "denied"
        case .restricted: status = "restricted"
        case .notDetermined: return // Still waiting
        @unknown default: status = "unknown"
        }
        pendingCallbackRef = nil
        onAsyncCallback?(ref, ["status": status])
    }
}
