import Foundation
import CoreLocation
import Combine
import MapKit

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

    private var request: Task<Void, Never>?

    deinit {
        request?.cancel()
    }

    func resolveTimeZone(at coordinate: CLLocationCoordinate2D) {
        hasResolvedInitialLocation = true
        request?.cancel()
        status = .loading

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        request = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self else { return }

                let result = try await Self.reverseGeocode(location)
                guard !Task.isCancelled else { return }

                self.timeZone = result.timeZone
                self.placeName = result.placeName
                self.status = .resolved
            } catch is CancellationError {
                // A newer camera position superseded this request.
            } catch {
                guard !Task.isCancelled else { return }
                self?.status = .failed
            }
        }
    }

    private static func reverseGeocode(_ location: CLLocation) async throws -> (timeZone: TimeZone, placeName: String) {
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let mapItem = try await request.mapItems.first,
                  let timeZone = mapItem.timeZone else {
                throw CocoaError(.coderValueNotFound)
            }

            let address = mapItem.addressRepresentations
            let placeName = address?.cityWithContext(.automatic)
                ?? address?.regionName
                ?? timeZone.identifier.replacingOccurrences(of: "_", with: " ")
            return (timeZone, placeName)
        } else {
            return try await legacyReverseGeocode(location)
        }
    }

    @available(iOS, introduced: 5.0, deprecated: 26.0)
    private static func legacyReverseGeocode(_ location: CLLocation) async throws -> (timeZone: TimeZone, placeName: String) {
        let placemark = try await CLGeocoder().reverseGeocodeLocation(location).first
        guard let timeZone = placemark?.timeZone else {
            throw CocoaError(.coderValueNotFound)
        }
        return (timeZone, placeName(from: placemark, fallback: timeZone))
    }

    private static func placeName(from placemark: CLPlacemark?, fallback: TimeZone) -> String {
        if let locality = placemark?.locality, let country = placemark?.country {
            return "\(locality), \(country)"
        }
        return placemark?.country ?? fallback.identifier.replacingOccurrences(of: "_", with: " ")
    }
}
