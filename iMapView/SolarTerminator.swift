import Foundation
import MapKit

struct SolarTwilightOverlay: Identifiable {
    let id: Int
    let polygon: MKPolygon
    let opacity: Double
}

enum SolarTerminator {
    private struct Point {
        var longitude: Double
        var latitude: Double
    }

    private static let sampleCount = 360
    private static let altitudeSteps = stride(from: 0.0, through: -18.0, by: -1.5).map { $0 }

    static func twilightOverlays(at date: Date) -> [SolarTwilightOverlay] {
        let antiSolarPoint = antiSolarCoordinate(at: date)

        return altitudeSteps.enumerated().flatMap { bandIndex, solarAltitude in
            let angularRadius = 90 + solarAltitude
            return polygons(around: antiSolarPoint, radius: angularRadius).enumerated().map {
                pieceIndex, polygon in
                SolarTwilightOverlay(
                    id: bandIndex * 10 + pieceIndex,
                    polygon: polygon,
                    opacity: 0.035
                )
            }
        }
    }

    private static func antiSolarCoordinate(at date: Date) -> CLLocationCoordinate2D {
        let julianDate = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let daysSinceJ2000 = julianDate - 2_451_545

        let meanLongitude = normalizedDegrees(280.460 + 0.985_647_4 * daysSinceJ2000)
        let meanAnomaly = degreesToRadians(
            normalizedDegrees(357.528 + 0.985_600_3 * daysSinceJ2000)
        )
        let eclipticLongitude = degreesToRadians(
            meanLongitude
                + 1.915 * sin(meanAnomaly)
                + 0.020 * sin(2 * meanAnomaly)
        )
        let obliquity = degreesToRadians(23.439 - 0.000_000_4 * daysSinceJ2000)

        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscension = atan2(
            cos(obliquity) * sin(eclipticLongitude),
            cos(eclipticLongitude)
        )
        let greenwichSiderealTime = normalizedDegrees(
            280.460_618_37 + 360.985_647_366_29 * daysSinceJ2000
        )
        let subsolarLongitude = normalizedLongitude(
            radiansToDegrees(rightAscension) - greenwichSiderealTime
        )

        return CLLocationCoordinate2D(
            latitude: -radiansToDegrees(declination),
            longitude: normalizedLongitude(subsolarLongitude + 180)
        )
    }

    private static func polygons(
        around center: CLLocationCoordinate2D,
        radius: Double
    ) -> [MKPolygon] {
        let distanceToNearestPole = 90 - abs(center.latitude)
        let ring = radius >= distanceToNearestPole
            ? polarCap(around: center, radius: radius)
            : closedSmallCircle(around: center, radius: radius)

        let minimumLongitude = ring.map(\.longitude).min() ?? -180
        let maximumLongitude = ring.map(\.longitude).max() ?? 180
        let firstWorld = Int(floor((minimumLongitude + 180) / 360))
        let lastWorld = Int(floor((maximumLongitude + 180) / 360))

        return (firstWorld...lastWorld).compactMap { world in
            let offset = Double(world) * 360
            let clipped = clip(
                ring,
                minimumLongitude: offset - 180,
                maximumLongitude: offset + 180
            )
            guard clipped.count >= 3 else { return nil }

            let coordinates = clipped.map {
                CLLocationCoordinate2D(
                    latitude: max(-89.999, min(89.999, $0.latitude)),
                    longitude: max(-180, min(180, $0.longitude - offset))
                )
            }
            return MKPolygon(coordinates: coordinates, count: coordinates.count)
        }
    }

