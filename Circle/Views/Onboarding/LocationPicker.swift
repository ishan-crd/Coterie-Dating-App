//
//  LocationPicker.swift
//  Circle
//
//  A map-based location chooser, Google-Maps style: search a place (with live
//  autocomplete results), detect your current location, or pan/drag the map
//  under a fixed pin. Everything resolves to a city name.
//

import SwiftUI
import Combine
import MapKit
import CoreLocation

// MARK: - Location manager (current location)

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorization: CLAuthorizationStatus
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
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: break
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

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

// MARK: - Search autocomplete

@MainActor
final class LocationSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    @Published var results: [MKLocalSearchCompletion] = []

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { results = []; return }
        completer.queryFragment = trimmed
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let items = completer.results
        Task { @MainActor in self.results = items }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = [] }
    }
}

// MARK: - Location picker

struct LocationPicker: View {
    @Binding var city: String

    @StateObject private var locationManager = LocationManager()
    @StateObject private var search = LocationSearch()

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var programmaticEdit = false

    private static let defaultCenter = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(center: defaultCenter,
                           span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)))
    @State private var lastGeocoded = defaultCenter
    @State private var resolving = false
    @State private var locating = false
    @State private var pinLift = false

    private var showResults: Bool { searchFocused && !search.results.isEmpty }

    var body: some View {
        VStack(spacing: 14) {
            searchBar

            if showResults {
                resultsList
            } else {
                detectButton
                mapCard
                if locationManager.denied {
                    Label("Location is off. Enable it in Settings, or search / drag the map.",
                          systemImage: "location.slash")
                        .font(.grotesk(12)).foregroundStyle(CT.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: showResults)
        .onAppear {
            setText(city)
            locationManager.onFix = { coord in flyTo(coord) }
        }
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(CT.muted)
            TextField("Search a city or place", text: $searchText)
                .font(.grotesk(16))
                .tint(CT.accent)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .submitLabel(.search)
                .onChange(of: searchText) { _, value in
                    if programmaticEdit { programmaticEdit = false; return }
                    search.update(value)
                    city = value
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""; search.update(""); city = ""; searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16)).foregroundStyle(CT.faint)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(CT.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CT.border, lineWidth: 1))
    }

    // MARK: Results list

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(search.results.prefix(7).enumerated()), id: \.offset) { index, result in
                Button { pick(result) } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 20)).foregroundStyle(CT.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(.grotesk(15, weight: .medium)).foregroundStyle(CT.ink)
                                .lineLimit(1)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.grotesk(12.5)).foregroundStyle(CT.muted).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 13).padding(.horizontal, 15)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < min(search.results.count, 7) - 1 {
                    Rectangle().fill(CT.hairline).frame(height: 1).padding(.leading, 48)
                }
            }
        }
        .background(CT.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(CT.border, lineWidth: 1))
    }

    // MARK: Map

    private var mapCard: some View {
        map
            .frame(height: 300)
            .overlay { centerPin }
            .overlay(alignment: .bottomTrailing) { recenterButton.padding(12) }
            .overlay(alignment: .bottomLeading) { if resolving { resolvingBadge.padding(12) } }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(CT.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 10)
    }

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
        .offset(y: -18)
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

    // MARK: Actions

    /// Set the search field programmatically without re-triggering autocomplete.
    private func setText(_ value: String) {
        programmaticEdit = true
        searchText = value
    }

    private func pick(_ completion: MKLocalSearchCompletion) {
        searchFocused = false
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            guard let item = response?.mapItems.first else { return }
            let coord = item.placemark.coordinate
            let name = item.placemark.locality
                ?? item.placemark.name
                ?? completion.title
            setText(name)
            city = name
            search.results = []
            flyTo(coord)
        }
    }

    private func locate() {
        locating = true
        locationManager.requestLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { locating = false }
    }

    private func flyTo(_ coord: CLLocationCoordinate2D) {
        locating = false
        lastGeocoded = coord
        withAnimation(.easeInOut(duration: 0.6)) {
            position = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)))
        }
        reverseGeocode(coord)
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        resolving = true
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
            resolving = false
            guard let p = placemarks?.first else { return }
            let name = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? p.country
            if let name, !name.isEmpty {
                setText(name)
                city = name
            }
        }
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
