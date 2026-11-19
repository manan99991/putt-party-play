import XCTest
import simd
@testable import HandyTools

/// Measure: walls from two corners, areas on the real surface (walls too, not just floors), corners tapped
/// out of order put back in order, corners off the surface flagged, and Will it fit?.
final class MeasureTests: XCTestCase {

    func testWallFromTwoOppositeCorners() {
        // A wall along x: bottom-left at the floor, top-right 3.2 m along and 2.4 m up.
        let r = MeasureMath.rectangle([0, 0, -2], [3.2, 2.4, -2])
        XCTAssertEqual(r.width, 3.2, accuracy: 0.001)
        XCTAssertEqual(r.height, 2.4, accuracy: 0.001)
        XCTAssertEqual(r.area, 7.68, accuracy: 0.001)
        // A wall at an angle on the floor plan: the width is along the floor.
        let d = MeasureMath.rectangle([0, 0, 0], [3, 2, 4])
        XCTAssertEqual(d.width, 5, accuracy: 0.001)
        XCTAssertEqual(MeasureMath.rectangleCorners([0, 0, 0], [3, 2, 4]).count, 4)
    }

    func testWallAreaIsOnTheWallNotTheFloor() {
        // The bug Manan hit: four corners of a wall (vertical) must give the wall's area, not ~0.
        let wall: [SIMD3<Float>] = [[0, 0, -2], [3, 0, -2], [3, 2.5, -2], [0, 2.5, -2]]
        let s = MeasureMath.surface(wall)
        XCTAssertEqual(s.area, 7.5, accuracy: 0.01)
        XCTAssertTrue(s.flat)
        XCTAssertFalse(s.reordered)
    }

    func testCornersOutOfOrderArePutBackInOrder() {
        // A 4 × 3 m floor tapped as a bow-tie (corner 3 before corner 2).
        let tapped: [SIMD3<Float>] = [[0, 0, 0], [4, 0, 3], [4, 0, 0], [0, 0, 3]]
        let s = MeasureMath.surface(tapped)
        XCTAssertTrue(s.reordered)
        XCTAssertEqual(s.area, 12, accuracy: 0.01)
        XCTAssertEqual(s.perimeter, 14, accuracy: 0.01)
    }

    func testCornerOffTheSurfaceIsFlagged() {
        // Three floor corners and one tapped on a shelf 60 cm up.
        let s = MeasureMath.surface([[0, 0, 0], [4, 0, 0], [4, 0.6, 3], [0, 0, 3]])
        XCTAssertFalse(s.flat)
        // A slightly uneven floor (2 cm) is still one surface.
        XCTAssertTrue(MeasureMath.surface([[0, 0, 0], [4, 0.02, 0], [4, 0, 3], [0, 0.01, 3]]).flat)
    }

    func testWillItFit() {
        XCTAssertEqual(MeasureARView.worstGap(space: 2.0, spaceH: nil, w: 1.9, h: nil), 0.1, accuracy: 0.0001)
        XCTAssertEqual(MeasureARView.worstGap(space: 2.0, spaceH: 1.0, w: 1.5, h: 1.2), -0.2, accuracy: 0.0001, "too tall wins")
        XCTAssertLessThan(MeasureARView.worstGap(space: 1.8, spaceH: nil, w: 2.0, h: nil), 0)
    }

    // MARK: Instruments, by job

    func testLevelReadsZeroWhenStraightEitherWay() {
        XCTAssertEqual(SensorMath.offSquare(90.4).off, 0.4, accuracy: 0.001)
        XCTAssertTrue(SensorMath.offSquare(-89.8).level)
        XCTAssertEqual(SensorMath.offSquare(2.3).off, 2.3, accuracy: 0.001)
        XCTAssertFalse(SensorMath.offSquare(2.3).level, "standing up is plumb, not level")
        let s = SensorMath.slope(degrees: 1)
        XCTAssertEqual(s.mm, 8.7, accuracy: 0.1, "1° is about 9 mm over 50 cm")
        XCTAssertEqual(s.oneIn, 57)
    }

    func testSafeListeningTime() {
        XCTAssertEqual(SensorMath.safeHours(85), 8, accuracy: 0.001)
        XCTAssertEqual(SensorMath.safeHours(94), 1, accuracy: 0.001)
        XCTAssertEqual(SensorMath.safeText(60), "Safe for as long as you like")
        XCTAssertTrue(SensorMath.safeText(100).contains("15 minutes"))
    }

    func testPlantLightAndDirections() {
        XCTAssertEqual(SensorMath.lightVerdict(1500).title, "Bright, indirect light")
        XCTAssertTrue(SensorMath.lightVerdict(100).plants.contains("Snake plant"))
        XCTAssertEqual(SensorMath.sunText(90), "Faces east — morning sun")
        XCTAssertEqual(SensorMath.sunText(0, southernHemisphere: true), "Faces the sun at midday — bright most of the day")
        // Qibla from London is about 119°, from New York about 58°.
        XCTAssertEqual(SensorMath.qibla(lat: 51.5074, lon: -0.1278), 119, accuracy: 1.5)
        XCTAssertEqual(SensorMath.qibla(lat: 40.7128, lon: -74.006), 58.5, accuracy: 1.5)
        XCTAssertEqual(SensorMath.turn(from: 350, to: 10), 20, accuracy: 0.001)
        XCTAssertEqual(SensorMath.turn(from: 10, to: 350), -20, accuracy: 0.001)
    }
}
