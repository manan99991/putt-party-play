import UIKit
import PDFKit

/// Fill a PDF's real form fields — text boxes, checkboxes and dropdowns — on device. The answers go
/// into the fields themselves, so the filled file still works as a form in Preview, Acrobat or a browser.
enum PDFForm {
    enum Kind: Equatable { case text, checkbox, choice }

    struct Field: Identifiable, Equatable {
        let id: String          // "page-index" — stable for one file
        let page: Int
        let name: String        // the field's own label, or a friendly fallback
        let kind: Kind
        var value: String       // text / chosen option; "1" or "" for a checkbox
        let options: [String]
        let multiline: Bool
    }

    /// Every fillable field in reading order (page, then top-to-bottom). Empty for a PDF without a form.
    static func fields(_ data: Data) -> [Field] {
        guard let doc = PDFDocument(data: data), !doc.isLocked else { return [] }
        var out: [Field] = []
        for p in 0..<doc.pageCount {
            guard let page = doc.page(at: p) else { continue }
            var pageFields: [(CGRect, Field)] = []
            for (i, a) in page.annotations.enumerated() {
                guard let kind = kind(of: a) else { continue }
                let raw = (a.fieldName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let name = raw.isEmpty ? "\(kind == .checkbox ? "Checkbox" : "Field") \(out.count + pageFields.count + 1)" : raw
                let value: String
                switch kind {
                case .checkbox: value = a.buttonWidgetState == .onState ? "1" : ""
                case .text, .choice: value = a.widgetStringValue ?? ""
                }
                pageFields.append((a.bounds, Field(id: "\(p)-\(i)", page: p, name: name, kind: kind, value: value,
                                                   options: a.choices ?? [], multiline: a.isMultiline)))
            }
            // Top of the page first (PDF y grows upward), then left to right.
            pageFields.sort { abs($0.0.maxY - $1.0.maxY) > 4 ? $0.0.maxY > $1.0.maxY : $0.0.minX < $1.0.minX }
            out += pageFields.map(\.1)
        }
        return out
    }

    /// Write `values` (field id → value; "1"/"" for checkboxes) into the form. Fields not mentioned keep
    /// what they had. Nil if the PDF can't be read or is locked.
    static func fill(_ data: Data, values: [String: String]) -> Data? {
        guard let doc = PDFDocument(data: data), doc.pageCount > 0, !doc.isLocked else { return nil }
        for p in 0..<doc.pageCount {
            guard let page = doc.page(at: p) else { continue }
            for (i, a) in page.annotations.enumerated() {
                guard let kind = kind(of: a), let v = values["\(p)-\(i)"] else { continue }
                switch kind {
                case .checkbox: a.buttonWidgetState = v.isEmpty ? .offState : .onState
                case .text, .choice: a.widgetStringValue = v
                }
            }
        }
        return doc.dataRepresentation()
    }

    private static func kind(of a: PDFAnnotation) -> Kind? {
        guard (a.type ?? "").contains("Widget") else { return nil }
        switch a.widgetFieldType {
        case .text: return .text
        case .choice: return .choice
        case .button: return a.widgetControlType == .checkBoxControl ? .checkbox : nil
        default: return nil
        }
    }
}
