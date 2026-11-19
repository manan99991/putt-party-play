import Foundation
import UIKit

/// After you measure a room's floor: how much paint, flooring and tile to buy — with the waste and second coat
/// people forget. And a list of saved measurements, so the sofa space you measured at home is with you at the shop.
enum RoomMath {
    struct Needs: Equatable {
        let wallArea: Double        // m², after doors and windows
        let paintLitres: Double     // for all coats
        let paintCans: Int          // 2.5 L cans (metric) / 1 US gallon cans (imperial), rounded up
        let flooring: Double        // m², with 10% for cuts and waste
        let tiles: Int              // tiles with 10% spare
    }

    /// Typical numbers, all editable in the app: a litre of wall paint covers about 10 m² per coat.
    static let coveragePerLitre = 10.0
    static let doorArea = 1.9      // m², a standard interior door
    static let windowArea = 1.5    // m², an average window
    static let waste = 1.10
    static let litresPerGallon = 3.785

    static func needs(floorArea: Double, perimeter: Double, ceiling: Double, doors: Int, windows: Int,
                      coats: Int = 2, tileSide: Double = 0.30, metric: Bool) -> Needs {
        let walls = max(0, perimeter * ceiling - Double(doors) * doorArea - Double(windows) * windowArea)
        let litres = walls * Double(max(1, coats)) / coveragePerLitre
        let can = metric ? 2.5 : litresPerGallon
        let cans = litres <= 0 ? 0 : Int((litres / can).rounded(.up))
        let floor = floorArea * waste
        let tile = max(0.01, tileSide * tileSide)
        let tiles = floorArea <= 0 ? 0 : Int((floorArea * waste / tile).rounded(.up))
        return Needs(wallArea: walls, paintLitres: litres, paintCans: cans, flooring: floor, tiles: tiles)
    }

    static func paintText(_ n: Needs, metric: Bool) -> String {
        metric ? String(format: "%.1f L", n.paintLitres) + " · \(n.paintCans) × 2.5 L"
               : String(format: "%.1f gal", n.paintLitres / litresPerGallon) + " · \(n.paintCans) × 1 gal"
    }

    // MARK: - Saved measurements

    struct Saved: Codable, Identifiable, Equatable {
        var id = UUID()
        var name: String
        var value: String           // the readout as shown, e.g. "Area 14.2 m², perimeter 15.1 m"
        var date = Date()
        var photo: String?          // file name in the app's own folder
    }

    static var folder: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Measurements", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func load() -> [Saved] {
        (try? JSONDecoder().decode([Saved].self, from: Data(contentsOf: folder.appendingPathComponent("list.json")))) ?? []
    }
    static func store(_ list: [Saved]) {
        try? JSONEncoder().encode(list).write(to: folder.appendingPathComponent("list.json"), options: .completeFileProtection)
    }
    @discardableResult
    static func add(name: String, value: String, photo: UIImage?) -> Saved {
        var s = Saved(name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Measurement" : name, value: value)
        if let d = photo?.jpegData(compressionQuality: 0.85) {
            let f = "m-\(s.id.uuidString.prefix(8)).jpg"
            if (try? d.write(to: folder.appendingPathComponent(f), options: .completeFileProtection)) != nil { s.photo = f }
        }
        store([s] + load())
        return s
    }
    static func remove(_ s: Saved) {
        if let p = s.photo { try? FileManager.default.removeItem(at: folder.appendingPathComponent(p)) }
        store(load().filter { $0.id != s.id })
    }
    static func image(_ s: Saved) -> UIImage? { s.photo.flatMap { UIImage(contentsOfFile: folder.appendingPathComponent($0).path) } }
}
