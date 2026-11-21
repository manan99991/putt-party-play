import SwiftUI
import WebKit
import QuickLook

/// Shows whatever FileReaders made of a file, in the way that kind of thing is meant to be gone through: a book
/// you page through by chapter with your place kept, a comic page by page, an email with its attachments, a
/// table you can scroll both ways and open in Numbers or Excel, an archive you can open things inside, a database
/// table by table. Anything inside (an attachment, a file in a ZIP) opens the same way, one level deeper.
struct FileReaderView: View {
    let url: URL
    @State private var reading: FileReaders.Reading?
    @State private var inner: URL?

    var body: some View {
        Group {
            if let reading { content(reading) } else { ToolProgressBar(label: L("Opening…"), showsTime: false) }
        }
        .task(id: url) {
            let u = url
            reading = await Task.detached(priority: .userInitiated) { FileReaders.read(u) }.value
        }
        .sheet(item: Binding(get: { inner.map(IdentURL.init) }, set: { inner = $0?.url })) { i in
            NavigationStack {
                ScrollView { FileReaderView(url: i.url).padding(HandySpacing.gutter) }
                    .navigationTitle(i.url.lastPathComponent).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Done")) { inner = nil } }
                               ToolbarItem(placement: .primaryAction) { ShareLink(item: i.url) { Image(systemName: "square.and.arrow.up") } } }
            }
        }
    }

    struct IdentURL: Identifiable { let url: URL; var id: String { url.path } }

    @ViewBuilder private func content(_ r: FileReaders.Reading) -> some View {
        switch r {
        case .quickLook(let u):
            QuickLookPreview(url: u).frame(height: 520).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        case .table(let rows, let note):
            TableReader(rows: rows, note: note, name: url.deletingPathExtension().lastPathComponent)
        case .text(let t, let title):
            TextReader(text: t, title: title)
        case .book(let b):
            BookReader(book: b, key: url.lastPathComponent)
        case .comic(let pages):
            ComicReader(pages: pages, key: url.lastPathComponent)
        case .email(let e):
            EmailReader(email: e) { name, data in inner = temp(name, data) }
        case .database(let tables):
            DatabaseReader(tables: tables, name: url.deletingPathExtension().lastPathComponent)
        case .archive(let entries, let kind):
            ArchiveReader(entries: entries, kind: kind) { e in if let d = e.data() { inner = temp((e.name as NSString).lastPathComponent, d) } }
        case .webVideo(let u):
            WebVideo(url: u).frame(height: 420).clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
        case .image(let img):
            ZoomableImage(image: img)
        case .info(let kind, let detail, let hex):
            VStack(alignment: .leading, spacing: HandySpacing.s8) {
                Label(kind, systemImage: "doc.questionmark").font(HandyFont.bodyStrong)
                Text(detail).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                Text(L("First bytes of the file")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                Text(hex).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                Text(L("You can still share it to an app made for this kind of file.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(padding: HandySpacing.s12)
        }
    }

    private func temp(_ name: String, _ data: Data) -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("inner-\(UUID().uuidString.prefix(6))", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let u = dir.appendingPathComponent(name.isEmpty ? "file" : name)
        return (try? data.write(to: u)) != nil ? u : nil
    }
}

// MARK: - tables

private struct TableReader: View {
    let rows: [[String]]
    let note: String?
    let name: String
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text("\(max(0, rows.count - 1)) \(L("rows")) · \(rows.map(\.count).max() ?? 0) \(L("columns"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            if let note { Text(L(note)).font(HandyFont.micro).foregroundStyle(HandyColor.amber) }
            DataGrid(rows: rows).frame(height: 460)
            if let d = XLSXWriter.workbook(rows: rows, sheetName: "Sheet1") {
                let u = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).xlsx")
                if (try? d.write(to: u)) != nil {
                    ShareLink(item: u) { Label(L("Open in Numbers or Excel"), systemImage: "tablecells").frame(maxWidth: .infinity) }.primaryButton()
                }
            }
        }
    }
}

/// A scroll-both-ways grid, first row as the header.
struct DataGrid: View {
    let rows: [[String]]
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.prefix(2000).enumerated()), id: \.offset) { i, r in
                    HStack(spacing: 0) {
                        ForEach(Array(r.enumerated()), id: \.offset) { _, c in
                            Text(c).font(i == 0 ? HandyFont.caption.weight(.semibold) : HandyFont.caption).lineLimit(2)
                                .frame(width: 130, alignment: .leading).padding(.horizontal, 8).padding(.vertical, 6)
                                .overlay(Rectangle().stroke(HandyColor.border, lineWidth: 0.5))
                        }
                    }
                    .background(i == 0 ? HandyColor.surface : Color.clear)
                }
            }.textSelection(.enabled)
        }
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(HandyColor.border, lineWidth: 1))
    }
}

