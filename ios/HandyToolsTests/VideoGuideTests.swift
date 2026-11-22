import XCTest
@testable import HandyTools

final class VideoGuideTests: XCTestCase {
    private var options: [Guide.Option] {
        Guide.sort(kind: .video, count: 1, tools: ToolHandoff.tools(for: .video),
                   chains: ChainTemplates.all.filter { $0.problem(starting: .video) == nil }, voices: false).flatMap(\.options)
    }

    /// Every way Tenzy has to work on a video lands in one plain job, once, and the whole choice fits one screen.
    func testEveryWayHasOneJob() {
        let jobs = Guide.videoJobs(options)
        let ids = jobs.flatMap(\.options).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "a way shows twice: \(ids)")
        XCTAssertEqual(Set(ids), Set(options.map(\.id)), "a way went missing")
        XCTAssertLessThanOrEqual(jobs.count, 10)
        XCTAssertNil(jobs.first { $0.goal == "more" }, "these fit no job: \(jobs.first { $0.goal == "more" }?.options.map(\.id) ?? [])")
        func job(_ id: String) -> String? { jobs.first { $0.options.contains { $0.id == id } }?.goal }
        XCTAssertEqual(job("tool-video"), "cut")
        XCTAssertEqual(job("chain-video-boomerang"), "fun")
        XCTAssertEqual(job("chain-video-chat"), "send")
        XCTAssertEqual(job("chain-video-email"), "send")
        XCTAssertEqual(job("chain-video-still"), "photo")
        XCTAssertEqual(job("chain-video-slowmo"), "speed")
        XCTAssertEqual(job("chain-video-words"), "words")
        XCTAssertEqual(job("chain-video-quiet"), "sound")
        XCTAssertEqual(job("chain-reel-captions"), "post")
        if ToolHandoff.tools(for: .video).contains("celebrate") { XCTAssertEqual(job("tool-celebrate"), "stunning") }
        // Every tool that can work on a video is offered — none hidden (precheck checks the pickers too).
        for t in ["video", "post", "celebrate", "fitit", "audiomix", "audioconvert", "ringtone", "audioclean", "audioedit", "audiocompress", "meetingnotes"] {
            XCTAssertNotNil(job("tool-" + t), "\(t) can work on a video but isn't offered for one")
        }
        XCTAssertEqual(job("tool-audioclean"), "sound")
        XCTAssertEqual(job("tool-post"), "post")
        XCTAssertEqual(jobs.first { $0.goal == "post" }?.options.first?.id, "tool-post")
        // The way most people mean comes first in its job.
        XCTAssertEqual(jobs.first { $0.goal == "send" }?.options.first?.id, "chain-video-chat")
        XCTAssertEqual(jobs.first { $0.goal == "fun" }?.options.first?.id, "chain-video-boomerang")
        // Jobs keep their order on the screen.
        let order = jobs.map(\.goal)
        XCTAssertEqual(order, Guide.videoGoalIDs.filter(order.contains))
    }

    func testEveryJobReadsPlainly() {
        for id in Guide.videoGoalIDs {
            let g = Guide.videoGoal(id)
            XCTAssertEqual(g.id, id)
            XCTAssertLessThanOrEqual(g.title.count, 20, g.title)
            XCTAssertLessThanOrEqual(g.line.count, 42, g.line)
        }
    }

    func testTheHintFitsTheVideo() {
        XCTAssertEqual(Guide.videoHint(bytes: 90_000_000, seconds: 40, tall: true).goal, "send")
        XCTAssertEqual(Guide.videoHint(bytes: 5_000_000, seconds: 20, tall: false).goal, "post")
        XCTAssertEqual(Guide.videoHint(bytes: 9_000_000, seconds: 300, tall: true).goal, "cut")
        XCTAssertEqual(Guide.videoHint(bytes: 4_000_000, seconds: 12, tall: true).goal, "stunning")
    }
}
