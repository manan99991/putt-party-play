// swift-tools-version:5.5
// UnRAR 6.12 (freeware source by Alexander Roshal, as bundled in UnrarKit) with a small C bridge, so File Opener can
// open .rar and .cbr. UnRAR source code may be used in any software to handle RAR archives without limitations free
// of charge, but cannot be used to develop RAR (WinRAR) compatible archiver and to re-create RAR compression algorithm,
// which is proprietary. Distribution of modified UnRAR source code in separate form or as a part of other software is
// permitted, provided that full text of this paragraph, starting from "UnRAR source code" words, is included in
// license, or in documentation if license is not available, and in source code comments of resulting package.
import PackageDescription

let package = Package(
    name: "Unrar",
    platforms: [.iOS(.v15)],
    products: [.library(name: "Unrar", targets: ["Unrar"])],
    targets: [
        .target(
            name: "Unrar",
            path: "Sources/Unrar",
            exclude: ["arccmt.cpp", "blake2s_sse.cpp", "blake2sp.cpp", "cmdfilter.cpp", "cmdmix.cpp", "coder.cpp", "crypt1.cpp", "crypt2.cpp", "crypt3.cpp", "crypt5.cpp", "hardlinks.cpp", "isnt.cpp", "log.cpp", "model.cpp", "rarpch.cpp", "recvol.cpp", "recvol3.cpp", "recvol5.cpp", "rs.cpp", "suballoc.cpp", "threadmisc.cpp", "uicommon.cpp", "uiconsole.cpp", "uisilent.cpp", "ulinks.cpp", "unpack15.cpp", "unpack20.cpp", "unpack30.cpp", "unpack50.cpp", "unpack50frag.cpp", "unpack50mt.cpp", "unpackinline.cpp", "uowners.cpp", "win32acl.cpp", "win32lnk.cpp", "win32stm.cpp", "license.txt", "acknow.txt"],
            cxxSettings: [.define("RARDLL"), .define("SILENT"), .define("RAR_SMP"),
                          .define("_FILE_OFFSET_BITS", to: "64"), .define("_LARGEFILE_SOURCE")]),
    ],
    cxxLanguageStandard: .cxx11
)