// MARK: - text

private struct TextReader: View {
    let text: String
    let title: String
    @State private var find = ""
    private var hits: Int { find.count < 2 ? 0 : text.lowercased().components(separatedBy: find.lowercased()).count - 1 }
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            HStack {
                Text("\(title) · \(text.split(separator: "\n", omittingEmptySubsequences: false).count) \(L("lines"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                Spacer()
                CopyButton(text: text)
            }
            TextField(L("Find in this file"), text: $find).textFieldStyle(.handy).autocorrectionDisabled().textInputAutocapitalization(.never)
            if find.count >= 2 { Text("\(hits) \(L(hits == 1 ? "match" : "matches"))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) }
            ScrollView([.vertical, .horizontal]) {
                Text(highlighted).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            .frame(height: 460).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 10))
        }
    }
    private var highlighted: AttributedString {
        var a = AttributedString(text)
        guard find.count >= 2 else { return a }
        var range = a.startIndex..<a.endIndex
        while let r = a[range].range(of: find, options: .caseInsensitive) { a[r].backgroundColor = .yellow.opacity(0.5); range = r.upperBound..<a.endIndex }
        return a
    }
}

// MARK: - books

private struct BookReader: View {
    let book: FileReaders.Book
    let key: String
    @State private var index = 0
    @AppStorage("tenzy.reader.size") private var size = 100.0
    @AppStorage("tenzy.reader.paper") private var paper = 0          // 0 light, 1 sepia, 2 dark
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title).font(HandyFont.cardTitle).lineLimit(2)
                if !book.author.isEmpty { Text(book.author).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary) }
            }
            HStack {
                Menu {
                    ForEach(book.chapters.indices, id: \.self) { i in Button(book.chapters[i].title) { index = i } }
                } label: { Label("\(index + 1) / \(book.chapters.count)", systemImage: "list.bullet").font(HandyFont.caption) }
                Spacer()
                Button { size = max(70, size - 10) } label: { Image(systemName: "textformat.size.smaller") }.accessibilityLabel(L("Smaller text"))
                Button { size = min(200, size + 10) } label: { Image(systemName: "textformat.size.larger") }.accessibilityLabel(L("Bigger text"))
                Button { paper = (paper + 1) % 3 } label: { Image(systemName: paper == 2 ? "moon.fill" : paper == 1 ? "book.closed.fill" : "sun.max") }.accessibilityLabel(L("Page colour"))
            }
            HTMLPage(html: styled(book.chapters[min(index, book.chapters.count - 1)].html), base: book.baseDir)
                .frame(height: 520).clipShape(RoundedRectangle(cornerRadius: 10))
            HStack {
                Button { index = max(0, index - 1) } label: { Label(L("Previous"), systemImage: "chevron.left") }.disabled(index == 0)
                Spacer()
                Button { index = min(book.chapters.count - 1, index + 1) } label: { Label(L("Next"), systemImage: "chevron.right") }.disabled(index >= book.chapters.count - 1)
            }.font(HandyFont.body)
        }
        .onAppear { index = min(UserDefaults.standard.integer(forKey: "tenzy.reader.at.\(key)"), max(0, book.chapters.count - 1)) }
        .onChange(of: index) { _, i in UserDefaults.standard.set(i, forKey: "tenzy.reader.at.\(key)") }
    }
    private func styled(_ html: String) -> String {
        let (bg, fg) = paper == 2 ? ("#111", "#ddd") : paper == 1 ? ("#f4ecd8", "#3b2f1e") : ("#fff", "#111")
        let css = "<style>html,body{background:\(bg)!important;color:\(fg)!important;font-family:-apple-system,Georgia,serif;font-size:\(Int(size))%;line-height:1.55;margin:16px;} img{max-width:100%;height:auto} a{color:#3b6fe0}</style><meta name='viewport' content='width=device-width,initial-scale=1'>"
        if let r = html.range(of: "</head>", options: .caseInsensitive) { var h = html; h.insert(contentsOf: css, at: r.lowerBound); return h }
        return css + html
    }
}

