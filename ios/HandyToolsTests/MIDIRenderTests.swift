import XCTest
import AVFoundation
@testable import HandyTools

/// A .mid plays (File Opener tier 2): its notes are read with the right timing and turned into a real audio file.
final class MIDIRenderTests: XCTestCase {
    /// Format 0, one track, 96 ticks a quarter at 120 bpm: middle C for a quarter, then E (running status) for a quarter,
    /// and a drum hit on channel 10.
    private let mid: Data = {
        var t: [UInt8] = [0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,          // tempo 500,000 µs a quarter
                          0x00, 0xFF, 0x03, 0x05] + Array("Piano".utf8) +
                         [0x00, 0x90, 60, 100,  0x60, 60, 0,                 // C on, then off after 96 ticks (running status, vel 0)
                          0x00, 64, 90,         0x60, 0x80, 64, 0,           // E on, off after 96 ticks
                          0x00, 0x99, 36, 110,  0x10, 0x89, 36, 0,           // a kick on the drum channel
                          0x00, 0xFF, 0x2F, 0x00]
        var d: [UInt8] = Array("MThd".utf8) + [0, 0, 0, 6, 0, 0, 0, 1, 0, 96]
        d += Array("MTrk".utf8) + [0, 0, UInt8(t.count >> 8), UInt8(t.count & 0xFF)] + t
        return Data(d)
    }()

    func testNotesKeepTheirTiming() throws {
        let s = try XCTUnwrap(MIDIRender.parse(mid))
        let melody = s.notes.filter { !$0.drum }
        XCTAssertEqual(melody.map(\.key), [60, 64])
        XCTAssertEqual(melody[0].start, 0, accuracy: 0.001)
        XCTAssertEqual(melody[0].end, 0.5, accuracy: 0.001, "a quarter at 120 bpm is half a second")
        XCTAssertEqual(melody[1].start, 0.5, accuracy: 0.001)
        XCTAssertEqual(melody[1].end, 1.0, accuracy: 0.001)
        XCTAssertEqual(s.notes.filter(\.drum).count, 1)
        XCTAssertEqual(s.trackNames, ["Piano"])
    }

    func testItBecomesAnAudioFileOfTheRightLength() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tune.mid")
        try mid.write(to: url)
        let m4a = try XCTUnwrap(MIDIRender.toM4A(url))
        let f = try AVAudioFile(forReading: m4a)
        let seconds = Double(f.length) / f.fileFormat.sampleRate
        XCTAssertEqual(seconds, 1.4, accuracy: 0.15)
        if case .quickLook = FileReaders.read(url) {} else { XCTFail("a .mid should open to play") }
    }

    func testSilenceIsNotAResult() {
        XCTAssertNil(MIDIRender.parse(Data("MThd".utf8)))
    }
}
