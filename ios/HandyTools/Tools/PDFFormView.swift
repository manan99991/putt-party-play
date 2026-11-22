import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Fill a Form — open a PDF form and Tenzy lists every field in reading order (text, checkboxes,
/// dropdowns) as simple rows to fill. The filled file is reopened and previewed before Save or Share,
/// and stays a working form. A PDF with no fields is pointed to Sign → "Add text" instead of a dead end.
struct PDFFormView: View {
    @State private var sourceData: Data?
    @State private var fileName = "Form"
    @State private var fields: [PDFForm.Field] = []
    @State private var values: [String: String] = [:]
    @State private var preview: UIImage?
    @State private var resultURL: URL?
    @State private var resultPreview: UIImage?
    @State private var filledCount = 0
    @State private var working = false
    @State private var errorText: String?
    @State private var showFiles = false
    @State private var me = MyDetails.load()
    @State private var editingMe = false
    @State private var autoNote: String?

    var body: some View {
        ToolPage(title: "Fill a Form",
                 subtitle: "Type into a PDF form's boxes, tick its checkboxes, pick its options.",
                 working: working) {
            VStack(spacing: HandySpacing.s16) {
                if sourceData == nil { pickCard }
                else if let url = resultURL { result(url) }
                else if fields.isEmpty { noFields }
                else { editor }
            }
            .padding(.horizontal, HandySpacing.gutter)
            .padding(.vertical, HandySpacing.s12)
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { res in
            if case .success(let url) = res { load(url) }
        }
        .handoff("pdfform") { p in if let u = ToolHandoff.fileURL(p) { load(u) } }
    }

    private var pickCard: some View {
        VStack(spacing: HandySpacing.s16) {
            Image(systemName: "list.bullet.rectangle.portrait").font(.system(size: 44)).foregroundStyle(HandyColor.accent)
            Text(L("Choose a PDF form — an application, a tax or school form — and fill it in here."))
                .font(HandyFont.body).foregroundStyle(HandyColor.textSecondary).multilineTextAlignment(.center)
            Button { showFiles = true } label: {
                Label(L("Choose a PDF"), systemImage: "folder").frame(maxWidth: .infinity)
            }.primaryButton()
            if let e = errorText { Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger) }
        }
        .cardStyle(padding: HandySpacing.s16)
    }

    private var noFields: some View {
        VStack(spacing: HandySpacing.s12) {
            if let img = preview { pageImage(img, maxHeight: 280) }
            Label(L("This PDF has no fillable boxes — it's a flat form."), systemImage: "info.circle")
                .font(HandyFont.bodyStrong).frame(maxWidth: .infinity, alignment: .leading)
            Text(L("You can still fill it: open Sign and use “Add text” to type anywhere on the page, then add your signature."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            NavigationLink { SignPDFView() } label: {
                Label(L("Type on it with Sign"), systemImage: "character.cursor.ibeam").frame(maxWidth: .infinity)
            }.primaryButton()
            Button(L("Choose a different PDF")) { reset() }.textButton().font(HandyFont.caption)
        }
    }

    /// Type your details once; every form after that fills its name, address, email, phone and dates for you.
    private var myDetailsCard: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s8) {
            Button {
                let n = fillFromMe()
                autoNote = me.isEmpty ? "Add your details below first — they're kept only on this phone."
                    : (n == 0 ? "No empty fields matched your details." : "Filled \(n) field\(n == 1 ? "" : "s") from My details — check them below.")
                if me.isEmpty { editingMe = true }
            } label: { Label(L("Fill from My details"), systemImage: "person.text.rectangle").frame(maxWidth: .infinity) }.primaryButton()
                .accessibilityIdentifier("form-mydetails")
            if let autoNote { Text(L(autoNote)).font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
            DisclosureGroup(isExpanded: $editingMe) {
                VStack(spacing: 6) {
                    HStack { TextField(L("First name"), text: $me.first); TextField(L("Last name"), text: $me.last) }
                    TextField(L("Email"), text: $me.email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    TextField(L("Phone"), text: $me.phone).keyboardType(.phonePad)
                    TextField(L("Street address"), text: $me.street)
                    HStack { TextField(L("City"), text: $me.city); TextField(L("State / county"), text: $me.region) }
                    HStack { TextField(L("Postcode / ZIP"), text: $me.postcode); TextField(L("Country"), text: $me.country) }
                    TextField(L("Date of birth"), text: $me.birth)
                    Text(L("Kept only on this phone, never sent anywhere.")).font(HandyFont.micro).foregroundStyle(HandyColor.textSecondary)
                }.textFieldStyle(.handy).font(HandyFont.body)
            } label: { Text(L("My details")).font(HandyFont.caption.weight(.semibold)) }
            .onChange(of: me) { _, v in v.save() }
        }.cardStyle(padding: HandySpacing.s12)
    }

    /// Empty fields only, so nothing already typed is overwritten.
    @discardableResult private func fillFromMe() -> Int {
        var n = 0
        for f in fields where f.kind == .text && (values[f.id] ?? f.value).trimmingCharacters(in: .whitespaces).isEmpty {
            if let v = me.value(for: f.name) { values[f.id] = v; n += 1 }
        }
        return n
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: HandySpacing.s12) {
            if let img = preview { pageImage(img, maxHeight: 220) }
            Text("\(fields.count) \(fields.count == 1 ? L("field") : L("fields"))")
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            myDetailsCard
            ForEach(fields) { f in row(f) }
            if let e = errorText {
                Text(L(e)).font(HandyFont.caption).foregroundStyle(HandyColor.danger)
            }
            Button { run() } label: {
                Label(L("Fill & preview"), systemImage: "checkmark.rectangle").frame(maxWidth: .infinity)
            }.primaryButton().disabled(working)
            if working { ToolProgressBar(label: "Filling your form…") }
            Button(L("Choose a different PDF")) { reset() }.textButton().font(HandyFont.caption)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private func row(_ f: PDFForm.Field) -> some View {
        let binding = Binding<String>(get: { values[f.id] ?? f.value }, set: { values[f.id] = $0 })
        VStack(alignment: .leading, spacing: HandySpacing.s4) {
            if f.kind != .checkbox {
                Text(f.name + (fields.contains { $0.page > 0 } ? " · \(L("page")) \(f.page + 1)" : ""))
                    .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
            }
            switch f.kind {
            case .text:
                if f.multiline {
                    TextField(L("Type here"), text: binding, axis: .vertical).lineLimit(2...6).textFieldStyle(.handy)
                } else {
                    TextField(L("Type here"), text: binding).textFieldStyle(.handy)
                }
            case .checkbox:
                Toggle(isOn: Binding(get: { !(values[f.id] ?? f.value).isEmpty },
                                     set: { values[f.id] = $0 ? "1" : "" })) {
                    Text(f.name).font(HandyFont.body)
                }.tint(HandyColor.accent)
            case .choice:
                if f.options.isEmpty {
                    TextField(L("Type here"), text: binding).textFieldStyle(.handy)
                } else {
                    Picker(f.name, selection: binding) {
                        Text(L("Choose…")).tag("")
                        ForEach(f.options, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pageImage(_ img: UIImage, maxHeight: CGFloat) -> some View {
        Image(uiImage: img).resizable().scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .clipShape(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: HandyRadius.input, style: .continuous).stroke(HandyColor.border, lineWidth: 1))
    }

    private func result(_ url: URL) -> some View {
        VStack(spacing: HandySpacing.s12) {
            Label("\(L("Filled")) — \(filledCount) \(filledCount == 1 ? L("answer") : L("answers"))", systemImage: "checkmark.circle.fill")
                .font(HandyFont.caption).foregroundStyle(HandyColor.success)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let img = resultPreview { pageImage(img, maxHeight: 380) }
            Text(L("It's still a working form — you or anyone can change the answers later."))
                .font(HandyFont.caption).foregroundStyle(HandyColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            KeepShare(url, tool: "Fill a form")
            Button(L("Keep editing")) { resultURL = nil; resultPreview = nil }.textButton().font(HandyFont.caption)
        }
    }

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let doc = PDFDocument(data: data) else {
            errorText = "Couldn't open that PDF."; return
        }
        guard !doc.isLocked else { errorText = "That PDF is password-locked — remove the password with Protect first."; return }
        sourceData = data
        fileName = url.deletingPathExtension().lastPathComponent
        fields = PDFForm.fields(data)
        values = [:]
        preview = doc.page(at: 0)?.thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
        resultURL = nil; resultPreview = nil; errorText = nil
    }

    private func reset() {
        sourceData = nil; fields = []; values = [:]; preview = nil; resultURL = nil; resultPreview = nil; errorText = nil
    }

    private func run() {
        guard let data = sourceData else { return }
        working = true; errorText = nil
        let vals = values
        let base = fileName.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        let firstPage = fields.first { vals[$0.id] != nil }?.page ?? 0
        Task { @MainActor in
            let out: URL? = await Task.detached(priority: .userInitiated) {
                guard let d = PDFForm.fill(data, values: vals) else { return nil }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(base.isEmpty ? "Form" : String(base.prefix(50))) (filled).pdf")
                try? FileManager.default.removeItem(at: url)
                guard (try? d.write(to: url)) != nil else { return nil }
                return url
            }.value
            working = false
            // Check the REAL output by reopening it.
            guard let url = out, let doc = PDFDocument(url: url), let back = try? Data(contentsOf: url) else {
                errorText = "Couldn't save the form — try again."; return
            }
            let reread = PDFForm.fields(back)
            filledCount = reread.filter { !$0.value.isEmpty }.count
            resultPreview = doc.page(at: min(firstPage, doc.pageCount - 1))?
                .thumbnail(of: CGSize(width: 900, height: 1200), for: .mediaBox)
            resultURL = url
            HandyHaptics.success()
        }
    }
}
