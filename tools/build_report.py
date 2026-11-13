"""Build the report (.docx and .pdf) from report/*.md.

Moved into the repository from report-draft/build_docx.py at Task S0.3, and called by
`Rscript make.R --release` after every stage has run. Run by hand from the project root:

    python3 tools/build_report.py

Design: document-design skill, Meridian palette (professional register, JHF/CASH audience).
Two passes: pass 1 renders to PDF with LibreOffice to find the page of each section, pass 2
writes those page numbers into the table of contents field.

Sections are every report/NN-*.md in order, then report/appendix.md if present. Figures and
their captions come from report/figures.csv. LibreOffice is found through the SOFFICE
environment variable, then the PATH, then the usual install locations.
"""
import csv, os, re, subprocess, sys, tempfile, shutil
from pathlib import Path
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_TAB_ALIGNMENT, WD_TAB_LEADER
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt, Inches, RGBColor, Emu

REPO = Path(__file__).resolve().parent.parent
## Task S5.4: `--supplement` builds the technical supplement from report/supplement/
## (sections A-*.md, B-*.md, ... in order, figures numbered S1, S2, ... from its own
## figures.csv) into its own document; without it, the main report as before.
SUPP = "--supplement" in sys.argv
REPORT = REPO / "report" / "supplement" if SUPP else REPO / "report"
FIGS = REPO / "output" / "figures" / "final"
OUT = REPO / "output" / "report" / ("Variance Project - Technical Supplement.docx" if SUPP else "Variance Project - Report.docx")
FIGPFX = "S" if SUPP else ""


def find_soffice():
    cands = [os.environ.get("SOFFICE"), shutil.which("soffice"), shutil.which("libreoffice"),
             "/Applications/LibreOffice.app/Contents/MacOS/soffice", "/usr/bin/soffice",
             "/usr/lib/libreoffice/program/soffice", r"C:\Program Files\LibreOffice\program\soffice.exe"]
    for c in cands:
        if c and Path(c).is_file():
            return c
    sys.exit("LibreOffice not found: set SOFFICE to its soffice executable, or put soffice on the PATH")


SOFFICE = None  # resolved when a PDF is first rendered


def report_sections():
    if SUPP:
        return sorted(p.name for p in REPORT.glob("[A-Z]-*.md"))
    secs = sorted(p.name for p in REPORT.glob("[0-9][0-9]-*.md"))
    if (REPORT / "appendix.md").exists():
        secs.append("appendix.md")
    return secs


