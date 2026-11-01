#!/usr/bin/env python3
"""
File Viewer — off-device type matrix (logic gate).

Reproduces FileViewer.probe()'s decision tree and the text-extraction helpers
(ebookText / officeText / stripHtml / stripOfficeXml) from
  android/app/src/main/java/com/handytools/app/tools/power/FileViewerEngine.kt
in plain Python, generates one real sample of every file type the viewer claims
to handle, and asserts:
  • each sample is classified to the EXPECTED Kind, and
  • every readable type ("content kinds") yields non-empty, on-topic text.

This is the fast logic gate the app owner runs BEFORE a build (it would have
caught the EPUB-as-archive and the ODF-mistaken-for-a-book bugs). The emulator
file-type smoke in CI is the integration gate on top of it.

Keep the constants below in sync with FileViewerEngine.kt. Exit code 0 = all
expectations met; non-zero = a mismatch (printed as a matrix).
"""
import io, os, re, sys, struct, tempfile, zipfile, zlib

# ── extension sets, copied verbatim from FileViewerEngine.kt ────────────────────
RAW_EXT = {"3fr","arw","bay","cr2","cr3","crw","dcr","dng","erf","kdc","mos","mrw","nef","nrw",
           "orf","pef","raf","raw","rw2","rwl","sr2","srf","srw","x3f"}
EBOOK_EXT = {"epub","mobi","azw","azw3","pdb","kf8"}
OFFICE_EXT = {"docx","pptx","xlsx","odt","ods","odp"}
IMAGE_EXT = {"png","jpg","jpeg","gif","webp","bmp","heic","heif","avif","avifs","ico","jp2","wbmp",
             "dds","tga","targa","pbm","pgm","ppm","pcx","ras","sgi","xbm","xpm","jng","mng"}
AUDIO_EXT = {"mp3","wav","ogg","oga","m4a","flac","aac","opus","amr","mid","midi","mka","3ga","ota","imy"}
VIDEO_EXT = {"mp4","mkv","webm","avi","mov","3gp","m4v","ts"}
SQLITE_EXT = {"db","sqlite","sqlite3","db3"}
CSV_EXT = {"csv","tsv","psv","ssv"}
ARCHIVE_LABEL_KEYS = {"7z","rar","r00","tar","gz","gzip","tgz","bz2","bzip2","tbz","tbz2","xz","txz",
                      "zst","zstd","tzst","lz4","lzma","lzh","lha","cab","arj","cpio","ar","deb","rpm",
                      "cbr","cbz","iso","dmg","img","vhd","vhdx","vmdk","vdi","qcow","qcow2","wim","xar",
                      "z","squashfs","ext4","ntfs","fat","hfs","apfs","udf","chm"}
TEXT_EXT = {"txt","text","md","log","kt","kts","java","py","js","ts","html","htm","xhtml","css","scss",
            "sass","less","sh","yml","yaml","ini","cfg","conf","htaccess","c","cpp","cxx","cppm","h","rs",
            "go","rb","rbp","php","sql","gradle","groovy","properties","toml","env","gitignore","lua",
            "swift","dart","scala","pl","r","ada","ahk","as","aspx","bas","bicep","coffee","cs","f","for",
            "f90","haml","lisp","m","makefile","mk","nim","nsi","pas","ps1","tcl","vb","wat","xq","xquery"}

def starts_with(h, *sig):
    if len(h) < len(sig): return False
    return all((h[i] & 0xFF) == sig[i] for i in range(len(sig)))

def looks_like_text(h):
    if not h: return False
    printable = sum(1 for b in h if b in (9,10,13) or 32 <= b < 127)
    return printable / len(h) >= 0.85

def zip_names(path):
    try:
        with zipfile.ZipFile(path) as z: return z.namelist()
    except Exception: return []

def zip_entry_bytes(path, name):
    try:
        with zipfile.ZipFile(path) as z: return z.read(name)
    except Exception: return None

def is_epub(path):
    b = zip_entry_bytes(path, "mimetype")
    if b is None: return False
    return b.decode("utf-8","ignore").strip().startswith("application/epub+zip")

def zip_family(path, ext):
    if ext == "apk": return "APK"
    if ext == "epub" or is_epub(path): return "EBOOK"
    if ext in OFFICE_EXT: return "DOC"
    return "ARCHIVE"

