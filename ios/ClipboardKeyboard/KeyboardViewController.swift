import UIKit

/// The Clips keyboard. Shows the stack; tap a row to insert it into whatever field is focused.
/// "+" reads the current pasteboard into the stack (needs Full Access, which iOS asks for once).
final class KeyboardViewController: UIInputViewController, UITableViewDataSource, UITableViewDelegate {

    private var clips: [Clip] = []
    private let table = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground

        let bar = UIStackView()
        bar.axis = .horizontal; bar.distribution = .fillEqually; bar.spacing = 6
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.addArrangedSubview(key("🌐", #selector(handleInputModeList(from:with:)), isGlobe: true))
        bar.addArrangedSubview(key("＋ Grab clipboard", #selector(grab)))
        bar.addArrangedSubview(key("Paste all", #selector(pasteAll)))
        bar.addArrangedSubview(key("⌫", #selector(backspace)))
        view.addSubview(bar)

        table.dataSource = self; table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .clear
        view.addSubview(table)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            bar.heightAnchor.constraint(equalToConstant: 40),
            table.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 4),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.heightAnchor.constraint(equalToConstant: 260),
        ])
    }

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); reload() }

    private func key(_ title: String, _ sel: Selector, isGlobe: Bool = false) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        b.backgroundColor = .systemBackground; b.layer.cornerRadius = 8
        if isGlobe { b.addTarget(self, action: sel, for: .allTouchEvents) } else { b.addTarget(self, action: sel, for: .touchUpInside) }
        return b
    }

    private func reload() { clips = ClipStore.all(); table.reloadData() }

    @objc private func grab() {
        guard hasFullAccess else { insertHint("Enable Full Access in Settings to grab the clipboard"); return }
        if let s = UIPasteboard.general.string { ClipStore.add(s); reload() }
    }
    @objc private func pasteAll() { textDocumentProxy.insertText(clips.map(\.text).joined(separator: "\n")) }
    @objc private func backspace() { textDocumentProxy.deleteBackward() }
    private func insertHint(_ s: String) { let a = UIAlertController(title: nil, message: s, preferredStyle: .alert); a.addAction(.init(title: "OK", style: .default)); present(a, animated: true) }

    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { max(clips.count, 1) }
    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = t.dequeueReusableCell(withIdentifier: "c", for: ip)
        c.backgroundColor = .clear
        var cfg = c.defaultContentConfiguration()
        if clips.isEmpty { cfg.text = "Nothing saved yet. Copy text, then tap ＋ Grab clipboard."; cfg.textProperties.color = .secondaryLabel }
        else { cfg.text = (clips[ip.row].pinned ? "📌 " : "") + clips[ip.row].text; cfg.textProperties.numberOfLines = 2 }
        c.contentConfiguration = cfg
        return c
    }
    func tableView(_ t: UITableView, didSelectRowAt ip: IndexPath) {
        t.deselectRow(at: ip, animated: true)
        guard !clips.isEmpty else { return }
        textDocumentProxy.insertText(clips[ip.row].text)
    }
}
