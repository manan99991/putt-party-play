import SwiftUI
import MapKit
import CoreLocation
import UIKit

/// One tap saves where you parked; one tap walks you back. It drops a pin at your spot and hands
/// directions to Maps — no more wandering a parking garage.
struct ParkView: View {
    @StateObject private var loc = OneShotLocation()
    @State private var saved: CLLocationCoordinate2D? = ParkStore.load()
    @State private var savedAt: Date? = ParkStore.date()
    @State private var note = ParkStore.note()

    var body: some View {
        ToolPage(title: "Where Did I Park", subtitle: "Save the spot now. Find it later.") {
            if let saved {
                Map(initialPosition: .region(MKCoordinateRegion(center: saved, latitudinalMeters: 200, longitudinalMeters: 200))) {
                    Marker("Your car", systemImage: "car.fill", coordinate: saved).tint(HandyColor.accent)
                }
                .frame(height: 240).clipShape(RoundedRectangle(cornerRadius: HandyRadius.card, style: .continuous))
                if let savedAt { Text("Saved \(savedAt.formatted(.relative(presentation: .named)))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
                TextField("Note (e.g. Level 3, near lift)", text: $note).textFieldStyle(.roundedBorder)
                    .onChange(of: note) { _, n in ParkStore.setNote(n) }
                HStack(spacing: HandySpacing.s12) {
                    Button { directions(to: saved) } label: { Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill").frame(maxWidth: .infinity) }.primaryButton()
                    Button { save() } label: { Label("Re-save here", systemImage: "mappin.and.ellipse").frame(maxWidth: .infinity) }.compactButton()
                }
            } else {
                VStack(spacing: HandySpacing.s12) {
                    Image(systemName: "car.fill").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
                    Text("Park, then tap below to remember this spot.").font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
                    Button { save() } label: { Label("Save my spot", systemImage: "mappin.and.ellipse").frame(maxWidth: .infinity) }.primaryButton()
                }.frame(maxWidth: .infinity).padding(.top, HandySpacing.s24)
            }
            if loc.denied {
                Text("Location is off. Turn it on in Settings so Tenzy can mark your spot.").font(HandyFont.caption).foregroundStyle(HandyColor.danger)
            }
        }
        .onReceive(loc.$coordinate.compactMap { $0 }) { c in
            saved = c; savedAt = Date(); ParkStore.save(c)
        }
    }

    private func save() { loc.requestOnce() }
    private func directions(to c: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: c))
        item.name = "Your car"
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

@MainActor
final class OneShotLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var denied = false
    private let m = CLLocationManager()
    override init() { super.init(); m.delegate = self }
    func requestOnce() {
        m.requestWhenInUseAuthorization()
        m.desiredAccuracy = kCLLocationAccuracyBest
        m.requestLocation()
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        Task { @MainActor in self.coordinate = c; HandyHaptics.success() }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in self.denied = (s == .denied || s == .restricted) }
    }
}

/// Tiny persistence for the saved spot.
enum ParkStore {
    nonisolated(unsafe) private static let d = UserDefaults.standard
    static func save(_ c: CLLocationCoordinate2D) { d.set(c.latitude, forKey: "park.lat"); d.set(c.longitude, forKey: "park.lng"); d.set(Date(), forKey: "park.at") }
    static func load() -> CLLocationCoordinate2D? {
        guard d.object(forKey: "park.lat") != nil else { return nil }
        return CLLocationCoordinate2D(latitude: d.double(forKey: "park.lat"), longitude: d.double(forKey: "park.lng"))
    }
    static func date() -> Date? { d.object(forKey: "park.at") as? Date }
    static func note() -> String { d.string(forKey: "park.note") ?? "" }
    static func setNote(_ s: String) { d.set(s, forKey: "park.note") }
}
