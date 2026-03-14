import Foundation
import CoreLocation

final class GeolocationHandler: NSObject, NativeHandler, CLLocationManagerDelegate {
    let namespace = "geolocation"

    var onAsyncCallback: ((String, Any?) -> Void)?

    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        return manager
    }()

    private var pendingCallbackRef: String?

    func handle(method: String, args: [String: Any]) -> Any? {
        switch method {
        case "getCurrentPosition":
            let ref = args["_callbackRef"] as? String
            pendingCallbackRef = ref
            locationManager.requestLocation()
            return ["status": "locating"]

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
        guard let location = locations.last, let ref = pendingCallbackRef else { return }
        pendingCallbackRef = nil

        onAsyncCallback?(ref, [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "altitude": location.altitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": location.timestamp.timeIntervalSince1970
        ])
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        dbg.error("Geolocation", "Location error: \(error.localizedDescription)")
        guard let ref = pendingCallbackRef else { return }
        pendingCallbackRef = nil
        onAsyncCallback?(ref, ["error": error.localizedDescription])
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