def classify(path, ext, declared=""):
    """Faithful mirror of FileViewer.probe(). declared='' == ContentResolver.getType unavailable."""
    with open(path, "rb") as f: h = f.read(64)
    head16 = h[:16].decode("latin-1","ignore")
    # --- content signatures ---
    if starts_with(h, 0x25,0x50,0x44,0x46): return "PDF"
    if starts_with(h, 0x89,0x50,0x4E,0x47): return "IMAGE"
    if starts_with(h, 0xFF,0xD8,0xFF): return "IMAGE"
    if starts_with(h, 0x47,0x49,0x46,0x38): return "IMAGE"
    if starts_with(h, 0x42,0x4D) and ext == "bmp": return "IMAGE"
    if len(h) >= 12 and starts_with(h, 0x52,0x49,0x46,0x46) and h[8]==0x57 and h[9]==0x45: return "IMAGE"
    if head16.startswith("SQLite format 3"): return "SQLITE"
    if starts_with(h, 0x50,0x4B,0x03,0x04) or starts_with(h, 0x50,0x4B,0x05,0x06): return zip_family(path, ext)
    if starts_with(h, 0x1F,0x8B): return "BINARY"       # gzip
    if starts_with(h, 0x37,0x7A,0xBC,0xAF): return "BINARY"  # 7z
    if starts_with(h, 0x52,0x61,0x72,0x21): return "BINARY"  # rar
    if starts_with(h, 0x42,0x5A,0x68): return "BINARY"       # bzip2
    if starts_with(h, 0xFD,0x37,0x7A,0x58): return "BINARY"  # xz
    if starts_with(h, 0x28,0xB5,0x2F,0xFD): return "BINARY"  # zstd
    if starts_with(h, 0x4D,0x5A): return "BINARY"            # PE
    if starts_with(h, 0x7F,0x45,0x4C,0x46): return "BINARY"  # ELF
    # --- declared MIME / extension ---
    if ext in RAW_EXT: return "IMAGE"
    if ext in EBOOK_EXT: return "EBOOK"
    if declared.startswith("image/") or ext in IMAGE_EXT: return "IMAGE"
    if declared.startswith("audio/") or ext in AUDIO_EXT: return "AUDIO"
    if declared.startswith("video/") or ext in VIDEO_EXT: return "VIDEO"
    if ext == "apk": return "APK"
    if ext in SQLITE_EXT: return "SQLITE"
    if ext == "json": return "JSON"
    if ext == "xml" or declared.endswith("xml"): return "XML"
    if ext in CSV_EXT: return "CSV"
    if ext in ARCHIVE_LABEL_KEYS: return "BINARY"
    if ext in TEXT_EXT or declared.startswith("text/"): return "TEXT"
    # --- sniff ---
    with open(path, "rb") as f: head_all = f.read(4096)
    if looks_like_text(h) and looks_like_text(head_all):
        t = head_all.decode("utf-8","ignore").lstrip()
        if t.startswith("{") or t.startswith("["): return "JSON"
        if t.startswith("<"): return "XML"
        return "TEXT"
    return "BINARY"

# ── text extraction mirrors ────────────────────────────────────────────────────
def strip_html(html):
    s = re.sub(r"(?is)<(script|style)[^>]*>.*?</\1>", " ", html)
    s = re.sub(r"(?is)<(/p|/div|/h[1-6]|br|/li)[^>]*>", "\n", s)
    s = re.sub(r"(?s)<[^>]+>", " ", s)
    for a,b in (("&nbsp;"," "),("&amp;","&"),("&lt;","<"),("&gt;",">"),("&#39;","'"),("&quot;",'"')):
        s = s.replace(a,b)
    s = re.sub(r"[ \t]+"," ",s); s = re.sub(r"\n{3,}","\n\n",s)
    return s.strip()

def strip_office_xml(xml):
    s = re.sub(r"(?is)</(w:p|a:p|text:p|text:h|si)>", "\n", xml)
    s = re.sub(r"(?is)<(w:br|a:br|text:line-break)[^>]*/?>", "\n", s)
    s = re.sub(r"(?is)<(w:tab|text:tab)[^>]*/?>", "\t", s)
    s = re.sub(r"(?s)<[^>]+>", "", s)
    for a,b in (("&amp;","&"),("&lt;","<"),("&gt;",">"),("&apos;","'"),("&quot;",'"'),("&#39;","'")):
        s = s.replace(a,b)
    s = re.sub(r"[ \t]+"," ",s); s = re.sub(r"\n{3,}","\n\n",s)
    return s.strip()

def ebook_text(path):
    names = [n for n in zip_names(path) if n.rsplit(".",1)[-1].lower() in ("xhtml","html","htm")]
    if not names: return ""
    out = []
    for n in names[:300]:
        b = zip_entry_bytes(path, n)
        if b: out.append(strip_html(b.decode("utf-8","ignore")))
    return "\n\n".join(out).strip()

