import SwiftUI

/// One home for jobs that belong together (Notes from Speech, Audio Editor). Each job is a big, clearly named
/// card — what it's for, what you get — and opens the full tool it always was, so nothing is lost by bringing
/// them together. Back returns here.
struct ToolHub: View {
    let id: String

    struct Job: Identifiable { let id: String; let title: String; let line: String; let gets: String }

    static func jobs(_ hub: String) -> [Job] {
        switch hub {
        case "speechnotes": return [
            Job(id: "voicenotes", title: "Talk and take notes", line: "Speak and watch the words appear. When you stop, you get a summary and the to-dos.", gets: "Notes kept on your phone, searchable and shareable"),
            Job(id: "meetingnotes", title: "Notes from a meeting recording", line: "Pick a recording or a video of a meeting.", gets: "Who said what, a summary, a to-do list and a ready follow-up email"),
        ]
        case "audiostudio": return [
            Job(id: "audioedit", title: "Trim and fade", line: "Keep just the part you want, fade it in and out, cut long silences.", gets: "A clean M4A or WAV you can hear before saving"),
            Job(id: "ringtone", title: "Make a ringtone", line: "Choose up to 30 seconds of any song or video.", gets: "A ringtone file, with the steps to set it"),
            Job(id: "audiomix", title: "Join clips or change speed", line: "Put recordings in order as one file, or play a lecture faster or slower without the chipmunk effect.", gets: "One file, played back before you save"),
            Job(id: "audioclean", title: "Make it clearer", line: "Remove hum and hiss, and bring a quiet recording up to an even volume.", gets: "A clearer recording, before and after to compare"),
        ]
        case "scan": return [Job(id: "pdfsearchable", title: "Make a PDF searchable", line: "Already have a scanned PDF? Read every page so you can search, select and copy its words.", gets: "A searchable PDF, with the text shown before you save")]
        case "fitit": return [Job(id: "audiocompress", title: "Shrink a recording", line: "Make a voice memo or song small enough to email or message.", gets: "A smaller audio file, sizes shown before you choose")]
        case "scrub": return [Job(id: "faceemoji", title: "Cover faces with emoji", line: "Pick an emoji for each face, or leave a face showing.", gets: "A photo that's fun to share and keeps people private")]
        default: return []
        }
    }

    private var tool: Tool? { TOOLS.first { $0.id == id } }

    var body: some View {
        ToolPage(title: tool?.name ?? "", subtitle: L("What do you want to do?")) {
            VStack(alignment: .leading, spacing: HandySpacing.s12) {
                ForEach(Self.jobs(id)) { j in ToolJobCard(job: j, big: true) }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
    }
}

/// One job, as a card that opens its full tool: icon, plain name, what it's for, and what you'll get.
struct ToolJobCard: View {
    let job: ToolHub.Job
    var big = false

    var body: some View {
        NavigationLink(value: job.id) {
            HStack(alignment: .top, spacing: HandySpacing.s12) {
                ToolIconBadge(id: job.id, symbol: TOOLS.first { $0.id == job.id }?.icon ?? "wrench.and.screwdriver.fill", size: big ? 52 : 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L(job.title)).font(big ? HandyFont.cardTitle : HandyFont.bodyStrong).foregroundStyle(HandyColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L(job.line)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(L(job.gets), systemImage: "arrow.turn.down.right").font(HandyFont.micro).foregroundStyle(HandyColor.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(HandyColor.textSecondary).padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            .cardStyle(padding: HandySpacing.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("job-\(job.id)")
    }
}

/// "Also in this tool": the jobs that moved in here, at the foot of the main tool, so they're easy to find.
struct AlsoInThisTool: View {
    let hub: String
    var body: some View {
        let jobs = ToolHub.jobs(hub)
        if !jobs.isEmpty {
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Text(L("Also in this tool")).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                ForEach(jobs) { j in ToolJobCard(job: j) }
            }
        }
    }
}
