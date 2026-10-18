import SwiftUI
import UniformTypeIdentifiers

// Lets ShareLink hand off raw bytes as real files with the right type. Shared by every tool.

struct PNGFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .png) { $0.data } }
}

struct JPEGFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .jpeg) { $0.data } }
}

struct HEICFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .heic) { $0.data } }
}

struct PDFFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .pdf) { $0.data } }
}

struct VCardFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .vCard) { $0.data } }
}

struct CSVFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .commaSeparatedText) { $0.data } }
}

struct ICSFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .calendarEvent) { $0.data } }
}

struct TextFile: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation { DataRepresentation(exportedContentType: .plainText) { $0.data } }
}
