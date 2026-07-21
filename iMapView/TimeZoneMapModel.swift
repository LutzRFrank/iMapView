import Foundation
import CoreLocation
import Combine

@MainActor
final class TimeZoneMapModel: ObservableObject {
    enum Status {
        case idle
        case loading
        case resolved
        case failed
    }

    @Published private(set) var timeZone: TimeZone = .current
    @Published private(set) var placeName = "Aktueller Standort"
    @Published private(set) var status: Status = .idle
    private(set) var hasResolvedInitialLocation = false

    private let geocoder = CLGeocoder()
    private var request: Task<Void, Never>?

    deinit {
        request?.cancel()
    }

    func resolveTimeZone(at coordinate: CLLocationCoordinate2D) {
        hasResolvedInitialLocation = true
        request?.cancel()
        geocoder.cancelGeocode()
        status = .loading

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        request = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self else { return }

                let placemark = try await geocoder.reverseGeocodeLocation(location).first
                guard !Task.isCancelled, let timeZone = placemark?.timeZone else { return }

                self.timeZone = timeZone
                self.placeName = Self.placeName(from: placemark, fallback: timeZone)
                self.status = .resolved
            } catch is CancellationError {
                // A newer camera position superseded this request.
            } catch {
                guard !Task.isCancelled else { return }
                self?.status = .failed
            }
        }
    }

    private static func placeName(from placemark: CLPlacemark?, fallback: TimeZone) -> String {
        if let locality = placemark?.locality, let country = placemark?.country {
            return "\(locality), \(country)"
        }
        return placemark?.country ?? fallback.identifier.replacingOccurrences(of: "_", with: " ")
    }
}
