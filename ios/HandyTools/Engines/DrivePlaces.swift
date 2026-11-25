import Foundation
import CoreLocation

/// A short place name for a drive's start and end ("Naperville Public Library", "1420 Ogden Ave"), from Apple's maps on
/// this phone. Empty when it can't be found — the review then says Start and End, and the miles still count.
enum DrivePlaces {
    static func name(lat: Double, lng: Double) async -> String {
        guard let p = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lng)).first else { return "" }
        if let n = p.areasOfInterest?.first { return n }
        if let street = p.thoroughfare { return [p.subThoroughfare, street].compactMap { $0 }.joined(separator: " ") }
        return p.name ?? p.locality ?? ""
    }
}
