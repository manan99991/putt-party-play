import Foundation
import Network

/// "Send a file" without a cable or a cloud: a one-file HTTP server on the local Wi-Fi. The other
/// device scans the QR (or types the address), gets a tiny landing page, taps the file, and the
/// bytes stream straight from this phone. State is driven by what was actually written to the socket.
final class LocalShareServer: ObservableObject {

    enum State: Equatable {
        case idle, waiting, connected, sending(Double), delivered, failed(String)
        var label: String {
            switch self {
            case .idle: return ""
            case .waiting: return "Waiting for the other device…"
            case .connected: return "Connected — the other device is looking at the page"
            case .sending(let p): return "Sending \(Int((p * 100).rounded()))%"
            case .delivered: return "✓ Delivered"
            case .failed(let m): return m
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var port: UInt16 = 0
    @Published private(set) var ip: String?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "tenzy.localshare")
    private var fileURL: URL?
    private var fileName = ""
    private var fileSize = 0
    private var connections: [NWConnection] = []

    var url: String? { guard let ip, port > 0 else { return nil }; return "http://\(ip):\(port)/" }

    // MARK: lifecycle

    func start(file: URL) {
        stop()
        fileURL = file; fileName = file.lastPathComponent
        fileSize = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
        ip = LocalNet.wifiIPv4()
        guard ip != nil else { setState(.failed("Not on Wi-Fi")); return }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        var l: NWListener?
        if let p = NWEndpoint.Port(rawValue: 8080) { l = try? NWListener(using: params, on: p) }
        if l == nil { l = try? NWListener(using: params) }
        guard let listener = l else { setState(.failed("Couldn't open a port")); return }
        self.listener = listener
        listener.stateUpdateHandler = { [weak self] st in
            guard let self else { return }
            switch st {
            case .ready:
                let p = listener.port?.rawValue ?? 0
                DispatchQueue.main.async { self.port = p; self.state = .waiting }
            case .failed(let e): self.setState(.failed("Server stopped: \(e.localizedDescription)"))
            case .cancelled: break
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] c in self?.accept(c) }
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel(); listener = nil
        connections.forEach { $0.cancel() }; connections = []
        if state != .idle { setState(.idle) }
        port = 0
    }

    deinit { listener?.cancel(); connections.forEach { $0.cancel() } }

    private func setState(_ s: State) { DispatchQueue.main.async { self.state = s } }

    // MARK: HTTP

    private func accept(_ c: NWConnection) {
        connections.append(c)
        c.stateUpdateHandler = { [weak self] st in
            if case .ready = st, let self, case .waiting = self.state { self.setState(.connected) }
        }
        c.start(queue: queue)
        readRequest(c, buffer: Data())
    }

    private func readRequest(_ c: NWConnection, buffer: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, done, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if let r = buf.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: buf[buf.startIndex..<r.lowerBound], as: UTF8.self)
                self.respond(c, requestLine: head.components(separatedBy: "\r\n").first ?? "")
            } else if done || error != nil || buf.count > 65_536 {
                c.cancel()
            } else {
                self.readRequest(c, buffer: buf)
            }
        }
    }

    private func respond(_ c: NWConnection, requestLine: String) {
        let parts = requestLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? "GET"
        let rawPath = parts.count > 1 ? String(parts[1]) : "/"
        let path = rawPath.components(separatedBy: "?").first?.removingPercentEncoding ?? "/"
        if path == "/" || path.isEmpty {
            let html = landingPage()
            send(c, status: "200 OK", headers: ["Content-Type": "text/html; charset=utf-8", "Content-Length": "\(html.utf8.count)", "Connection": "close"], body: method == "HEAD" ? Data() : Data(html.utf8)) { c.cancel() }
        } else if path == "/" + fileName || path == "/download", let fileURL, let fh = try? FileHandle(forReadingFrom: fileURL) {
            let headers = ["Content-Type": "application/octet-stream", "Content-Length": "\(fileSize)",
                           "Content-Disposition": "attachment; filename=\"\(fileName.replacingOccurrences(of: "\"", with: ""))\"", "Connection": "close"]
            if method == "HEAD" { send(c, status: "200 OK", headers: headers, body: Data()) { c.cancel() }; return }
            setState(.sending(0))
            send(c, status: "200 OK", headers: headers, body: Data()) { [weak self] in self?.stream(fh, to: c, sent: 0) }
        } else {
            let body = Data("Not found".utf8)
            send(c, status: "404 Not Found", headers: ["Content-Type": "text/plain", "Content-Length": "\(body.count)", "Connection": "close"], body: body) { c.cancel() }
        }
    }

    private func send(_ c: NWConnection, status: String, headers: [String: String], body: Data, then: @escaping () -> Void) {
        var head = "HTTP/1.1 \(status)\r\n"
        for (k, v) in headers { head += "\(k): \(v)\r\n" }
        head += "\r\n"
        c.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in then() })
    }

    private func stream(_ fh: FileHandle, to c: NWConnection, sent: Int) {
        let chunk = fh.readData(ofLength: 256 * 1024)
        if chunk.isEmpty {
            try? fh.close()
            setState(.delivered)
            c.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in c.cancel() })
            return
        }
        c.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if error != nil { try? fh.close(); self.setState(.failed("The other device stopped the download")); c.cancel(); return }
            let total = sent + chunk.count
            self.setState(.sending(self.fileSize > 0 ? min(1, Double(total) / Double(self.fileSize)) : 1))
            self.stream(fh, to: c, sent: total)
        })
    }

    private func landingPage() -> String {
        let name = fileName.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
        let href = "/" + (fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "download")
        let size = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
        return """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tenzy — file ready</title>
        <style>body{font-family:-apple-system,system-ui,sans-serif;background:#0f1115;color:#eee;margin:0;padding:32px 20px;text-align:center}
        .card{max-width:420px;margin:0 auto;background:#1b1e26;border-radius:18px;padding:28px 20px}h1{font-size:20px;margin:0 0 6px}p{color:#9aa;margin:0 0 22px}
        a{display:block;background:#4f7cff;color:#fff;text-decoration:none;padding:16px;border-radius:14px;font-weight:600;font-size:17px}small{display:block;margin-top:18px;color:#778}</style></head>
        <body><div class="card"><h1>\(name)</h1><p>\(size)</p><a href="\(href)" download>Download</a><small>Sent from Tenzy over your Wi-Fi. Nothing was uploaded.</small></div></body></html>
        """
    }
}

/// Local-network details iOS will give an app without special entitlements.
enum LocalNet {
    /// IPv4 of the Wi-Fi interface (en0), else the personal-hotspot bridge, else any non-loopback en*.
    static func wifiIPv4() -> String? {
        var found: [String: String] = [:]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var p: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = p {
            let ifa = cur.pointee
            if let sa = ifa.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET), (Int32(ifa.ifa_flags) & IFF_UP) != 0 {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let name = String(cString: ifa.ifa_name)
                    let addr = String(cString: host)
                    if !addr.hasPrefix("127.") && !addr.hasPrefix("169.254.") { found[name] = addr }
                }
            }
            p = ifa.ifa_next
        }
        if let a = found["en0"] { return a }
        if let a = found["bridge100"] { return a }
        return found.first { $0.key.hasPrefix("en") }?.value
    }
}
