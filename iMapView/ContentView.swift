import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    private let loadsLiveData: Bool

    private static let destinations: [TimeZoneDestination] = [
        .init(city: "Honolulu", identifier: "Pacific/Honolulu", latitude: 21.31, longitude: -157.86),
        .init(city: "Los Angeles", identifier: "America/Los_Angeles", latitude: 34.05, longitude: -118.24),
        .init(city: "New York", identifier: "America/New_York", latitude: 40.71, longitude: -74.01),
        .init(city: "São Paulo", identifier: "America/Sao_Paulo", latitude: -23.55, longitude: -46.63),
        .init(city: "London", identifier: "Europe/London", latitude: 51.51, longitude: -0.13),
        .init(city: "Berlin", identifier: "Europe/Berlin", latitude: 52.52, longitude: 13.41),
        .init(city: "Cairo", identifier: "Africa/Cairo", latitude: 30.04, longitude: 31.24),
        .init(city: "Dubai", identifier: "Asia/Dubai", latitude: 25.20, longitude: 55.27),
        .init(city: "Delhi", identifier: "Asia/Kolkata", latitude: 28.61, longitude: 77.21),
        .init(city: "Kathmandu", identifier: "Asia/Kathmandu", latitude: 27.72, longitude: 85.32),
        .init(city: "Bangkok", identifier: "Asia/Bangkok", latitude: 13.76, longitude: 100.50),
        .init(city: "Tokyo", identifier: "Asia/Tokyo", latitude: 35.68, longitude: 139.69),
        .init(city: "Sydney", identifier: "Australia/Sydney", latitude: -33.87, longitude: 151.21),
        .init(city: "Auckland", identifier: "Pacific/Auckland", latitude: -36.85, longitude: 174.76)
    ]

    @StateObject private var model = TimeZoneMapModel()
    @StateObject private var boundaryModel = TimeZoneBoundaryModel()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 85, longitudeDelta: 85)
        )
    )
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var isShowingHelp = false

    init(loadsLiveData: Bool = true) {
        self.loadsLiveData = loadsLiveData
    }

    private var selectedBoundaryIdentifiers: Set<String> {
        let identifiers = Set(boundaryModel.polygons.map(\.timeZoneIdentifier))
        return Set(identifiers.filter { candidate in
            guard let candidateTimeZone = TimeZone(identifier: candidate) else { return false }
            return TimeZoneRuleMatcher.hasSameRules(candidateTimeZone, model.timeZone)
        })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition, interactionModes: .all) {
                    ForEach(boundaryModel.polygons) { boundary in
                        let isSelected = selectedBoundaryIdentifiers.contains(boundary.timeZoneIdentifier)
                        MapPolygon(boundary.polygon)
                            .foregroundStyle(isSelected ? .blue.opacity(0.08) : .clear)
                            .stroke(
                                isSelected ? .blue.opacity(0.72) : .primary.opacity(0.22),
                                lineWidth: isSelected ? 1.6 : 0.65
                            )
                    }
                }
                    .mapStyle(.standard(elevation: .flat))
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                    }
                    .onMapCameraChange(frequency: .onEnd) { context in
                        guard loadsLiveData else { return }
                        model.resolveTimeZone(at: context.region.center)
                    }
                    .ignoresSafeArea(edges: .bottom)

                Crosshair()
                    .allowsHitTesting(false)

                VStack {
                    DraggableTimeZoneCard(model: model)
                    Spacer()
                    statusPill
                    TimeZoneStrip(destinations: Self.destinations, selectedIdentifier: model.timeZone.identifier) { destination in
                        withAnimation(.easeInOut(duration: 0.8)) {
                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: destination.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
                                )
                            )
                        }
                        model.resolveTimeZone(at: destination.coordinate)
                    }
                }
                .padding()
            }
            .navigationTitle("World Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingHelp = true
                    } label: {
                        Label("Hilfe", systemImage: "questionmark.circle")
                    }
                }
            }
            .task {
                guard loadsLiveData else { return }
                guard !model.hasResolvedInitialLocation else { return }
                model.resolveTimeZone(at: CLLocationCoordinate2D(latitude: 30, longitude: 0))
            }
            .task {
                guard loadsLiveData else { return }
                await boundaryModel.loadIfNeeded()
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { !hasSeenWelcome },
                set: { isPresented in
                    if !isPresented {
                        hasSeenWelcome = true
                    }
                }
            )
        ) {
            WelcomeView(buttonTitle: "Los geht’s") {
                hasSeenWelcome = true
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isShowingHelp) {
            WelcomeView(buttonTitle: "Schließen") {
                isShowingHelp = false
            }
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        switch model.status {
        case .idle:
            Label("Karte bewegen, um eine Zeitzone zu wählen", systemImage: "hand.draw")
                .statusPillStyle()
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Zeitzone wird bestimmt …")
            }
            .statusPillStyle()
        case .resolved:
            EmptyView()
        case .failed:
            Label("Hier konnte keine Zeitzone bestimmt werden", systemImage: "exclamationmark.triangle")
                .statusPillStyle()
        }
    }
}