/// A web view for book chapters and email bodies — scripts off, links open outside.
struct HTMLPage: UIViewRepresentable {
    let html: String
    var base: URL? = nil
    func makeUIView(context: Context) -> WKWebView {
        let c = WKWebViewConfiguration()
        c.defaultWebpagePreferences.allowsContentJavaScript = false
        let v = WKWebView(frame: .zero, configuration: c)
        v.navigationDelegate = context.coordinator
        return v
    }
    func updateUIView(_ v: WKWebView, context: Context) {
        guard context.coordinator.shown != html else { return }
        context.coordinator.shown = html
        if let base {
            let f = base.appendingPathComponent("tenzy-page.html")
            try? html.write(to: f, atomically: true, encoding: .utf8)
            v.loadFileURL(f, allowingReadAccessTo: base)
        } else {
            v.loadHTMLString(html, baseURL: nil)
        }
    }
    func makeCoordinator() -> Coord { Coord() }
    final class Coord: NSObject, WKNavigationDelegate {
        var shown = ""
        func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if a.navigationType == .linkActivated, let u = a.request.url, u.scheme?.hasPrefix("http") == true { UIApplication.shared.open(u); decisionHandler(.cancel) } else { decisionHandler(.allow) }
        }
    }
}

/// WebM picture and sound (VP8, VP9, AV1, Opus, Vorbis) played by the system web engine, which decodes them.
struct WebVideo: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let c = WKWebViewConfiguration()
        c.allowsInlineMediaPlayback = true
        c.defaultWebpagePreferences.allowsContentJavaScript = false
        let v = WKWebView(frame: .zero, configuration: c)
        v.isOpaque = false
        v.backgroundColor = .black
        v.scrollView.isScrollEnabled = false
        let dir = url.deletingLastPathComponent(), page = dir.appendingPathComponent("tenzy-player.html")
        let src = url.lastPathComponent.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: ".-_"))) ?? "video.webm"
        let html = "<!doctype html><meta name=viewport content='width=device-width,initial-scale=1'>"
            + "<style>html,body{margin:0;height:100%;background:#000}video{width:100%;height:100%}</style>"
            + "<video src='\(src)' controls playsinline preload=metadata></video>"
        try? html.write(to: page, atomically: true, encoding: .utf8)
        v.loadFileURL(page, allowingReadAccessTo: dir)
        return v
    }
    func updateUIView(_ v: WKWebView, context: Context) {}
}

// MARK: - comics

private struct ComicReader: View {
    let pages: [Data]
    let key: String
    @State private var page = 0
    var body: some View {
        VStack(spacing: HandySpacing.s8) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    ZoomableImage(image: UIImage(data: pages[i]) ?? UIImage()).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)).frame(height: 560)
            Text("\(L("Page")) \(page + 1) / \(pages.count)").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
        }
        .onAppear { page = min(UserDefaults.standard.integer(forKey: "tenzy.comic.at.\(key)"), max(0, pages.count - 1)) }
        .onChange(of: page) { _, p in UserDefaults.standard.set(p, forKey: "tenzy.comic.at.\(key)") }
    }
}