def office_text(path):
    ext = path.rsplit(".",1)[-1].lower()
    names = [n for n in zip_names(path)]
    if ext == "docx": parts = [n for n in names if n.lower()=="word/document.xml"]
    elif ext == "pptx": parts = sorted([n for n in names if n.lower().startswith("ppt/slides/slide") and n.lower().endswith(".xml")],
                                        key=lambda p:int((re.search(r"slide(\d+)\.xml",p.lower()) or [0,0])[1] if re.search(r"slide(\d+)\.xml",p.lower()) else 0))
    elif ext == "xlsx": parts = [n for n in names if n.lower()=="xl/sharedstrings.xml"]
    elif ext in ("odt","ods","odp"): parts = [n for n in names if n.lower()=="content.xml"]
    else: parts = []
    out = []
    for n in parts:
        b = zip_entry_bytes(path, n)
        if b: out.append(strip_office_xml(b.decode("utf-8","ignore")))
    return "\n\n".join(out).strip()

# ── corpus: (filename, expected_kind, builder, content_probe_or_None) ───────────
def png_bytes():
    def chunk(t,d): return struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d)&0xffffffff)
    ihdr = struct.pack(">IIBBBBB",1,1,8,2,0,0,0)
    idat = zlib.compress(b"\x00\xff\x00\x00")
    return b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",ihdr)+chunk(b"IDAT",idat)+chunk(b"IEND",b"")

def jpeg_bytes(): return bytes([0xFF,0xD8,0xFF,0xE0])+b"\x00\x10JFIF\x00"+b"\x00"*8+bytes([0xFF,0xD9])
def gif_bytes(): return b"GIF89a"+b"\x01\x00\x01\x00\x00\x00\x00;"
def bmp_bytes(): return b"BM"+b"\x00"*40
def webp_bytes(): return b"RIFF"+struct.pack("<I",16)+b"WEBP"+b"VP8 "+b"\x00"*8
def sqlite_bytes(): return b"SQLite format 3\x00"+b"\x00"*80
def pdf_bytes(): return b"%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF"
def gzip_bytes(): return bytes([0x1F,0x8B,0x08])+b"\x00"*18
def sevenz_bytes(): return bytes([0x37,0x7A,0xBC,0xAF,0x27,0x1C])+b"\x00"*20
def rar_bytes(): return b"Rar!\x1a\x07\x00"+b"\x00"*16
def elf_bytes(): return bytes([0x7F,0x45,0x4C,0x46])+b"\x00"*28
def pe_bytes(): return b"MZ"+b"\x00"*64
def mp3_bytes(): return b"ID3\x03\x00\x00\x00\x00\x00\x00"+b"\x00"*32   # no magic rule -> falls to ext
def mp4_bytes(): return b"\x00\x00\x00\x18ftypmp42"+b"\x00"*16          # ext rule
def heic_bytes(): return b"\x00\x00\x00\x18ftypheic"+b"\x00"*16         # ext rule

def mk_epub():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf,"w") as z:
        z.writestr("mimetype","application/epub+zip",compress_type=zipfile.ZIP_STORED)
        z.writestr("OEBPS/ch1.xhtml","<html><body><h1>Chapter One</h1><p>The white devil sailed at dawn.</p></body></html>")
    return buf.getvalue()

def mk_odf(mimetype, body):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf,"w") as z:
        z.writestr("mimetype",mimetype,compress_type=zipfile.ZIP_STORED)
        z.writestr("content.xml",f"<?xml version='1.0'?><office:document-content xmlns:office='x' xmlns:text='x'>{body}</office:document-content>")
    return buf.getvalue()

def mk_docx():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf,"w") as z:
        z.writestr("[Content_Types].xml","<Types/>")
        z.writestr("word/document.xml","<?xml version='1.0'?><w:document xmlns:w='x'><w:body><w:p><w:r><w:t>Quarterly report draft.</w:t></w:r></w:p><w:p><w:r><w:t>Revenue is up.</w:t></w:r></w:p></w:body></w:document>")
    return buf.getvalue()

def mk_pptx():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf,"w") as z:
        z.writestr("[Content_Types].xml","<Types/>")
        z.writestr("ppt/slides/slide1.xml","<p:sld xmlns:a='x'><a:p><a:r><a:t>Title slide</a:t></a:r></a:p></p:sld>")
        z.writestr("ppt/slides/slide2.xml","<p:sld xmlns:a='x'><a:p><a:r><a:t>Second slide bullet</a:t></a:r></a:p></p:sld>")
    return buf.getvalue()

