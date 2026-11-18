import Foundation
import UniformTypeIdentifiers
import CoreTransferable

/// A real Excel workbook (.xlsx) built on device — opens in Excel, Numbers, Google Sheets and Files with
/// numbers as numbers (they sum and sort), a bold header row, frozen header, and columns sized to their
/// content. An .xlsx is a ZIP of a few XML parts, so this is ZipWriter plus the smallest valid set of parts.
enum XLSXWriter {
    /// `rows[0]` is the header when `header` is true.
    static func workbook(rows: [[String]], sheetName: String = "Sheet1", header: Bool = true) -> Data? {
        guard !rows.isEmpty else { return nil }
        let width = rows.map(\.count).max() ?? 0
        guard width > 0 else { return nil }
        let name = String(sheetName.filter { !"[]:*?/\\".contains($0) }.prefix(31)).isEmpty ? "Sheet1"
            : String(sheetName.filter { !"[]:*?/\\".contains($0) }.prefix(31))

        // Column widths from the longest value (Excel "characters"), clamped.
        var widths = [Int](repeating: 8, count: width)
        for r in rows { for (c, v) in r.enumerated() { widths[c] = min(60, max(widths[c], v.count + 2)) } }
        let cols = widths.enumerated().map { "<col min=\"\($0.offset + 1)\" max=\"\($0.offset + 1)\" width=\"\($0.element)\" customWidth=\"1\"/>" }.joined()

        var sheetRows = ""
        for (ri, r) in rows.enumerated() {
            let rowNum = ri + 1
            var cells = ""
            for c in 0..<width {
                let v = c < r.count ? r[c] : ""
                guard !v.isEmpty else { continue }
                let ref = column(c) + String(rowNum)
                let bold = header && ri == 0
                if !bold, let n = number(v) {
                    cells += "<c r=\"\(ref)\"><v>\(n)</v></c>"
                } else {
                    cells += "<c r=\"\(ref)\" t=\"inlineStr\"\(bold ? " s=\"1\"" : "")><is><t xml:space=\"preserve\">\(escape(v))</t></is></c>"
                }
            }
            sheetRows += "<row r=\"\(rowNum)\">\(cells)</row>"
        }
        let freeze = header && rows.count > 1
            ? "<sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"1\" topLeftCell=\"A2\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews>"
            : "<sheetViews><sheetView workbookViewId=\"0\"/></sheetViews>"
        let lastRef = column(width - 1) + String(rows.count)
        let sheet = xmlHead + "<worksheet xmlns=\"\(mainNS)\" xmlns:r=\"\(relNS)\"><dimension ref=\"A1:\(lastRef)\"/>\(freeze)<cols>\(cols)</cols><sheetData>\(sheetRows)</sheetData></worksheet>"

        let parts: [ZipWriter.Item] = [
            .init(name: "[Content_Types].xml", data: Data((xmlHead + """
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
            <Default Extension="xml" ContentType="application/xml"/>\
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
            <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\
            </Types>
            """).utf8)),
            .init(name: "_rels/.rels", data: Data((xmlHead + """
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
            </Relationships>
            """).utf8)),
            .init(name: "xl/workbook.xml", data: Data((xmlHead + """
            <workbook xmlns="\(mainNS)" xmlns:r="\(relNS)"><sheets><sheet name="\(escape(name))" sheetId="1" r:id="rId1"/></sheets></workbook>
            """).utf8)),
            .init(name: "xl/_rels/workbook.xml.rels", data: Data((xmlHead + """
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\
            </Relationships>
            """).utf8)),
            .init(name: "xl/worksheets/sheet1.xml", data: Data(sheet.utf8)),
            .init(name: "xl/styles.xml", data: Data((xmlHead + """
            <styleSheet xmlns="\(mainNS)">\
            <fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>\
            <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>\
            <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>\
            <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>\
            <cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>\
            <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>\
            </styleSheet>
            """).utf8)),
        ]
        guard case .success(let zip) = ZipWriter.zip(parts) else { return nil }
        return zip
    }

    /// A plain number for the cell, when the text is clearly one ("1,234.50", "$12", "-3", "45%" stays text).
    static func number(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s.count <= 20, !s.hasSuffix("%") else { return nil }
        for sym in ["$", "€", "£", "¥", "₹"] where s.hasPrefix(sym) { s.removeFirst(sym.count) }
        if s.hasPrefix("0"), s.count > 1, !s.hasPrefix("0.") { return nil }        // keep leading zeros (IDs, ZIPs)
        let thousands = #"^-?\d{1,3}(,\d{3})+(\.\d+)?$"#
        if s.range(of: thousands, options: .regularExpression) != nil { s = s.replacingOccurrences(of: ",", with: "") }
        guard s.range(of: #"^-?\d+(\.\d+)?$"#, options: .regularExpression) != nil, let d = Double(s), d.isFinite else { return nil }
        return s
    }

    /// 0 → "A", 25 → "Z", 26 → "AA".
    static func column(_ i: Int) -> String {
        var n = i + 1, s = ""
        while n > 0 { let r = (n - 1) % 26; s = String(UnicodeScalar(65 + r)!) + s; n = (n - 1) / 26 }
        return s
    }

    static func escape(_ s: String) -> String {
        var out = s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
        out.unicodeScalars.removeAll { $0.value < 0x20 && $0 != "\t" && $0 != "\n" && $0 != "\r" }   // XML-illegal controls
        return out
    }

    private static let xmlHead = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
    private static let mainNS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    private static let relNS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
}

/// Share an .xlsx with the right type, so Files, Mail and Excel recognise it.
struct XLSXFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data) { $0.data }
    }
}