    private static func closedSmallCircle(
        around center: CLLocationCoordinate2D,
        radius: Double
    ) -> [Point] {
        let centerLatitude = degreesToRadians(center.latitude)
        let centerLongitude = degreesToRadians(center.longitude)
        let angularRadius = degreesToRadians(radius)
        var previousLongitude: Double?

        return (0..<sampleCount).map { sample in
            let bearing = 2 * Double.pi * Double(sample) / Double(sampleCount)
            let latitude = asin(
                sin(centerLatitude) * cos(angularRadius)
                    + cos(centerLatitude) * sin(angularRadius) * cos(bearing)
            )
            let longitude = centerLongitude + atan2(
                sin(bearing) * sin(angularRadius) * cos(centerLatitude),
                cos(angularRadius) - sin(centerLatitude) * sin(latitude)
            )
            var longitudeDegrees = radiansToDegrees(longitude)

            if let previousLongitude {
                while longitudeDegrees - previousLongitude > 180 { longitudeDegrees -= 360 }
                while previousLongitude - longitudeDegrees > 180 { longitudeDegrees += 360 }
            }
            previousLongitude = longitudeDegrees
            return Point(longitude: longitudeDegrees, latitude: radiansToDegrees(latitude))
        }
    }

    private static func polarCap(
        around center: CLLocationCoordinate2D,
        radius: Double
    ) -> [Point] {
        let poleLatitude = center.latitude >= 0 ? 89.999 : -89.999
        let oppositePoleLatitude = -poleLatitude
        let startLongitude = center.longitude - 180
        let step = 360 / Double(sampleCount)

        var points = [Point(longitude: startLongitude, latitude: poleLatitude)]
        points += (0...sampleCount).map { sample in
            let longitude = startLongitude + Double(sample) * step
            var insideLatitude = poleLatitude
            var outsideLatitude = oppositePoleLatitude

            for _ in 0..<32 {
                let midpoint = (insideLatitude + outsideLatitude) / 2
                if angularDistance(
                    from: CLLocationCoordinate2D(latitude: midpoint, longitude: longitude),
                    to: center
                ) <= radius {
                    insideLatitude = midpoint
                } else {
                    outsideLatitude = midpoint
                }
            }
            return Point(longitude: longitude, latitude: (insideLatitude + outsideLatitude) / 2)
        }
        points.append(Point(longitude: startLongitude + 360, latitude: poleLatitude))
        return points
    }

    private static func clip(
        _ polygon: [Point],
        minimumLongitude: Double,
        maximumLongitude: Double
    ) -> [Point] {
        let afterMinimum = clip(polygon, boundary: minimumLongitude, keepsGreaterValues: true)
        return clip(afterMinimum, boundary: maximumLongitude, keepsGreaterValues: false)
    }

    private static func clip(
        _ polygon: [Point],
        boundary: Double,
        keepsGreaterValues: Bool
    ) -> [Point] {
        guard var previous = polygon.last else { return [] }
        var result: [Point] = []

        for current in polygon {
            let previousInside = keepsGreaterValues
                ? previous.longitude >= boundary
                : previous.longitude <= boundary
            let currentInside = keepsGreaterValues
                ? current.longitude >= boundary
                : current.longitude <= boundary

            if currentInside != previousInside {
                let fraction = (boundary - previous.longitude) / (current.longitude - previous.longitude)
                result.append(
                    Point(
                        longitude: boundary,
                        latitude: previous.latitude + fraction * (current.latitude - previous.latitude)
                    )
                )
            }
            if currentInside {
                result.append(current)
            }
            previous = current
        }
        return result
    }

    private static func angularDistance(
        from first: CLLocationCoordinate2D,
        to second: CLLocationCoordinate2D
    ) -> Double {
        let firstLatitude = degreesToRadians(first.latitude)
        let secondLatitude = degreesToRadians(second.latitude)
        let longitudeDifference = degreesToRadians(first.longitude - second.longitude)
        let cosine = sin(firstLatitude) * sin(secondLatitude)
            + cos(firstLatitude) * cos(secondLatitude) * cos(longitudeDifference)
        return radiansToDegrees(acos(max(-1, min(1, cosine))))
    }

    private static func normalizedDegrees(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }

    private static func normalizedLongitude(_ longitude: Double) -> Double {
        normalizedDegrees(longitude + 180) - 180
    }

    private static func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }

    private static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}
