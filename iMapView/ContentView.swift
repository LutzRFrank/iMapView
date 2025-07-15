
//
//  ContentView.swift – Final Version (Alle Fehler behoben)
//

import SwiftUI
import MapKit
import Combine

// MARK: - Theme

struct Theme {
    let colorScheme: ColorScheme

    var primary: Color { colorScheme == .dark ? .white : .black }
    var secondary: Color { colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.2) }
    var accent: Color { colorScheme == .dark ? .white : .black }
    var background: Color { Color(.systemBackground) }
    var containerBackground: Color { Color(.secondarySystemBackground) }
    var mapOverlay: Color { colorScheme == .dark ? .black.opacity(0.7) : .white.opacity(0.7) }
    var buttonBackground: Color { colorScheme == .dark ? .white : .blue }
    var buttonText: Color { colorScheme == .dark ? .black : .white }
}

// MARK: - TimeZoneView

struct TimeZoneView: View {
    @Environment(\.colorScheme) var colorScheme
    let timeZone: TimeZone
    @Binding var selectedTimeZone: TimeZone
    let isFavorite: Bool
    let toggleFavorite: () -> Void

    private var theme: Theme { Theme(colorScheme: colorScheme) }

    private func displayName() -> String {
        let hours = timeZone.secondsFromGMT() / 3600
        return hours == 0 ? "UTC" : "UTC\(hours >= 0 ? "+" : "")\(hours)"
    }

    private func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(displayName())
                    .font(.caption)
                if isFavorite {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.red)
                }
            }
            .foregroundColor(theme.primary)

            Text(currentTime())
                .font(.caption2)
                .foregroundColor(theme.primary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(timeZone == selectedTimeZone ? theme.secondary.opacity(0.2) : Color.clear)
        )
        .onTapGesture {
            selectedTimeZone = timeZone
        }
        .onLongPressGesture {
            toggleFavorite()
        }
    }
}

// MARK: - ClockView

