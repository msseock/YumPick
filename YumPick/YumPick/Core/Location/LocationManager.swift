import CoreLocation
import Foundation

protocol LocationManagerProtocol {
    func currentLocation() async -> Geolocation?
}

final class LocationManager: NSObject, LocationManagerProtocol, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let clManager = CLLocationManager()
    private var continuations: [CheckedContinuation<Geolocation?, Never>] = []
    private var isRequestingLocation = false

    private override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async -> Geolocation? {
        guard clManager.authorizationStatus != .denied,
              clManager.authorizationStatus != .restricted else {
            return nil
        }

        clManager.requestWhenInUseAuthorization()
        return await withCheckedContinuation { cont in
            self.continuations.append(cont)

            guard !self.isRequestingLocation else { return }
            self.isRequestingLocation = true
            self.clManager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            resumeContinuations(returning: nil)
            return
        }
        resumeContinuations(returning: Geolocation(
            longitude: loc.coordinate.longitude,
            latitude: loc.coordinate.latitude
        ))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resumeContinuations(returning: nil)
    }

    private func resumeContinuations(returning location: Geolocation?) {
        continuations.forEach { $0.resume(returning: location) }
        continuations.removeAll()
        isRequestingLocation = false
    }
}
