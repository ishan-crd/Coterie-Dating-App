//
//  LocationPicker.swift
//  coterie-ios
//
//  A map-based location chooser: detect the current location, pan/drag the map
//  under a fixed pin to place yourself, and reverse-geocode to a city name.
//

import SwiftUI
import Combine
import MapKit
import CoreLocation

// MARK: - Location manager

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorization: CLAuthorizationStatus
    /// Called once when a fresh fix arrives (after a request).
    var onFix: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var denied: Bool { authorization == .denied || authorization == .restricted }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        Task { @MainActor in self.onFix?(coord) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {}
}

// MARK: - Location picker

struct LocationPicker: View {
    @Binding var city: String

    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                           span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
    )
    @State private var lastGeocoded = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    @State private var resolving = false
    @State private var locating = false
    @State private var pinLift = false

    var body: some View {
        VStack(spacing: 16) {
            detectButton

            map
                .frame(height: 320)
                .overlay { centerPin }
                .overlay(alignment: .bottomTrailing) { recenterButton.padding(12) }
                .overlay(alignment: .bottomLeading) {
                    if resolving { resolvingBadge.padding(12) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(CT.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 10)

            cityField

            if locationManager.denied {
                Label("Location is off. Enable it in Settings, or drag the map to choose.",
                      systemImage: "location.slash")
                    .font(.grotesk(12)).foregroundStyle(CT.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            locationManager.onFix = { coord in flyTo(coord) }
        }
    }

    // MARK: Map

    private var map: some View {
        MapReader { proxy in
            Map(position: $position, interactionModes: [.pan, .zoom]) {}
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .onTapGesture { point in
                    if let coord = proxy.convert(point, from: .local) { flyTo(coord) }
                }
                .onMapCameraChange(frequency: .continuous) { _ in
                    if !pinLift { withAnimation(.easeOut(duration: 0.15)) { pinLift = true } }
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    withAnimation(.easeOut(duration: 0.2)) { pinLift = false }
                    let center = context.region.center
                    if distance(center, lastGeocoded) > 60 {
                        lastGeocoded = center
                        reverseGeocode(center)
                    }
                }
        }
    }

    /// Fixed pin at the map's centre; the map moves beneath it.
    private var centerPin: some View {
        VStack(spacing: 2) {
            Image(systemName: "mappin")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(CT.accent)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                .offset(y: pinLift ? -8 : 0)
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: pinLift ? 14 : 10, height: 4)
                .blur(radius: 1)
        }
        .offset(y: -18)               // lift so the needle tip sits on the centre
        .allowsHitTesting(false)
    }

    private var recenterButton: some View {
        Button { locate() } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CT.accent)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(CT.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }

    private var resolvingBadge: some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini).tint(CT.accent)
            Text("Locating…").font(.grotesk(11, weight: .medium)).foregroundStyle(CT.ink70)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: Controls

    private var detectButton: some View {
        Button { locate() } label: {
            HStack(spacing: 9) {
                if locating {
                    ProgressView().controlSize(.small).tint(CT.accent)
                } else {
                    Image(systemName: "location.circle.fill").font(.system(size: 17, weight: .medium))
                }
                Text(locating ? "Detecting…" : "Detect my location")
                    .font(.grotesk(14, weight: .semibold)).tracking(0.3)
            }
            .foregroundStyle(CT.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(CT.accentSoft)
            .clipShape(Capsule())
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private var cityField: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(CT.muted)
            UnderlineField(placeholder: "Your city", text: $city, fontSize: 24)
        }
    }

    // MARK: Actions

    private func locate() {
        locating = true
        locationManager.requestLocation()
        // Clear the spinner shortly after; the fix (if any) arrives via onFix.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { locating = false }
    }

    private func flyTo(_ coord: CLLocationCoordinate2D) {
        locating = false
        withAnimation(.easeInOut(duration: 0.6)) {
            position = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)))
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        resolving = true
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
            resolving = false
            guard let p = placemarks?.first else { return }
            let name = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? p.country
            if let name, !name.isEmpty { city = name }
        }
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