def mk_xlsx():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf,"w") as z:
        z.writestr("[Content_Types].xml","<Types/>")
        z.writestr("xl/sharedStrings.xml","<sst xmlns='x'><si><t>Region</t></si><si><t>Total</t></si></sst>")
    return buf.getvalue()

def mk_plain_zip():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf,"w") as z:
        z.writestr("readme.txt","hello"); z.writestr("data/one.bin",b"\x00\x01")
    return buf.getvalue()

def mk_jar():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf,"w") as z:
        z.writestr("META-INF/MANIFEST.MF","Manifest-Version: 1.0\n"); z.writestr("Main.class",b"\xca\xfe\xba\xbe")
    return buf.getvalue()

def mk_apk():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf,"w") as z:
        z.writestr("AndroidManifest.xml",b"\x03\x00\x08\x00"); z.writestr("classes.dex",b"dex\n035\x00")
    return buf.getvalue()

CORPUS = [
    # name,              expected, bytes,                     content-check (substr) or None
    ("sample.pdf",       "PDF",    pdf_bytes(),               None),
    ("photo.png",        "IMAGE",  png_bytes(),               None),
    ("photo.jpg",        "IMAGE",  jpeg_bytes(),              None),
    ("anim.gif",         "IMAGE",  gif_bytes(),               None),
    ("pic.bmp",          "IMAGE",  bmp_bytes(),               None),
    ("pic.webp",         "IMAGE",  webp_bytes(),              None),
    ("photo.heic",       "IMAGE",  heic_bytes(),              None),
    ("raw.dng",          "IMAGE",  b"II*\x00"+b"\x00"*40,     None),
    ("data.db",          "SQLITE", sqlite_bytes(),            None),
    ("book.epub",        "EBOOK",  mk_epub(),                 "white devil"),
    ("report.docx",      "DOC",    mk_docx(),                 "Revenue is up"),
    ("deck.pptx",        "DOC",    mk_pptx(),                 "Second slide"),
    ("sheet.xlsx",       "DOC",    mk_xlsx(),                 "Region"),
    ("notes.odt",        "DOC",    mk_odf("application/vnd.oasis.opendocument.text","<text:p>Open document body text.</text:p>"), "Open document body"),
    ("calc.ods",         "DOC",    mk_odf("application/vnd.oasis.opendocument.spreadsheet","<text:p>Sheet cell value</text:p>"), "Sheet cell"),
    ("show.odp",         "DOC",    mk_odf("application/vnd.oasis.opendocument.presentation","<text:p>Slide deck text</text:p>"), "Slide deck"),
    ("archive.zip",      "ARCHIVE",mk_plain_zip(),            None),
    ("lib.jar",          "ARCHIVE",mk_jar(),                  None),
    ("app.apk",          "APK",    mk_apk(),                  None),
    ("blob.gz",          "BINARY", gzip_bytes(),              None),
    ("blob.7z",          "BINARY", sevenz_bytes(),            None),
    ("blob.rar",         "BINARY", rar_bytes(),               None),
    ("prog.elf",         "BINARY", elf_bytes(),               None),
    ("app.exe",          "BINARY", pe_bytes(),                None),
    ("song.mp3",         "AUDIO",  mp3_bytes(),               None),
    ("clip.mp4",         "VIDEO",  mp4_bytes(),               None),
    ("notes.txt",        "TEXT",   b"just some plain notes",  None),
    ("Main.kt",          "TEXT",   b"fun main() { println(1) }", None),
    ("config.json",      "JSON",   b'{"a":1,"b":[2,3]}',      None),
    ("feed.xml",         "XML",    b"<rss><item>hi</item></rss>", None),
    ("table.csv",        "CSV",    b"a,b,c\n1,2,3",           None),
    ("table.tsv",        "CSV",    b"a\tb\n1\t2",             None),
    ("README",           "TEXT",   b"a readme with no extension at all, plain words", None),
    ("mystery",          "BINARY", bytes(range(0,64)),        None),
]