def report_date():
    """Date of the last commit touching this document's sources, so a rebuild of the same text is
    the same document. October 13 audit: the main report and the supplement are dated separately,
    and sources with uncommitted edits are dated today, so a build made before its commit does not
    carry the previous revision's date."""
    paths = ["report/supplement"] if SUPP else ["report", ":(exclude)report/supplement"]
    from datetime import date
    try:
        git = ["git", "-C", str(REPO)]
        dirty = subprocess.run(git + ["status", "--porcelain", "--"] + paths,
                               capture_output=True, text=True, check=True).stdout.strip()
        d = "" if dirty else subprocess.run(git + ["log", "-1", "--format=%cs", "--"] + paths,
                                            capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        d = ""
    y, m, dd = (int(x) for x in (d or date.today().isoformat()).split("-"))
    return date(y, m, dd).strftime("%B %-d, %Y")


SECTIONS = report_sections()

TITLE = "Community disadvantage and hospital patient safety scores"
SUBTITLE = ("How much of the variation in PSI-90 tracks the communities hospitals serve, "
            "and where a Q-HIP-style incentive would send its money")
if SUPP:
    TITLE = "Technical supplement"
    SUBTITLE = ("Community disadvantage and hospital patient safety scores: methods, "
                "exploratory analyses, sensitivity tables and the number registry")
FOOTER = f"Patient Safety Variance Project  ·  Carl Jacobsen  ·  Draft for review, {report_date()} revision"

def load_figures():
    with open(REPORT / "figures.csv", newline="") as f:
        rows = list(csv.DictReader(f))
    ## October 7 audit A12: a figure marked `place = next-section` is held until after the
    ## first table following the next heading, so a tall figure does not leave a mostly blank page
    global DEFER_FIG
    DEFER_FIG = {int(r["number"]) for r in rows if (r.get("place") or "").strip() == "next-section"}
    ## October 13 audit: a figure marked `place = after-heading` goes directly under the heading of
    ## the section that first cites it, so a tall figure starts that section's page beside its text
    global HEAD_FIG
    HEAD_FIG = {int(r["number"]) for r in rows if (r.get("place") or "").strip() == "after-heading"}
    return {int(r["number"]): (r["file"], r["caption"]) for r in rows}


DEFER_FIG = set()
HEAD_FIG = set()


FIGURES = load_figures()

# Meridian palette
ACCENT = RGBColor(0x4A, 0x7F, 0xB3)
ANCHOR = RGBColor(0x1E, 0x3A, 0x5C)
GRAY = RGBColor(0x6B, 0x8B, 0xA4)
INK = RGBColor(0x1A, 0x1A, 0x1A)
TINT_HEX, ANCHOR_HEX, BORDER_HEX, GRAY_HEX = "EBF2F8", "1E3A5C", "D0DCE8", "6B8BA4"
BODY_FONT = "Calibri"
TEXT_WIDTH_TW = 9360  # 6.5 in


# ---------------------------------------------------------------- low-level XML helpers
def set_cell_shading(cell, hex_fill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear"); shd.set(qn("w:color"), "auto"); shd.set(qn("w:fill"), hex_fill)
    tcPr.append(shd)


def set_cell_borders(cell, **edges):
    tcPr = cell._tc.get_or_add_tcPr()
    b = OxmlElement("w:tcBorders")
    for edge in ("top", "left", "bottom", "right"):
        el = OxmlElement(f"w:{edge}")
        spec = edges.get(edge)
        if spec:
            el.set(qn("w:val"), "single"); el.set(qn("w:sz"), str(spec[0])); el.set(qn("w:space"), "0")
            el.set(qn("w:color"), spec[1])
        else:
            el.set(qn("w:val"), "nil")
        b.append(el)
    tcPr.append(b)


def set_cell_width(cell, tw):
    tcPr = cell._tc.get_or_add_tcPr()
    w = OxmlElement("w:tcW"); w.set(qn("w:w"), str(tw)); w.set(qn("w:type"), "dxa")
    tcPr.append(w)


def set_table_props(table, widths):
    tbl = table._tbl
    tblPr = tbl.tblPr
    for tag in ("w:tblW", "w:tblLayout", "w:tblCellMar", "w:tblBorders"):
        for el in tblPr.findall(qn(tag)):
            tblPr.remove(el)
    w = OxmlElement("w:tblW"); w.set(qn("w:w"), str(sum(widths))); w.set(qn("w:type"), "dxa"); tblPr.append(w)
    lay = OxmlElement("w:tblLayout"); lay.set(qn("w:type"), "fixed"); tblPr.append(lay)
    borders = OxmlElement("w:tblBorders")
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        el = OxmlElement(f"w:{edge}"); el.set(qn("w:val"), "nil"); borders.append(el)
    tblPr.append(borders)
    mar = OxmlElement("w:tblCellMar")
    for edge, v in (("top", 90), ("bottom", 90), ("left", 100), ("right", 100)):
        el = OxmlElement(f"w:{edge}"); el.set(qn("w:w"), str(v)); el.set(qn("w:type"), "dxa"); mar.append(el)
    tblPr.append(mar)
    grid = tbl.tblGrid
    for gc, wd in zip(grid.findall(qn("w:gridCol")), widths):
        gc.set(qn("w:w"), str(wd))


def row_props(row, header=False):
    trPr = row._tr.get_or_add_trPr()
    cs = OxmlElement("w:cantSplit"); trPr.append(cs)
    if header:
        th = OxmlElement("w:tblHeader"); trPr.append(th)


def keep_next(p, on=True):
    p.paragraph_format.keep_with_next = on


def para_border_top(p, hex_color, sz=4):
    pPr = p._p.get_or_add_pPr()
    bdr = OxmlElement("w:pBdr")
    top = OxmlElement("w:top")
    top.set(qn("w:val"), "single"); top.set(qn("w:sz"), str(sz)); top.set(qn("w:space"), "6"); top.set(qn("w:color"), hex_color)
    bdr.append(top); pPr.append(bdr)


def add_field_run(p, instr):
    def fc(t):
        r = p.add_run(); el = OxmlElement("w:fldChar"); el.set(qn("w:fldCharType"), t); r._r.append(el); return r
    fc("begin")
    r = p.add_run(); it = OxmlElement("w:instrText"); it.set(qn("xml:space"), "preserve"); it.text = instr; r._r.append(it)
    fc("separate")
    return fc


# ---------------------------------------------------------------- inline text
TOKEN = re.compile(r"(`[^`]+`)|(_\{[^}]+\}|_[A-Za-z]+)|(\^\{[^}]+\})|(\*\*[^*]+\*\*)|((?<![*\w])\*[^*\s][^*]*\*(?![*\w]))")


def add_inline(p, text, size=None, color=None, italic=None, font=None):
    """Write text into paragraph p: `code` spans, x_sub / x_{sub} subscripts, ^{sup} superscripts, **bold**."""
    pos = 0
    for m in TOKEN.finditer(text):
        if m.start() > pos:
            _run(p, text[pos:m.start()], size, color, italic, font)
        if m.group(1):
            s = m.group(1)[1:-1]
            if s.startswith(("https://", "http://")):  # October 13 audit: references carry direct links
                add_hyperlink(p, s, size, font)
            else:
                r = _run(p, s, size, color, italic, font)  # file paths in the body face: one typeface
        elif m.group(2):
            s = m.group(2)[1:]
            s = s[1:-1] if s.startswith("{") else s
            r = _run(p, s, size, color, italic, font); r.font.subscript = True
        elif m.group(3):
            r = _run(p, m.group(3)[2:-1], size, color, italic, font); r.font.superscript = True
        elif m.group(4):  # October 7 audit A12: the glossary's bold terms rendered, not printed as asterisks
            r = _run(p, m.group(4)[2:-2], size, color, italic, font); r.bold = True
        elif m.group(5):  # titles in the source lists
            r = _run(p, m.group(5)[1:-1], size, color, True, font)
        pos = m.end()
    if pos < len(text):
        _run(p, text[pos:], size, color, italic, font)


def add_hyperlink(p, url, size, font):
    rid = p.part.relate_to(url, "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
                           is_external=True)
    h = OxmlElement("w:hyperlink"); h.set(qn("r:id"), rid)
    r = _run(p, url, size, ACCENT, None, font)
    r._r.getparent().remove(r._r)
    h.append(r._r); p._p.append(h)


def _run(p, s, size, color, italic, font):
    r = p.add_run(s)
    if size: r.font.size = size
    if color is not None: r.font.color.rgb = color
    if italic: r.italic = True
    if font:
        r.font.name = font
        r._r.get_or_add_rPr().get_or_add_rFonts().set(qn("w:eastAsia"), font)
    return r


# ---------------------------------------------------------------- document setup
def setup(doc):
    sec = doc.sections[0]
    sec.page_width, sec.page_height = Inches(8.5), Inches(11)
    for side in ("left_margin", "right_margin", "top_margin", "bottom_margin"):
        setattr(sec, side, Inches(1))
    sec.footer_distance = Inches(0.5)

    st = doc.styles
    normal = st["Normal"]
    normal.font.name = BODY_FONT; normal.font.size = Pt(11); normal.font.color.rgb = INK
    normal.element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:eastAsia"), BODY_FONT)
    pf = normal.paragraph_format
    pf.space_before, pf.space_after, pf.line_spacing = Pt(0), Pt(7), 1.15

    h1 = st["Heading 1"]
    h1.font.name = BODY_FONT; h1.font.size = Pt(16); h1.font.bold = True; h1.font.color.rgb = ANCHOR
    h1.paragraph_format.space_before, h1.paragraph_format.space_after = Pt(24), Pt(10)
    h1.paragraph_format.keep_with_next = True
    h2 = st["Heading 2"]
    h2.font.name = BODY_FONT; h2.font.size = Pt(13); h2.font.bold = True; h2.font.color.rgb = ACCENT
    h2.paragraph_format.space_before, h2.paragraph_format.space_after = Pt(15), Pt(5)
    h2.paragraph_format.keep_with_next = True
    for h in (h1, h2):
        h.font.italic = False
        rf = h.element.get_or_add_rPr().get_or_add_rFonts()
        for a in ("w:asciiTheme", "w:hAnsiTheme", "w:eastAsiaTheme", "w:cstheme"):
            if rf is not None and rf.get(qn(a)) is not None:
                del rf.attrib[qn(a)]
        rf.set(qn("w:ascii"), BODY_FONT); rf.set(qn("w:hAnsi"), BODY_FONT)
        h.paragraph_format.line_spacing = 1.0

    toc1 = st["TOC 1"] if "TOC 1" in [s.name for s in st] else st.add_style("TOC 1", 1)
    toc1.base_style = normal
    toc1.font.size = Pt(10.5)
    toc1.paragraph_format.space_after = Pt(2)
    toc1.paragraph_format.tab_stops.add_tab_stop(Inches(6.5), WD_TAB_ALIGNMENT.RIGHT, WD_TAB_LEADER.DOTS)

    # footer: rule above, text left, page number right
    fp = sec.footer.paragraphs[0]
    fp.paragraph_format.tab_stops.add_tab_stop(Inches(6.5), WD_TAB_ALIGNMENT.RIGHT)
    para_border_top(fp, BORDER_HEX, 4)
    _run(fp, FOOTER, Pt(8.5), GRAY, None, None)
    _run(fp, "\t", Pt(8.5), GRAY, None, None)
    end = add_field_run(fp, "PAGE")
    r = _run(fp, "1", Pt(8.5), GRAY, None, None)
    end("end")
    for run in fp.runs:
        run.font.size = Pt(8.5); run.font.color.rgb = GRAY


# ---------------------------------------------------------------- blocks
def add_title(doc):
    p = doc.add_paragraph(); p.paragraph_format.space_after = Pt(4); p.paragraph_format.line_spacing = 1.0
    r = _run(p, TITLE, Pt(24), ANCHOR, None, None); r.bold = True
    p = doc.add_paragraph(); p.paragraph_format.space_after = Pt(18); p.paragraph_format.line_spacing = 1.1
    _run(p, SUBTITLE, Pt(13), GRAY, None, None)


def add_toc(doc, entries, pages):
    for i, (text, pg) in enumerate(zip(entries, pages)):
        p = doc.add_paragraph(style="TOC 1")
        end = add_field_run(p, 'TOC \\o "1-1" \\h \\z \\u') if i == 0 else None
        _run(p, text, None, None, None, None)
        _run(p, "\t" + str(pg), None, None, None, None)
        if i == 0:
            first_end = end
        if i == len(entries) - 1:
            first_end("end")
            p.paragraph_format.space_after = Pt(16)


def col_is_numeric(cells):
    pat = re.compile(r"^[−+\-]?[\d.,]+%?( \(.*\))?$|^[−+\-]?[\d.,]+%?\s*(to|–|/)\s*[−+\-]?[\d.,]+%?$|^[\d,./ ]+$|^median [\d / ]+$")
    data = [c for c in cells if c.strip()]
    if not data: return False
    return sum(bool(pat.match(c.strip())) for c in data) / len(data) >= 0.8


def add_table(doc, rows):
    header, body = rows[0], rows[1:]
    ncol = len(header)
    # column widths from content length, bounded
    lens = []
    for j in range(ncol):
        col = [header[j]] + [r[j] for r in body]
        L = max(len(header[j]) * 0.8, sum(min(len(c), 60) for c in col) / len(col) + 6)
        lens.append(max(L, 8))
    tot = sum(lens)
    widths = [int(TEXT_WIDTH_TW * l / tot) for l in lens]
    widths[-1] += TEXT_WIDTH_TW - sum(widths)
    numeric = [col_is_numeric([r[j] for r in body]) and j > 0 for j in range(ncol)]

    t = doc.add_table(rows=len(rows), cols=ncol)
    t.alignment = WD_TABLE_ALIGNMENT.LEFT
    set_table_props(t, widths)
    for i, row in enumerate(rows):
        tr = t.rows[i]
        row_props(tr, header=(i == 0))
        for j, txt in enumerate(row):
            cell = tr.cells[j]
            set_cell_width(cell, widths[j])
            p = cell.paragraphs[0]
            p.paragraph_format.space_after = Pt(0); p.paragraph_format.line_spacing = 1.05
            p.alignment = WD_ALIGN_PARAGRAPH.RIGHT if numeric[j] else WD_ALIGN_PARAGRAPH.LEFT
            if len(rows) <= 12 and i < len(rows) - 1:
                keep_next(p)  # short tables stay on one page
            if i == 0:
                set_cell_shading(cell, TINT_HEX)
                set_cell_borders(cell, bottom=(12, ANCHOR_HEX))
                r = _run(p, txt, Pt(10), ANCHOR, None, None); r.bold = True
            else:
                set_cell_borders(cell, bottom=(4, BORDER_HEX))
                add_inline(p, txt, Pt(10), INK)
    sp = doc.add_paragraph(); sp.paragraph_format.space_after = Pt(4)
    sp.paragraph_format.line_spacing = 0.8


def add_caption(doc, text, above):
    m = re.match(r"^((?:Table|Figure) [A-Z]?\.?\d*(?:\.\d+)?\.)\s*(.*)$", text)
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(4) if above else Pt(2)
    p.paragraph_format.space_after = Pt(5) if above else Pt(12)
    p.paragraph_format.line_spacing = 1.05
    if m:
        _run(p, m.group(1) + " ", Pt(9), ANCHOR, None, None)
        add_inline(p, m.group(2), Pt(9), GRAY)
    else:
        add_inline(p, text, Pt(9), GRAY)
    if above:
        keep_next(p)
    return p


def add_figure(doc, n):
    fn, cap = FIGURES[n]
    p = doc.add_paragraph(); p.paragraph_format.space_before = Pt(8); p.paragraph_format.space_after = Pt(2)
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    keep_next(p)
    p.add_run().add_picture(str(FIGS / fn), width=Inches(6.5))
    add_caption(doc, f"Figure {FIGPFX}{n}. {cap}", above=False)


def add_equation(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(4); p.paragraph_format.space_after = Pt(8)
    add_inline(p, text.strip(), Pt(11), INK)


# ---------------------------------------------------------------- markdown -> docx
def parse_blocks(md):
    lines = md.split("\n")
    blocks, i = [], 0
    while i < len(lines):
        ln = lines[i]
        if not ln.strip():
            i += 1; continue
        if ln.startswith("# "):
            blocks.append(("h1", ln[2:].strip())); i += 1
        elif ln.startswith("## "):
            blocks.append(("h2", ln[3:].strip())); i += 1
        elif ln.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            blocks.append(("table", rows))
        elif ln.startswith("$$"):
            blocks.append(("eq", ln[2:])); i += 1
        else:
            buf = [ln]; i += 1
            while i < len(lines) and lines[i].strip() and not lines[i].startswith(("#", "|", "$$")):
                buf.append(lines[i]); i += 1
            blocks.append(("p", " ".join(s.strip() for s in buf)))
    return blocks


def build(pages):
    doc = Document()
    setup(doc)
    add_title(doc)
    blocks_by_file = [(f, parse_blocks((REPORT / f).read_text())) for f in SECTIONS]
    h1s = [b[1] for _, bl in blocks_by_file for b in bl if b[0] == "h1"]
    add_toc(doc, h1s, pages or ["0"] * len(h1s))

    placed, held, seen_heading = set(), [], False
    for fname, blocks in blocks_by_file:
        for k, (kind, val) in enumerate(blocks):
            nxt = blocks[k + 1][0] if k + 1 < len(blocks) else None
            if kind in ("h1", "h2") and held:
                seen_heading = True
            if kind == "h1":
                if fname == "appendix.md":
                    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
                doc.add_paragraph(val, style="Heading 1")
            elif kind == "h2":
                h = doc.add_paragraph(val, style="Heading 2"); keep_next(h)
                for j in range(k + 1, len(blocks)):
                    if blocks[j][0] in ("h1", "h2"):
                        break
                    if blocks[j][0] == "p":
                        for n in sorted(int(x) for x in re.findall(rf"Figure {FIGPFX}(\d+)", blocks[j][1])):
                            if n in HEAD_FIG and n not in placed:
                                placed.add(n)
                                add_figure(doc, n)
            elif kind == "table":
                add_table(doc, val)
                if held and seen_heading:  # a held figure goes after the next section's first table
                    for n in held:
                        add_figure(doc, n)
                    held, seen_heading = [], False
            elif kind == "eq":
                add_equation(doc, val)
            elif kind == "p":
                if re.match(r"^Table [A-Z]?\.?\d", val) and nxt == "table":
                    add_caption(doc, val, above=True)
                    continue
                p = doc.add_paragraph()
                add_inline(p, val)
                if nxt == "table":
                    keep_next(p)
                for n in sorted(int(x) for x in re.findall(rf"Figure {FIGPFX}(\d+)", val)):
                    if n not in placed:
                        placed.add(n)
                        if n in DEFER_FIG:
                            held.append(n)
                        else:
                            add_figure(doc, n)
    for n in held:
        add_figure(doc, n)
    missing = set(FIGURES) - placed
    if missing:
        sys.exit(f"figures never referenced in text: {sorted(missing)}")
    doc.save(OUT)
    return h1s


def pdf_pages_of(h1s):
    global SOFFICE
    SOFFICE = SOFFICE or find_soffice()
    tmp = Path(tempfile.mkdtemp())
    subprocess.run([SOFFICE, f"-env:UserInstallation=file://{tmp}/lo-profile", "--headless", "--convert-to", "pdf", "--outdir", str(tmp), str(OUT)],
                   check=True, capture_output=True)
    from pypdf import PdfReader
    pdf = next(tmp.glob("*.pdf"))
    texts = [re.sub(r"\s+", " ", pg.extract_text() or "") for pg in PdfReader(str(pdf)).pages]
    pages, start = [], 0  # page 1 also carries the table of contents, so a heading there must appear twice
    for h in h1s:
        found = None
        for idx in range(start, len(texts)):
            if texts[idx].count(h) >= (2 if idx == 0 else 1):
                found = idx; break
        if found is None:
            sys.exit(f"heading not found in PDF: {h}")
        pages.append(str(found + 1))
        start = found
    return pages, pdf, len(texts)


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    h1s = build(None)
    pages, _, _ = pdf_pages_of(h1s)
    build(pages)
    pages2, pdf, npages = pdf_pages_of(h1s)
    if pages2 != pages:
        build(pages2)
        pages2, pdf, npages = pdf_pages_of(h1s)
    final_pdf = OUT.with_suffix(".pdf")
    shutil.copy(pdf, final_pdf)
    print(f"wrote {OUT.name} and {final_pdf.name}: {npages} pages")
    if SUPP:  # Task S5.4: the full number registry ships beside the supplement
        reg = OUT.parent / "Variance Project - Number Registry.csv"
        shutil.copy(REPO / "output" / "tables" / "report-numbers.csv", reg)
        print(f"wrote {reg.name}")
    for h, pg in zip(h1s, pages2):
        print(f"  p.{pg:>3}  {h}")