struct ZoomableImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    var body: some View {
        Image(uiImage: image).resizable().scaledToFit()
            .scaleEffect(scale * pinch)
            .gesture(MagnifyGesture().updating($pinch) { v, s, _ in s = v.magnification }.onEnded { v in scale = min(5, max(1, scale * v.magnification)) })
            .onTapGesture(count: 2) { withAnimation { scale = scale > 1 ? 1 : 2.5 } }
            .frame(maxWidth: .infinity).frame(minHeight: 300)
    }
}

// MARK: - email

private struct EmailReader: View {
    let email: FileReaders.Email
    let openAttachment: (String, Data) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(email.subject.isEmpty ? L("(no subject)") : email.subject).font(HandyFont.cardTitle)
                row(L("From"), email.from); row(L("To"), email.to)
                if !email.cc.isEmpty { row("Cc", email.cc) }
                if !email.date.isEmpty { row(L("Date"), email.date) }
            }.cardStyle(padding: HandySpacing.s12)
            if let html = email.html { HTMLPage(html: html).frame(height: 460).clipShape(RoundedRectangle(cornerRadius: 10)) }
            else { ScrollView { Text(email.text).font(HandyFont.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 460) }
            if !email.attachments.isEmpty {
                Text("\(email.attachments.count) \(L(email.attachments.count == 1 ? "attachment" : "attachments"))").font(HandyFont.bodyStrong)
                ForEach(email.attachments.indices, id: \.self) { i in
                    let a = email.attachments[i]
                    Button { openAttachment(a.name, a.data) } label: {
                        HStack { Image(systemName: "paperclip"); Text(a.name).lineLimit(1); Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(a.data.count), countStyle: .file)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                            Image(systemName: "chevron.right").foregroundStyle(HandyColor.textSecondary) }
                    }.buttonStyle(.plain).cardStyle(padding: HandySpacing.s12)
                }
            }
        }
    }
    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) { Text(k).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).frame(width: 44, alignment: .leading); Text(v).font(HandyFont.caption).textSelection(.enabled) }
    }
}

// MARK: - databases & archives

private struct DatabaseReader: View {
    let tables: [(table: String, rows: [[String]])]
    let name: String
    @State private var pick = 0
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Picker(L("Table"), selection: $pick) { ForEach(tables.indices, id: \.self) { Text(tables[$0].table).tag($0) } }.pickerStyle(.menu)
            Text("\(tables.count) \(L("tables")) · \(L("showing up to 200 rows"))").font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
            DataGrid(rows: tables[pick].rows).frame(height: 460)
        }
    }
}

private struct ArchiveReader: View {
    let entries: [FileReaders.ArchiveEntry]
    let kind: String
    let open: (FileReaders.ArchiveEntry) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Text("\(kind) · \(entries.count) \(L(entries.count == 1 ? "file" : "files")) — \(L("tap one to open it"))").font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            LazyVStack(spacing: 6) {
                ForEach(entries.prefix(500)) { e in
                    Button { open(e) } label: {
                        HStack { Image(systemName: icon(e.name)).foregroundStyle(HandyColor.accent).frame(width: 22)
                            Text(e.name).font(HandyFont.caption).lineLimit(2).multilineTextAlignment(.leading); Spacer()
                            if e.size > 0 { Text(ByteCountFormatter.string(fromByteCount: Int64(e.size), countStyle: .file)).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary) } }
                        .padding(10).background(HandyColor.surface, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private func icon(_ n: String) -> String {
        switch FileKind.of(ext: (n as NSString).pathExtension) {
        case .image: return "photo"; case .video: return "film"; case .audio: return "waveform"; case .document: return "doc.richtext"
        case .archive: return "archivebox"; case .code, .text: return "doc.plaintext"; default: return "doc"
        }
    }
}