private struct DraggableTimeZoneCard: View {
    @ObservedObject var model: TimeZoneMapModel
    @State private var offset: CGSize = .zero
    @State private var dragStartOffset: CGSize?

    var body: some View {
        TimeZoneCard(model: model)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.secondary.opacity(0.45))
                    .frame(width: 42, height: 5)
                    .frame(width: 72, height: 30)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                if dragStartOffset == nil {
                                    dragStartOffset = offset
                                }
                                guard let startOffset = dragStartOffset else { return }
                                offset = CGSize(
                                    width: startOffset.width + value.translation.width,
                                    height: startOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                dragStartOffset = nil
                            }
                    )
            }
            .offset(offset)
    }
}

private struct WelcomeView: View {
    let buttonTitle: String
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 14) {
                        Image(systemName: "globe.europe.africa.fill")
                            .font(.system(size: 76))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)

                        Text("Willkommen bei iMapView")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)

                        Text("Entdecke Zeitzonen auf der Weltkarte und vergleiche die Ortszeit auf einen Blick.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 22) {
                        WelcomeFeature(
                            icon: "hand.draw",
                            title: "Karte bewegen",
                            description: "Positioniere das Fadenkreuz über einem Ort, um dessen Zeitzone anzuzeigen."
                        )
                        WelcomeFeature(
                            icon: "map",
                            title: "Zeitzonengrenzen erkennen",
                            description: "Die passende Zeitzone und Gebiete mit denselben Zeitregeln werden hervorgehoben."
                        )
                        WelcomeFeature(
                            icon: "clock",
                            title: "Ortszeit vergleichen",
                            description: "Die Uhrkarte zeigt Zeit, Namen und Unterschied zu deiner aktuellen Zeitzone."
                        )
                        WelcomeFeature(
                            icon: "arrow.left.and.right",
                            title: "Städte direkt auswählen",
                            description: "Wische durch die Leiste am unteren Rand und tippe auf eine Stadt."
                        )
                    }
                    .frame(maxWidth: 560)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 44)
                .padding(.bottom, 32)
            }
            .background {
                LinearGradient(
                    colors: [.blue.opacity(0.12), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
            .safeAreaInset(edge: .bottom) {
                Button(buttonTitle, action: dismiss)
                    .font(.headline)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(.bar)
            }
        }
    }
}

private struct WelcomeFeature: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private enum TimeZoneRuleMatcher {
    static func hasSameRules(_ lhs: TimeZone, _ rhs: TimeZone) -> Bool {
        if lhs.identifier == rhs.identifier { return true }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let currentYear = calendar.component(.year, from: .now)

        for year in currentYear...(currentYear + 2) {
            for month in 1...12 {
                guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                    continue
                }
                if lhs.secondsFromGMT(for: date) != rhs.secondsFromGMT(for: date) {
                    return false
                }
            }
        }
        return true
    }
}

