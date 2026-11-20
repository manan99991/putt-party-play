import XCTest
@testable import HandyTools

/// Every file type on the list Manan gave (the 200+ formats a full file viewer opens) is accounted for: File Opener
/// reads it, Apple's viewer shows it, or it's on the public "not yet" list with the reason the person is told.
/// Nothing can be silently missing; the score is printed every build.
final class FormatCoverageTests: XCTestCase {
    static let list = """
    csv doc docm docx dot dotm dotx oxps pdf pot potm potx pps ppsm ppsx ppt pptm pptx psv ssv tsv xls xlsm xlsx xlt xltm xltx xps azw azw3 epub mobi pdb dat eml emlx msg oft avif avifs bmp dds exr gif heic heif ico iff jng jp2 jpg jpeg mng pbm pcd pcx pgm png ppm psd ras rgb rgba sgi svg tga targa tiff tif wbmp webp xbm xpm 3fr arw bay cr2 cr3 crw dcr dng erf kdc mos mrw nef nrw orf pef raf raw rw2 rwl sr2 srf srw x3f 7z apk apfs ar arj bz2 bzip2 cab cbr cbz chm cpio cramfs deb udeb dmg dylib elf ext4 fat gz gzip hfs iso jar lz4 lz5 lzh lha lzma ntfs qcow qcow2 rar r00 rpm simg squashfs sys tar taz tar.z tbz tbz2 tar.bz2 tgz tar.gz tlzma tar.lzma txz tar.xz tzst tar.zst udf vdi vhd vhdx avhdx vmdk wim xar xz z zip zipx zst zstd 3ga 3gpa aac amr flac imy m4a mid midi mka mp3 ogg oga opus ota wav 3gp mkv mp4 ts webm ada ahk as aspx bas bicep c coffee cpp cxx cppm cs css dart f for f90 go gradle groovy h haml htaccess ini java js json kt less lisp lua m makefile md mk nim nsi pas php pl properties ps1 py r rb rbp rs sass scss sh sql swift tcl vb wat xml xq xquery yml yaml conf cfg txt text log html htm xhtml
    """.split(whereSeparator: \.isWhitespace).map(String.init)

    func testEveryFormatOnTheListIsReadOrHonestlyListedAsNotYet() {
        var reads = 0, apple = 0, later: [String] = [], missing: [String] = []
        for e in Self.list {
            switch FileReaders.support(e.replacingOccurrences(of: "tar.", with: "")) {
            case .reads: reads += 1
            case .apple: apple += 1
            case .notYet(let why): if why == "Not supported yet." { missing.append(e) } else { later.append(e) }
            }
        }
        let score = Double(reads + apple) / Double(Self.list.count)
        print("ACC| SCORE formats n=\(Self.list.count) \(String(format: "%.3f", score)) reads=\(reads) apple=\(apple) notYet=\(later.count) unaccounted=\(missing.count)")
        print("ACC| formats not yet: \(later.joined(separator: " "))")
        XCTAssertEqual(missing, [], "formats on the list with no reader and no stated reason — build them or list them honestly")
    }
}
