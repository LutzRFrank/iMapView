import Foundation
import MapKit
import Combine

struct TimeZoneBoundaryPolygon: Identifiable {
    let id = UUID()
    let timeZoneIdentifier: String
    let polygon: MKPolygon
}

@MainActor
final class TimeZoneBoundaryModel: ObservableObject {
    @Published private(set) var polygons: [TimeZoneBoundaryPolygon] = []

    func loadIfNeeded() async {
        guard polygons.isEmpty,
              let url = Bundle.main.url(forResource: "timezone-boundaries", withExtension: "geojson") else {
            return
        }

        do {
            let data = try await Task.detached(priority: .utility) {
                try Data(contentsOf: url)
            }.value
            let objects = try MKGeoJSONDecoder().decode(data)
            polygons = objects.flatMap(Self.boundaries(from:))
        } catch {
            assertionFailure("Zeitzonengrenzen konnten nicht geladen werden: \(error)")
        }
    }

    private static func boundaries(from object: MKGeoJSONObject) -> [TimeZoneBoundaryPolygon] {
        guard let feature = object as? MKGeoJSONFeature,
              let properties = feature.properties,
              let dictionary = try? JSONSerialization.jsonObject(with: properties) as? [String: String],
              let identifier = dictionary["tzid"] else {
            return []
        }

        return feature.geometry.flatMap { geometry in
            if let polygon = geometry as? MKPolygon {
                return [TimeZoneBoundaryPolygon(timeZoneIdentifier: identifier, polygon: polygon)]
            }
            if let multiPolygon = geometry as? MKMultiPolygon {
                return multiPolygon.polygons.map {
                    TimeZoneBoundaryPolygon(timeZoneIdentifier: identifier, polygon: $0)
                }
            }
            return []
        }
    }
}
