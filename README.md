# AtlasView

AtlasView is an interactive world-time map for iPhone. Move the map or jump to a city to see the local time, place, time-zone name, UTC difference, and the real geographic boundary of the selected time zone.

## Features

- Automatic time-zone and place detection at the map crosshair
- Analog and digital clocks updated in real time
- Transparent, draggable glass-style information card
- Horizontally scrollable city and time-zone shortcuts
- Real-world time-zone boundaries with highlighting for the selected zone
- Correct handling of daylight-saving time and fractional UTC offsets
- Offline bundled time-zone boundary geometry
- Accessibility label for the analog clock

## Requirements

- iOS 17 or later
- Xcode 26 or later

The app uses newer Liquid Glass effects when available and falls back to standard SwiftUI materials on earlier supported iOS versions.

## Building

1. Open `iMapView.xcodeproj` in Xcode.
2. Select the `iMapView` scheme.
3. Choose an iPhone or iOS Simulator.
4. Build and run.

For installation on a physical device, select your Apple Development team in the target's Signing & Capabilities settings.

## Basic iPhone Duo support

The map uses the available window space and the system safe areas. At widths of 760 points or more, the clock card starts at the leading edge to leave the map crosshair clear. Narrower windows retain the centered card. Dragging is bounded by the available card area, and its position is constrained again when the window or card size changes. Folding does not recreate the map or reset the selected time zone.

Build with the iOS 27.1 SDK or later for the Duo's full-display presentation, including system-managed vertical bars. Earlier SDK builds use Apple's compatibility presentation. No Duo-specific device detection or deployment-target change is required.

To validate on a Duo, dismiss the welcome screen, select a city, drag the card toward the lower trailing corner, then fold, unfold, and rotate. Check that the selected city remains selected, the card's drag handle stays reachable, and the city strip and Help button remain within the safe area. Repeat with larger text enabled and with the Help sheet open. Device validation is still required before claiming complete Duo support.

## Data and services

- Maps and reverse geocoding: Apple MapKit and Core Location
- Time-zone rules: the system IANA time-zone database through Foundation
- Boundary geometry: [Timezone Boundary Builder](https://github.com/evansiroky/timezone-boundary-builder), derived from [OpenStreetMap](https://www.openstreetmap.org/copyright) data

The bundled boundary geometry is simplified for efficient rendering on mobile devices.

## Privacy

See [PRIVACY.md](PRIVACY.md).