private struct TimeZoneDestination: Identifiable {
    let city: String
    let identifier: String
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees

    var id: String { identifier }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    var timeZone: TimeZone { TimeZone(identifier: identifier) ?? .gmt }
}

private struct TimeZoneStrip: View {
    let destinations: [TimeZoneDestination]
    let selectedIdentifier: String
    let select: (TimeZoneDestination) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(destinations) { destination in
                        Button {
                            select(destination)
                        } label: {
                            VStack(spacing: 2) {
                                Text(destination.city)
                                    .font(.caption.weight(.semibold))
                                Text(TimeZoneFormatting.time(context.date, in: destination.timeZone))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                if destination.identifier == selectedIdentifier {
                                    Capsule().fill(.primary.opacity(0.10))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 54)
            .frame(maxWidth: 720)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.58)
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.24), lineWidth: 0.75)
            }
        }
    }
}

private struct TimeZoneCard: View {
    @ObservedObject var model: TimeZoneMapModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 14) {
                VStack(spacing: 3) {
                    Text(model.placeName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(TimeZoneFormatting.displayName(for: model.timeZone))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }

                AnalogClock(date: context.date, timeZone: model.timeZone)
                    .frame(width: 132, height: 132)

                Text(TimeZoneFormatting.time(context.date, in: model.timeZone))
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Text(TimeZoneFormatting.difference(from: .current, to: model.timeZone, at: context.date))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 300)
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.58)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.16), radius: 24, y: 10)
        }
    }
}

private struct Crosshair: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .opacity(0.58)
                .frame(width: 38, height: 38)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.24), lineWidth: 0.75)
                }
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
        }
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
    }
}

private struct AnalogClock: View {
    let date: Date
    let timeZone: TimeZone

    private var components: DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.dateComponents([.hour, .minute, .second], from: date)
    }

    var body: some View {
        let hour = Double(components.hour ?? 0).truncatingRemainder(dividingBy: 12)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)

        ZStack {
            clockFace
            Circle()
                .stroke(.white.opacity(0.28), lineWidth: 0.75)

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2

                for index in 0..<12 {
                    let angle = Double(index) * .pi / 6 - .pi / 2
                    let isQuarter = index % 3 == 0
                    let outerRadius = radius - 9
                    let innerRadius = outerRadius - (isQuarter ? 11 : 7)
                    var tick = Path()
                    tick.move(to: CGPoint(
                        x: center.x + cos(angle) * innerRadius,
                        y: center.y + sin(angle) * innerRadius
                    ))
                    tick.addLine(to: CGPoint(
                        x: center.x + cos(angle) * outerRadius,
                        y: center.y + sin(angle) * outerRadius
                    ))
                    context.stroke(
                        tick,
                        with: .color(.primary.opacity(isQuarter ? 0.8 : 0.35)),
                        style: StrokeStyle(lineWidth: isQuarter ? 3 : 2, lineCap: .round)
                    )
                }

                let hands: [(value: Double, length: CGFloat, width: CGFloat, color: Color)] = [
                    ((hour + minute / 60) / 12, 32, 5, .primary),
                    ((minute + second / 60) / 60, 45, 3.5, .primary),
                    (second / 60, 48, 1.5, .red)
                ]

                for hand in hands {
                    let angle = hand.value * 2 * .pi - .pi / 2
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: CGPoint(
                        x: center.x + cos(angle) * hand.length,
                        y: center.y + sin(angle) * hand.length
                    ))
                    context.stroke(
                        path,
                        with: .color(hand.color),
                        style: StrokeStyle(lineWidth: hand.width, lineCap: .round)
                    )
                }
            }

            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TimeZoneFormatting.time(date, in: timeZone))
    }

    @ViewBuilder
    private var clockFace: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.clear, in: .circle)
                .opacity(0.48)
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .opacity(0.55)
        }
    }
}

private extension View {
    func statusPillStyle() -> some View {
        self
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

#Preview {
    ContentView(loadsLiveData: false)
}