struct ClockView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var currentTime = Date()
    @Binding var selectedTimeZone: TimeZone

    private var theme: Theme { Theme(colorScheme: colorScheme) }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = selectedTimeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: currentTime)
    }

    private func angle(for component: Calendar.Component, divisor: Double) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: selectedTimeZone, from: currentTime)
        let value = components.value(for: component) ?? 0
        return Double(value) * 360.0 / divisor
    }

    var body: some View {
        VStack(spacing: 60) {
            Text(formattedTime())
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(theme.primary)

            ZStack {
                Circle().stroke(theme.secondary, lineWidth: 4)

                ForEach(0..<12) { hour in
                    Rectangle()
                        .fill(theme.primary)
                        .frame(width: 2, height: 15)
                        .offset(y: -70)
                        .rotationEffect(.degrees(Double(hour) * 30))
                }

                ForEach(0..<60) { minute in
                    Rectangle()
                        .fill(theme.primary.opacity(0.5))
                        .frame(width: 1, height: 8)
                        .offset(y: -70)
                        .rotationEffect(.degrees(Double(minute) * 6))
                }

                Group {
                    Rectangle()
                        .fill(theme.primary)
                        .frame(width: 4, height: 40)
                        .offset(y: -20)
                        .rotationEffect(.degrees(angle(for: .hour, divisor: 12)))

                    Rectangle()
                        .fill(theme.primary.opacity(0.8))
                        .frame(width: 3, height: 60)
                        .offset(y: -30)
                        .rotationEffect(.degrees(angle(for: .minute, divisor: 60)))

                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 1, height: 70)
                        .offset(y: -35)
                        .rotationEffect(.degrees(angle(for: .second, divisor: 60)))

                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 150, height: 150)
        }
        .onReceive(timer) { currentTime = $0 }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTimeZone = TimeZone(identifier: "GMT") ?? .current
    @AppStorage("favoriteTimeZones") private var favoriteRaw: String = "[]"

    private var favoriteIdentifiers: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: Data(favoriteRaw.utf8))) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                favoriteRaw = string
            }
        }
    }

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
    )

    private var theme: Theme { Theme(colorScheme: colorScheme) }

    private let timeZones: [TimeZone] = [
        "America/Los_Angeles", "America/Denver", "America/Chicago",
        "America/New_York", "America/Halifax", "America/Sao_Paulo",
        "Atlantic/South_Georgia", "Atlantic/Azores", "GMT",
        "Europe/Paris", "Europe/Kiev", "Europe/Moscow",
        "Asia/Shanghai", "Asia/Tokyo"
    ].compactMap(TimeZone.init(identifier:))

    private func timeZoneFrom(longitude: Double) -> TimeZone {
        let offsetHours = Int(round(longitude / 15.0))
        let seconds = offsetHours * 3600
        return timeZones.min(by: { abs($0.secondsFromGMT() - seconds) < abs($1.secondsFromGMT() - seconds) }) ?? .current
    }

    private func updateRegion(for timeZone: TimeZone) {
        let offset = Double(timeZone.secondsFromGMT()) / 3600.0
        let longitude = offset * 15.0
        let delta = max(20.0, abs(longitude) * 2)
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
    }

    private func timeDifferenceText(from base: TimeZone, to target: TimeZone) -> String {
        let diff = (target.secondsFromGMT() - base.secondsFromGMT()) / 3600
        if diff == 0 { return "gleich wie hier" }
        return diff > 0 ? "\(diff)h vor dir" : "\(-diff)h hinter dir"
    }

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 15)
                .fill(theme.containerBackground)
                .frame(height: 140)
                .overlay(
                    VStack(spacing: 6) {
                        Text(selectedTimeZone.localizedName(for: .generic, locale: .current) ?? selectedTimeZone.identifier)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.primary)

                        Text(timeDifferenceText(from: .current, to: selectedTimeZone))
                            .font(.system(size: 18))
                            .foregroundColor(theme.primary)
                    }
                )
                .padding(.horizontal)

            RoundedRectangle(cornerRadius: 15)
                .fill(theme.containerBackground)
                .overlay(
                    ZStack {
                        if #available(iOS 17.0, *) {
                            Map(position: .constant(.region(region))) {}
                                .mapStyle(.standard(elevation: .flat))
                                .onMapCameraChange { ctx in
                                    let tz = timeZoneFrom(longitude: ctx.region.center.longitude)
                                    if tz != selectedTimeZone {
                                        selectedTimeZone = tz
                                        updateRegion(for: tz)
                                    }
                                }
                        } else {
                            Map(coordinateRegion: $region)
                                .onAppear {
                                    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                                        let tz = timeZoneFrom(longitude: region.center.longitude)
                                        if tz != selectedTimeZone {
                                            selectedTimeZone = tz
                                            updateRegion(for: tz)
                                        }
                                    }
                                }
                        }

                        Color(.secondarySystemBackground)
                            .opacity(colorScheme == .dark ? 0.2 : 0.4)
                            .allowsHitTesting(false)

                        VStack {
                            ClockView(selectedTimeZone: $selectedTimeZone)
                                .padding()
                            Text(selectedTimeZone.identifier)
                                .font(.caption)
                                .foregroundColor(theme.primary)
                        }
                    }
                )
                .padding(.horizontal)
                .onChange(of: selectedTimeZone) { updateRegion(for: $1) }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(timeZones, id: \.identifier) { tz in
                        TimeZoneView(
                            timeZone: tz,
                            selectedTimeZone: $selectedTimeZone,
                            isFavorite: favoriteIdentifiers.contains(tz.identifier),
                            toggleFavorite: {
                                if var decoded = try? JSONDecoder().decode([String].self, from: Data(favoriteRaw.utf8)) {
                                    if let index = decoded.firstIndex(of: tz.identifier) {
                                        decoded.remove(at: index)
                                    } else {
                                        decoded.append(tz.identifier)
                                    }
                                    if let encoded = try? JSONEncoder().encode(decoded),
                                       let encodedString = String(data: encoded, encoding: .utf8) {
                                        favoriteRaw = encodedString
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 60)
            .background(theme.containerBackground)
        }
        .padding(.top, 20)
        .onAppear {
            updateRegion(for: selectedTimeZone)
        }
    }
}

#Preview {
    ContentView()
}
