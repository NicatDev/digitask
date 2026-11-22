"""Tarixçə sətirlərini Excel-ə çıxarır (problemliləri düzəldib yenidən yükləmək üçün)."""
import io

from .parsers import TEMPLATE_HEADERS, TEMPLATE_SHEET, TEMPLATE_VERSION

RESULT_LABELS = {
    "new": "Yeni (yaradılacaq)",
    "created": "Yaradıldı",
    "existing": "Artıq mövcuddur",
    "duplicate_in_file": "Faylda təkrar",
    "problem": "Problemli",
}


def _safe(value):
    """Formula injection-a qarşı: =, +, -, @ ilə başlayan mətn hüceyrə formulu kimi işləməsin."""
    if value is None:
        return ""
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return value
    text = str(value)
    if text and text[0] in ("=", "+", "-", "@", "\t", "\r"):
        return "'" + text
    return text


def export_rows(rows):
    import openpyxl
    from openpyxl.styles import Alignment, Font, PatternFill

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = TEMPLATE_SHEET
    headers = [label for _f, label in TEMPLATE_HEADERS] + ["Fayldakı sətir", "Nəticə", "Səbəb / qeyd"]
    for col, label in enumerate(headers, start=1):
        c = ws.cell(row=1, column=col, value=label)
        c.font = Font(bold=True, color="FFFFFF")
        c.fill = PatternFill("solid", fgColor="1F4E78")
        c.alignment = Alignment(wrap_text=True, vertical="center")
    widths = [34, 20, 28, 22, 26, 20, 40, 14, 14, 12, 18, 70]
    for i, w in enumerate(widths, start=1):
        ws.column_dimensions[openpyxl.utils.get_column_letter(i)].width = w
    ws.freeze_panes = "A2"

    r = 2
    for row in rows:
        raw = row.raw or {}
        values = [raw.get(field) for field, _l in TEMPLATE_HEADERS]
        notes = [x.get("message", "") for x in (row.reasons or [])] + [x.get("message", "") for x in (row.warnings or [])]
        values += [row.row_number, RESULT_LABELS.get(row.result, row.result), "\n".join(notes)]
        for col, v in enumerate(values, start=1):
            cell = ws.cell(row=r, column=col, value=_safe(v))
            if col <= 7:
                cell.number_format = "@"
            if col == len(values):
                cell.alignment = Alignment(wrap_text=True, vertical="top")
        r += 1

    meta = wb.create_sheet("_meta")
    meta["A1"] = TEMPLATE_VERSION
    meta.sheet_state = "hidden"
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()
