"""Nümunə Excel şablonu və JSON nümunəsi."""
import io
import json

from tasks.models import Equipment, OpticBox
from users.models import Region

from .parsers import FIELD_LABELS, TEMPLATE_HEADERS, TEMPLATE_SHEET, TEMPLATE_VERSION

TEXT_ROWS = 3000  # "Mətn" formatı veriləcək sətir sayı (nömrələrin əvvəlindəki 0 itməsin)

INSTRUCTIONS = [
    ("Necə doldurmalı?", None),
    ("1. Müştəriləri “Müştərilər” vərəqinə, hər müştərini bir sətirə yazın. Başlıq sətrini dəyişməyin.", None),
    ("2. Ulduzlu (*) sütunlar məcburidir: Ad Soyad və Region.", None),
    ("3. Qeydiyyat nömrəsi və ya Telefon — ikisindən ən azı biri mütləq yazılmalıdır.", None),
    ("4. Telefonu istənilən formada yaza bilərsiniz: 0554264644, 554264644, +994 55 426 46 44.", None),
    ("   Bir neçə telefon varsa vergüllə ayırın: 0554264644, 0501234567", None),
    ("5. Region / Avadanlıq / Optik qutu üçün siyahıdan seçin. Siyahıda yoxdursa yeni ad yaza bilərsiniz —", None),
    ("   sistem əvvəlcə oxşar adı axtarır, tapmasa yenisini yaradır.", None),
    ("6. Koordinatlar istəyə bağlıdır. Yazırsınızsa, Enlik və Uzunluq ikisi birlikdə olmalıdır (məs. 40.4093 və 49.8671).", None),
    ("", None),
    ("Nə olacaq?", None),
    ("• Sistemdə artıq olan müştərilər (qeydiyyat nömrəsi və ya telefonu üst-üstə düşənlər) yaradılmır və dəyişdirilmir.", None),
    ("• Səhv və ya şübhəli sətirlər yaradılmır — səbəbi ilə birlikdə göstərilir, düzəldib yenidən yükləyə bilərsiniz.", None),
    ("• Yükləyəndən sonra əvvəlcə nəticəni görürsünüz, yalnız “Təsdiqlə” düyməsindən sonra müştərilər yaradılır.", None),
    ("", None),
    ("Nümunə sətir (bu vərəqdən import olunmur):", None),
]
EXAMPLE_ROW = ["Məmmədov Əli Vəli oğlu", "0554264644", "0554264644, 0501234567", "Suraxanı",
               "Suraxanı_OLT61", "", "Suraxanı qəs., Ə. Əliyev küç. 12", "40.4211", "50.0012"]


def build_excel_template():
    import openpyxl
    from openpyxl.styles import Alignment, Font, PatternFill
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.datavalidation import DataValidation

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = TEMPLATE_SHEET

    header_fill = PatternFill("solid", fgColor="1F4E78")
    required_fill = PatternFill("solid", fgColor="C00000")
    widths = [34, 20, 28, 22, 26, 20, 40, 14, 14]
    required = {"full_name", "region"}
    for col, ((field, label), width) in enumerate(zip(TEMPLATE_HEADERS, widths), start=1):
        cell = ws.cell(row=1, column=col, value=label)
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = required_fill if field in required else header_fill
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        letter = get_column_letter(col)
        ws.column_dimensions[letter].width = width
        if field not in ("lat", "lng"):
            ws.column_dimensions[letter].number_format = "@"
            for r in range(2, TEXT_ROWS + 2):
                ws.cell(row=r, column=col).number_format = "@"
    ws.row_dimensions[1].height = 30
    ws.freeze_panes = "A2"

    # Açılan siyahılar (yeni ad yazmaq da mümkündür — xəta göstərilmir)
    lists = wb.create_sheet("Siyahılar")
    sources = [
        ("region", list(Region.objects.filter(is_active=True).order_by("name").values_list("name", flat=True))),
        ("equipment", list(Equipment.objects.filter(is_active=True).order_by("name").values_list("name", flat=True))),
        ("optic_box", list(OpticBox.objects.filter(is_active=True).order_by("name").values_list("name", flat=True))),
    ]
    field_cols = {f: i for i, (f, _l) in enumerate(TEMPLATE_HEADERS, start=1)}
    for i, (field, names) in enumerate(sources, start=1):
        letter = get_column_letter(i)
        lists.cell(row=1, column=i, value=FIELD_LABELS[field]).font = Font(bold=True)
        for r, name in enumerate(names, start=2):
            lists.cell(row=r, column=i, value=name)
        if names:
            dv = DataValidation(
                type="list",
                formula1=f"='Siyahılar'!${letter}$2:${letter}${len(names) + 1}",
                allow_blank=True,
                showErrorMessage=False,
            )
            target = get_column_letter(field_cols[field])
            dv.add(f"{target}2:{target}{TEXT_ROWS + 1}")
            ws.add_data_validation(dv)
        lists.column_dimensions[letter].width = 34
    lists.sheet_state = "hidden"

    guide = wb.create_sheet("Təlimat")
    guide.column_dimensions["A"].width = 110
    r = 1
    for text, _ in INSTRUCTIONS:
        c = guide.cell(row=r, column=1, value=text)
        if text and not text.startswith((" ", "•")) and not text[0].isdigit():
            c.font = Font(bold=True, size=12)
        r += 1
    for col, ((_f, label), val) in enumerate(zip(TEMPLATE_HEADERS, EXAMPLE_ROW), start=1):
        guide.cell(row=r, column=col, value=label).font = Font(bold=True)
        guide.cell(row=r + 1, column=col, value=val)

    meta = wb.create_sheet("_meta")
    meta["A1"] = TEMPLATE_VERSION
    meta.sheet_state = "hidden"

    wb.active = 0
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def build_json_sample():
    sample = [
        {
            "full_name": "Məmmədov Əli Vəli oğlu",
            "register_number": "0554264644",
            "phone_number": "0554264644, 0501234567",
            "region": "Suraxanı",
            "equipment": "Suraxanı_OLT61",
            "optic_box": "",
            "address": "Suraxanı qəs., Ə. Əliyev küç. 12",
            "lat": 40.4211,
            "lng": 50.0012,
        },
        {
            "full_name": "Həsənova Leyla Rauf qızı",
            "register_number": "",
            "phone_number": "+994 70 123 45 67",
            "region": "Hövsan-Kənd",
            "equipment": "",
            "optic_box": "",
            "address": "",
            "lat": None,
            "lng": None,
        },
    ]
    return json.dumps(sample, ensure_ascii=False, indent=2).encode("utf-8")
