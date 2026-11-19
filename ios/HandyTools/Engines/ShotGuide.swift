import UIKit

/// Guided shots for a job: the camera walks you round every angle that matters, stamps each photo with what it
/// shows, when and where, and makes one dated PDF you can send or keep — proof for a rental car, a flat you're
/// moving into, something you're selling, or a parcel that arrived damaged.
enum ShotGuide {
    struct Shot: Equatable { let name: String; let tip: String }
    struct Job: Identifiable, Equatable {
        let id: String; let title: String; let line: String; let icon: String; let shots: [Shot]
    }

    static let jobs: [Job] = [
        Job(id: "rental", title: "Rental car check", line: "Every side, the wheels, mileage and fuel — before you drive off", icon: "car.fill", shots: [
            Shot(name: "Front", tip: "Step back until the whole front fits, number plate readable"),
            Shot(name: "Front left corner", tip: "Stand at an angle so the bumper and wing are in"),
            Shot(name: "Driver side", tip: "Step back until the whole side fits"),
            Shot(name: "Rear left corner", tip: "Bumper and wing at an angle"),
            Shot(name: "Back", tip: "Whole back, number plate readable"),
            Shot(name: "Rear right corner", tip: "Bumper and wing at an angle"),
            Shot(name: "Passenger side", tip: "Step back until the whole side fits"),
            Shot(name: "Front right corner", tip: "Bumper and wing at an angle"),
            Shot(name: "Wheels and tyres", tip: "Close up on any scuffed rim"),
            Shot(name: "Dashboard: mileage and fuel", tip: "Engine on, so the numbers show"),
            Shot(name: "Inside: seats and floor", tip: "Any stains or tears"),
            Shot(name: "Any damage close up", tip: "Fill the frame with the scratch or dent"),
        ]),
        Job(id: "movein", title: "Moving in or out", line: "Room by room, so the deposit comes back", icon: "house.fill", shots: [
            Shot(name: "Front door and hallway", tip: "Walls and floor in one shot"),
            Shot(name: "Living room", tip: "From the doorway, then any marks close up"),
            Shot(name: "Kitchen", tip: "Worktops, cupboards and the hob"),
            Shot(name: "Appliances inside", tip: "Open the oven and fridge"),
            Shot(name: "Bathroom", tip: "Bath or shower, sink, tiles and grout"),
            Shot(name: "Bedroom", tip: "From the doorway"),
            Shot(name: "Windows and blinds", tip: "Any cracks or broken slats"),
            Shot(name: "Carpets and floors", tip: "Stains or burns close up"),
            Shot(name: "Meter readings", tip: "Electricity, gas and water — numbers readable"),
            Shot(name: "Keys handed over", tip: "All keys laid out together"),
        ]),
        Job(id: "sell", title: "Something to sell", line: "Every angle buyers ask for, and any flaws shown honestly", icon: "tag.fill", shots: [
            Shot(name: "Front", tip: "Plain background, good light, fill the frame"),
            Shot(name: "Back", tip: "Same light and background"),
            Shot(name: "Sides", tip: "Both sides if they differ"),
            Shot(name: "Label, model or serial number", tip: "Close enough to read"),
            Shot(name: "Any wear or damage", tip: "Close up — buyers trust honest photos"),
            Shot(name: "Working or in use", tip: "Switched on, or with everything it comes with"),
        ]),
        Job(id: "parcel", title: "Parcel arrived damaged", line: "Proof for the seller or courier", icon: "shippingbox.fill", shots: [
            Shot(name: "Box as delivered", tip: "Before opening, all sides if you can"),
            Shot(name: "Shipping label", tip: "Tracking number readable"),
            Shot(name: "Damage to the box", tip: "Close up on dents, tears or wet patches"),
            Shot(name: "Inside, as opened", tip: "Packing and contents as they arrived"),
            Shot(name: "Damage to the item", tip: "Close up"),
        ]),
    ]

    struct Taken { let shot: Shot; let image: UIImage; let at: Date }

    static func stampText(_ shot: Shot, at: Date, place: String?) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return [shot.name, f.string(from: at), place].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: "  ·  ")
    }

    /// The photo with a strip along the bottom: what it shows, when and where. The photo itself is not cropped.
    static func stamp(_ img: UIImage, text: String) -> UIImage {
        let up = img.normalizedUp()
        let w = up.size.width * up.scale, h = up.size.height * up.scale
        let bar = max(36, h * 0.055)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h + bar), format: fmt).image { ctx in
            up.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
            UIColor(white: 0.08, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: h, width: w, height: bar))
            let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: bar * 0.42, weight: .semibold), .foregroundColor: UIColor.white]
            (text as NSString).draw(in: CGRect(x: bar * 0.4, y: h + bar * 0.24, width: w - bar * 0.8, height: bar * 0.6), withAttributes: a)
        }
    }

    /// One PDF: a cover with the job, date, place and how many photos; then two stamped photos per page.
    static func report(_ job: Job, taken: [Taken], place: String?, started: Date) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)       // US Letter
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .short
        return UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            ctx.beginPage()
            let title: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 28, weight: .bold)]
            let body: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.darkGray]
            (job.title as NSString).draw(at: CGPoint(x: 48, y: 64), withAttributes: title)
            var y: CGFloat = 112
            for line in [f.string(from: started), place ?? "", "\(taken.count) photo\(taken.count == 1 ? "" : "s"), each stamped with the time it was taken",
                         "Made with Tenzy on this phone. Photos are unedited apart from the stamp."] where !line.isEmpty {
                (line as NSString).draw(in: CGRect(x: 48, y: y, width: 516, height: 40), withAttributes: body); y += 26
            }
            y += 12
            for (i, t) in taken.enumerated() {
                let caption: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12, weight: .semibold)]
                (("\(i + 1). " + stampText(t.shot, at: t.at, place: place)) as NSString).draw(in: CGRect(x: 48, y: y, width: 516, height: 18), withAttributes: caption); y += 20
                if y > 700 { ctx.beginPage(); y = 48 }
            }
            for pair in stride(from: 0, to: taken.count, by: 2) {
                ctx.beginPage()
                for (k, t) in taken[pair..<min(pair + 2, taken.count)].enumerated() {
                    let box = CGRect(x: 48, y: 40 + CGFloat(k) * 366, width: 516, height: 346)
                    let img = stamp(t.image, text: stampText(t.shot, at: t.at, place: place))
                    let s = min(box.width / img.size.width, box.height / img.size.height)
                    let r = CGRect(x: box.midX - img.size.width * s / 2, y: box.minY, width: img.size.width * s, height: img.size.height * s)
                    img.draw(in: r)
                }
            }
        }
    }
}
