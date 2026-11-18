import Foundation
import CoreLocation
import WeatherKit
import SwiftUI

/// "What to wear" for the day's plan, from Apple Weather. The advice is pure and unit-tested; the fetch
/// uses WeatherKit on the phone's location. Shows Apple's required attribution (mark + legal link).
enum WeatherWear {
    struct Snapshot: Equatable {
        var tempC: Double
        var feelsC: Double
        var highC: Double
        var lowC: Double
        var rainChance: Double      // 0…1 for today
        var windKph: Double
        var uv: Int
        var condition: String
        var symbol: String
    }

    /// Short, practical lines — the clothes first, then the one thing to carry. Unwell → warmer.
    static func advice(_ s: Snapshot, unwell: Bool = false, goingOut: Bool = true) -> [String] {
        var out: [String] = []
        let feel = s.feelsC - (unwell ? 3 : 0)       // you feel the cold more when you're ill
        switch feel {
        case ..<0: out.append("Freezing — heavy coat, hat, gloves and a scarf.")
        case 0..<8: out.append("Cold — a warm coat and layers.")
        case 8..<14: out.append("Cool — a jacket or a warm sweater.")
        case 14..<20: out.append("Mild — a light jacket or long sleeves.")
        case 20..<27: out.append("Warm — T-shirt weather.")
        default: out.append("Hot — light, loose clothes, and drink plenty of water.")
        }
        if s.rainChance >= 0.5 { out.append("Rain likely (\(Int((s.rainChance * 100).rounded()))%) — take an umbrella or a rain jacket.") }
        else if s.rainChance >= 0.25 { out.append("Chance of rain (\(Int((s.rainChance * 100).rounded()))%) — a compact umbrella just in case.") }
        if s.windKph >= 35 { out.append("Windy — something windproof; skip the umbrella if it's gusty.") }
        if s.uv >= 6, goingOut { out.append("Strong sun — sunglasses and sunscreen.") }
        if s.highC - s.lowC >= 10 { out.append("Big swing today — wear layers you can take off.") }
        if unwell { out.append("Not feeling well — dress a layer warmer than usual.") }
        return out
    }

    /// Best time to go out, from the hourly rain chance: the first dry hour in the next 8.
    static func bestTripHour(_ hourlyRain: [(Date, Double)], now: Date = Date()) -> Date? {
        hourlyRain.filter { $0.0 >= now.addingTimeInterval(-1800) }.prefix(8).first { $0.1 < 0.25 }?.0
    }
}

@MainActor final class WeatherNow: ObservableObject {
    @Published var snapshot: WeatherWear.Snapshot?
    @Published var dryHour: Date?
    @Published var markLight: URL?
    @Published var markDark: URL?
    @Published var legal: URL?
    @Published var failed = false
    @Published var loading = false

    func load(using places: NearbyPlaces) {
        guard snapshot == nil, !loading else { return }
        loading = true
        places.locate { [weak self] loc in
            guard let self else { return }
            guard let loc else { self.loading = false; self.failed = true; return }
            Task { await self.fetch(loc) }
        }
    }

    private func fetch(_ loc: CLLocation) async {
        do {
            let (cur, daily, hourly) = try await WeatherService.shared.weather(for: loc, including: .current, .daily, .hourly)
            let today = daily.forecast.first
            func c(_ m: Measurement<UnitTemperature>) -> Double { m.converted(to: .celsius).value }
            snapshot = WeatherWear.Snapshot(
                tempC: c(cur.temperature), feelsC: c(cur.apparentTemperature),
                highC: today.map { c($0.highTemperature) } ?? c(cur.temperature),
                lowC: today.map { c($0.lowTemperature) } ?? c(cur.temperature),
                rainChance: today?.precipitationChance ?? 0,
                windKph: cur.wind.speed.converted(to: .kilometersPerHour).value,
                uv: cur.uvIndex.value, condition: cur.condition.description, symbol: cur.symbolName)
            dryHour = WeatherWear.bestTripHour(hourly.forecast.map { ($0.date, $0.precipitationChance) })
            if let a = try? await WeatherService.shared.attribution {
                markLight = a.combinedMarkLightURL; markDark = a.combinedMarkDarkURL; legal = a.legalPageURL
            }
        } catch {
            failed = true
        }
        loading = false
    }
}

/// The weather card for Untangle: now + high/low, what to wear, best dry hour for the trip, Apple attribution.
struct WeatherWearCard: View {
    @ObservedObject var weather: WeatherNow
    let unwell: Bool
    let goingOut: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let s = weather.snapshot {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: HandySpacing.s8) {
                    Image(systemName: s.symbol).symbolRenderingMode(.multicolor).font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(temp(s.tempC)) · \(s.condition)").font(HandyFont.bodyStrong)
                        Text("\(L("High")) \(temp(s.highC)) · \(L("Low")) \(temp(s.lowC)) · \(L("Feels like")) \(temp(s.feelsC))")
                            .font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                    }
                }
                Text(L("What to wear")).font(HandyFont.micro.weight(.bold)).foregroundStyle(HandyColor.textSecondary)
                ForEach(WeatherWear.advice(s, unwell: unwell, goingOut: goingOut), id: \.self) { line in
                    Label { Text(L(line)).font(HandyFont.caption) } icon: { Image(systemName: "tshirt").font(.system(size: 11)) }
                }
                if goingOut, s.rainChance >= 0.25, let h = weather.dryHour {
                    Label { Text("\(L("Driest time to head out:")) \(h.formatted(date: .omitted, time: .shortened))").font(HandyFont.caption) }
                        icon: { Image(systemName: "umbrella").font(.system(size: 11)) }
                }
                HStack(spacing: 6) {
                    if let u = scheme == .dark ? weather.markDark : weather.markLight {
                        AsyncImage(url: u) { $0.resizable().scaledToFit() } placeholder: { Text(" Weather").font(HandyFont.micro) }
                            .frame(height: 12)
                    } else { Text(" Weather").font(HandyFont.micro) }
                    if let l = weather.legal { Link(L("Data sources"), destination: l).font(HandyFont.micro) }
                }
            }
            .cardStyle(padding: HandySpacing.s12)
        } else if weather.loading {
            HStack(spacing: 6) { ProgressView(); Text(L("Checking today's weather…")).font(HandyFont.caption) }
        }
    }

    private func temp(_ c: Double) -> String {
        let f = MeasurementFormatter(); f.unitOptions = .temperatureWithoutUnit; f.numberFormatter.maximumFractionDigits = 0
        return f.string(from: Measurement(value: c, unit: UnitTemperature.celsius))   // the formatter shows °F or °C by the phone's region
    }
}