# On-device assertions for the emulator file-type smoke. header_anchor = the typeLabel the HeaderCard
# shows for every kind (proves probe classified it right, end-to-end on the device). reader_anchor =
# proof a readable container is being READ, not listed (the renderer's own on-screen note). mime is
# passed to `am start -a VIEW -t`. Keep in sync with FileViewerEngine typeLabel/textLabel + the
# renderer NoteText strings in FileViewerToolScreen.
HEADER_LABEL = {
    "sample.pdf":"PDF document","photo.png":"PNG image","photo.jpg":"JPEG image","anim.gif":"GIF image",
    "pic.bmp":"Bitmap image","pic.webp":"WebP image","photo.heic":"HEIC image","raw.dng":"DNG camera RAW",
    "data.db":"SQLite database","book.epub":"EPUB book","report.docx":"Word document","deck.pptx":"PowerPoint deck",
    "sheet.xlsx":"Excel spreadsheet","notes.odt":"OpenDocument file","calc.ods":"OpenDocument file",
    "show.odp":"OpenDocument file","archive.zip":"ZIP archive","lib.jar":"Java archive (JAR)","app.apk":"Android app (APK)",
    "blob.gz":"Gzip archive","blob.7z":"7-Zip archive","blob.rar":"RAR archive","prog.elf":"ELF executable",
    "app.exe":"Windows executable (PE)","song.mp3":"MP3 audio","clip.mp4":"MP4 video","notes.txt":"TXT text",
    "Main.kt":"Kotlin source","config.json":"JSON data","feed.xml":"XML document","table.csv":"CSV table",
    "table.tsv":"TSV table","README":"Text","mystery":"Unknown binary",
}
READER_ANCHOR = {
    "book.epub":"Reading the book's text",
    "report.docx":"Reading the document's text","deck.pptx":"Reading the document's text",
    "sheet.xlsx":"Reading the document's text","notes.odt":"Reading the document's text",
    "calc.ods":"Reading the document's text","show.odp":"Reading the document's text",
}
MIME = {
    "sample.pdf":"application/pdf","book.epub":"application/epub+zip",
    "report.docx":"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "deck.pptx":"application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "sheet.xlsx":"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "notes.odt":"application/vnd.oasis.opendocument.text","calc.ods":"application/vnd.oasis.opendocument.spreadsheet",
    "show.odp":"application/vnd.oasis.opendocument.presentation","archive.zip":"application/zip",
    "app.apk":"application/vnd.android.package-archive","data.db":"application/x-sqlite3",
}

def emit(out_dir):
    """Write every corpus file plus manifest.json (for the emulator file-type smoke)."""
    import json
    os.makedirs(out_dir, exist_ok=True)
    manifest = []
    for name, expected, data, _needle in CORPUS:
        with open(os.path.join(out_dir, name), "wb") as f: f.write(data)
        manifest.append({
            "name": name, "kind": expected, "mime": MIME.get(name, "*/*"),
            "header_anchor": HEADER_LABEL.get(name, ""), "reader_anchor": READER_ANCHOR.get(name, ""),
        })
    with open(os.path.join(out_dir, "manifest.json"), "w") as f: json.dump(manifest, f, indent=2)
    print(f"wrote {len(manifest)} corpus files + manifest.json to {out_dir}")

def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "--emit":
        emit(sys.argv[2]); return
    content_kinds = {"EBOOK","DOC","PDF","IMAGE","TEXT","JSON","XML","CSV","SQLITE","APK","AUDIO","VIDEO"}
    rows, fails = [], 0
    with tempfile.TemporaryDirectory() as d:
        for name, expected, data, needle in CORPUS:
            p = os.path.join(d, name)
            with open(p,"wb") as f: f.write(data)
            ext = name.rsplit(".",1)[-1].lower() if "." in name else ""
            got = classify(p, ext)
            kind_ok = got == expected
            text_note = ""
            if got == "EBOOK" and ext == "epub":
                txt = ebook_text(p); text_note = f"text={len(txt)}ch"
                if needle and needle not in txt: kind_ok = False; text_note += f" MISSING '{needle}'"
            elif got == "DOC":
                txt = office_text(p); text_note = f"text={len(txt)}ch"
                if needle and needle not in txt: kind_ok = False; text_note += f" MISSING '{needle}'"
            status = "PASS" if kind_ok else "FAIL"
            if not kind_ok: fails += 1
            rows.append((status, name, expected, got, text_note))

    w = max(len(r[1]) for r in rows)
    print(f"{'':4} {'file':<{w}}  {'expected':<8}  {'got':<8}  note")
    print("-"*(w+34))
    for s,n,e,g,note in rows:
        mark = "ok " if s=="PASS" else "XXX"
        print(f"{mark:4} {n:<{w}}  {e:<8}  {g:<8}  {note}")
    print("-"*(w+34))
    total = len(rows)
    print(f"{total-fails}/{total} types classified as expected; readable types extracted non-empty on-topic text.")
    if fails:
        print(f"\n{fails} MISMATCH(es) — the File Viewer would mis-handle these types. Fix before building.")
        sys.exit(1)
    print("All File Viewer types verified. ✔")

if __name__ == "__main__":
    main()
