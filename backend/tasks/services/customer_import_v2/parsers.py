"""
Excel (.xlsx) və JSON fayllarını sətirlərə çevirir.

Nəticə: ParsedFile(rows=[(row_number, {field: dəyər})], notes=[...])
Fayl ümumiyyətlə oxunmursa ImportFileError (istifadəçiyə göstəriləcək mesajla) atılır.
"""
import io
import json
import zipfile
from dataclasses import dataclass, field

from .normalize import clean_text, normalize_name

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB
MAX_ROWS = 20000
MAX_SCANNED_ROWS = 1_100_000  # Excel-in maksimum sətir sayından bir az çox — sonsuz dövrə qarşı

FIELDS = (
    "full_name", "register_number", "phone_number", "region",
    "equipment", "optic_box", "address", "lat", "lng",
)

FIELD_LABELS = {
    "full_name": "Ad Soyad",
    "register_number": "Qeydiyyat nömrəsi",
    "phone_number": "Telefon",
    "region": "Region",
    "equipment": "Avadanlıq",
    "optic_box": "Optik qutu",
    "address": "Ünvan",
    "lat": "Enlik (lat)",
    "lng": "Uzunluq (lng)",
}

# Şablondakı başlıqlar (sıra ilə)
TEMPLATE_HEADERS = [
    ("full_name", "Ad Soyad *"),
    ("register_number", "Qeydiyyat nömrəsi"),
    ("phone_number", "Telefon"),
    ("region", "Region *"),
    ("equipment", "Avadanlıq"),
    ("optic_box", "Optik qutu"),
    ("address", "Ünvan"),
    ("lat", "Enlik (lat)"),
    ("lng", "Uzunluq (lng)"),
]

_ALIASES = {
    "full_name": [
        "ad soyad", "ad soyad ata adi", "ad", "adi", "musteri", "musterinin adi", "musteri adi",
        "full name", "fullname", "name", "soyad ad",
    ],
    "register_number": [
        "qeydiyyat nomresi", "qeydiyyat no", "qeydiyyat", "register number", "register no",
        "registration number", "username", "user name", "abuneci nomresi", "abuneci no", "login",
    ],
    "phone_number": [
        "telefon", "telefon nomresi", "tel", "elaqe nomresi", "elaqe no", "mobil", "mobil nomre",
        "phone", "phone number", "mobile",
    ],
    "region": ["region", "region name", "regionu", "rayon", "bolge", "erazi"],
    "equipment": ["avadanliq", "equipment", "equipment name", "olt"],
    "optic_box": ["optik qutu", "optic box", "optic box name", "opticbox", "qutu"],
    "address": ["unvan", "address", "adres", "unvani"],
    "lat": ["enlik", "enlik lat", "lat", "latitude", "en dairesi"],
    "lng": ["uzunluq", "uzunluq lng", "lng", "lon", "long", "longitude", "uzunluq dairesi"],
}
HEADER_MAP = {}
for _field, _names in _ALIASES.items():
    for _n in _names:
        HEADER_MAP[normalize_name(_n)] = _field
for _field, _label in TEMPLATE_HEADERS:
    HEADER_MAP[normalize_name(_label)] = _field
    HEADER_MAP[normalize_name(_field)] = _field

TEMPLATE_SHEET = "Müştərilər"
SKIP_SHEETS = {"təlimat", "telimat", "siyahılar", "siyahilar", "_meta"}
TEMPLATE_VERSION = "customers-v1"


class ImportFileError(Exception):
    """Fayl oxunmadı — mesaj birbaşa istifadəçiyə göstərilir."""


@dataclass
class ParsedFile:
    rows: list = field(default_factory=list)       # [(row_number, {field: raw_value})]
    notes: list = field(default_factory=list)      # istifadəçi üçün qeydlər (xəbərdarlıq)
    template_version: str = ""


def detect_source(filename, head_bytes):
    name = (filename or "").lower()
    if name.endswith(".xls") or name.endswith(".csv") or name.endswith(".xlsm") or name.endswith(".ods"):
        raise ImportFileError(
            "Bu fayl formatı qəbul olunmur. Faylı Excel-də açıb “Fayl → Fərqli saxla → Excel iş kitabı (.xlsx)” kimi saxlayın."
        )
    if name.endswith(".xlsx"):
        if not head_bytes.startswith(b"PK"):
            raise ImportFileError("Fayl .xlsx adlanır, amma Excel faylı deyil və ya zədələnib.")
        return "excel"
    if name.endswith(".json"):
        return "json"
    raise ImportFileError("Yalnız Excel (.xlsx) və JSON (.json) faylları yükləmək olar.")


def _map_header(value):
    key = normalize_name(value)
    if not key:
        return None
    if key in HEADER_MAP:
        return HEADER_MAP[key]
    # "Ad Soyad (məcburi)" kimi əlavələr
    for alias, fld in HEADER_MAP.items():
        if len(alias) >= 3 and (key.startswith(alias + " ") or key.endswith(" " + alias)):
            return fld
    return None


def _check_required_columns(columns):
    missing = []
    if "full_name" not in columns:
        missing.append("Ad Soyad")
    if "region" not in columns:
        missing.append("Region")
    if "register_number" not in columns and "phone_number" not in columns:
        missing.append("Qeydiyyat nömrəsi və ya Telefon")
    if missing:
        raise ImportFileError(
            "Faylda bu sütunlar tapılmadı: " + ", ".join(missing)
            + ". Ən yaxşısı nümunə şablonu endirib onu doldurmaqdır."
        )


def parse_excel(content):
    try:
        import openpyxl
    except ImportError:  # pragma: no cover
        raise ImportFileError("Serverdə Excel dəstəyi quraşdırılmayıb (openpyxl). Administratora bildirin.")

    try:
        wb = openpyxl.load_workbook(io.BytesIO(content), read_only=True, data_only=True)
    except (zipfile.BadZipFile, KeyError, ValueError, OSError, TypeError) as exc:
        raise ImportFileError(f"Excel faylı açılmadı. Fayl zədələnib və ya şifrələnib ola bilər. ({exc.__class__.__name__})")
    except Exception as exc:  # openpyxl-in öz xətaları
        raise ImportFileError(f"Excel faylı açılmadı: {exc}")

    result = ParsedFile()
    try:
        if "_meta" in wb.sheetnames:
            try:
                result.template_version = clean_text(wb["_meta"]["A1"].value)
            except Exception:
                result.template_version = ""

        sheet = None
        if TEMPLATE_SHEET in wb.sheetnames:
            sheet = wb[TEMPLATE_SHEET]
        else:
            for name in wb.sheetnames:
                if name.strip().lower() not in SKIP_SHEETS:
                    sheet = wb[name]
                    break
        if sheet is None:
            raise ImportFileError("Faylda müştəri vərəqi tapılmadı.")

        rows_iter = sheet.iter_rows(values_only=True)

        # Başlıq sətri: ilk 10 sətir içində ən çox tanınan sütunu olan sətir
        header_row_idx, header_cells, columns = None, None, {}
        buffered = []
        for idx, cells in enumerate(rows_iter, start=1):
            buffered.append((idx, cells))
            mapped = {}
            for col, val in enumerate(cells or ()):
                fld = _map_header(val)
                if fld:
                    mapped.setdefault(fld, []).append(col)
            if len(mapped) >= 2 and len(mapped) > len(columns):
                header_row_idx, header_cells, columns = idx, cells, mapped
            if idx >= 10:
                break
        if header_row_idx is None:
            raise ImportFileError(
                "Başlıq sətri tapılmadı. Birinci sətirdə “Ad Soyad”, “Telefon”, “Region” kimi sütun adları olmalıdır."
            )
        dup = [fld for fld, cols in columns.items() if len(cols) > 1]
        if dup:
            raise ImportFileError(
                "Bu sütunlar faylda iki dəfə var: " + ", ".join(FIELD_LABELS[f] for f in dup)
                + ". Hər sütun bir dəfə olmalıdır."
            )
        col_index = {fld: cols[0] for fld, cols in columns.items()}
        _check_required_columns(col_index)

        known_cols = set(col_index.values())
        unknown = [
            clean_text(v) for c, v in enumerate(header_cells or ()) if c not in known_cols and clean_text(v)
        ]
        if unknown:
            result.notes.append({
                "code": "unknown_columns",
                "message": "Bu sütunlar tanınmadı və nəzərə alınmadı: " + ", ".join(unknown[:20]),
            })
        if result.template_version and result.template_version != TEMPLATE_VERSION:
            result.notes.append({
                "code": "old_template",
                "message": "Bu, şablonun köhnə versiyasıdır. Problem olmasa da, yeni şablonu endirmək tövsiyə olunur.",
            })

        def handle(idx, cells):
            values = {}
            any_value = False
            for fld, c in col_index.items():
                v = cells[c] if cells is not None and c < len(cells) else None
                if clean_text(v):
                    any_value = True
                values[fld] = _cell_to_raw(v)
            return any_value, values

        # Boş sətirlərdə dayanmırıq: aradakı boşluqdan sonrakı sətirlər səssizcə itməsin.
        for idx, cells in buffered:
            if idx <= header_row_idx:
                continue
            any_value, values = handle(idx, cells)
            if any_value:
                result.rows.append((idx, values))
        scanned = 0
        for idx, cells in enumerate(rows_iter, start=len(buffered) + 1):
            scanned += 1
            if scanned > MAX_SCANNED_ROWS:
                raise ImportFileError(
                    "Excel vərəqində çox sayda (formatlanmış) sətir var. Lazımsız boş sətirləri silib yenidən yükləyin."
                )
            any_value, values = handle(idx, cells)
            if not any_value:
                continue
            result.rows.append((idx, values))
            if len(result.rows) > MAX_ROWS:
                raise ImportFileError(f"Faylda {MAX_ROWS}-dən çox sətir var. Faylı hissələrə bölüb ayrı-ayrı yükləyin.")
    finally:
        wb.close()

    if not result.rows:
        raise ImportFileError("Faylda müştəri sətri yoxdur (başlıqdan sonra bütün sətirlər boşdur).")
    return result


def _cell_to_raw(v):
    """Xananı JSON-a yazıla bilən formaya salır (tarixçə üçün orijinal kimi saxlanılır)."""
    if v is None:
        return None
    if isinstance(v, (int, float, str, bool)):
        return v
    return clean_text(v) or str(v)


def parse_json(content):
    try:
        text = content.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise ImportFileError("JSON faylı UTF-8 kodlaşmasında olmalıdır. Faylı UTF-8 kimi yadda saxlayın.")
    if not text.strip():
        raise ImportFileError("JSON faylı boşdur.")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ImportFileError(
            f"JSON faylında yazı xətası var ({exc.lineno}-ci sətir, {exc.colno}-cu simvol). "
            "Faylı nümunə ilə müqayisə edin."
        )

    if isinstance(data, dict):
        for key in ("customers", "data", "items", "musteriler", "müştərilər"):
            if isinstance(data.get(key), list):
                data = data[key]
                break
        else:
            raise ImportFileError("JSON faylı müştəri siyahısı ([ ... ]) olmalıdır. Nümunə JSON-a baxın.")
    if not isinstance(data, list):
        raise ImportFileError("JSON faylı müştəri siyahısı ([ ... ]) olmalıdır. Nümunə JSON-a baxın.")
    if len(data) > MAX_ROWS:
        raise ImportFileError(f"Faylda {MAX_ROWS}-dən çox müştəri var. Faylı hissələrə bölüb ayrı-ayrı yükləyin.")

    result = ParsedFile()
    unknown_keys = set()
    seen_fields = set()
    for i, item in enumerate(data, start=1):
        if not isinstance(item, dict):
            result.rows.append((i, {"__invalid__": True, "__value__": clean_text(item)[:200]}))
            continue
        values = {}
        for k, v in item.items():
            if normalize_name(k) in ("address coordinates", "coordinates", "koordinatlar", "location"):
                lat, lng = _split_coords(v)
                values.setdefault("lat", lat)
                values.setdefault("lng", lng)
                seen_fields.update(("lat", "lng"))
                continue
            fld = _map_header(k)
            if fld is None:
                unknown_keys.add(str(k))
                continue
            if fld in values and values[fld] not in (None, ""):
                continue  # eyni sahə iki adla gəlibsə birincini saxla
            if isinstance(v, (dict, list)):
                v = json.dumps(v, ensure_ascii=False)
            values[fld] = v
            seen_fields.add(fld)
        if not any(clean_text(v) for v in values.values()):
            continue  # tam boş obyekt
        result.rows.append((i, values))

    if unknown_keys:
        result.notes.append({
            "code": "unknown_columns",
            "message": "Bu sahələr tanınmadı və nəzərə alınmadı: " + ", ".join(sorted(unknown_keys)[:20]),
        })
    if not result.rows:
        raise ImportFileError("JSON faylında müştəri yoxdur.")
    _check_required_columns(seen_fields)
    return result


def _split_coords(v):
    if isinstance(v, dict):
        lat = v.get("lat", v.get("latitude"))
        lng = v.get("lng", v.get("lon", v.get("longitude")))
        return lat, lng
    if isinstance(v, (list, tuple)) and len(v) == 2:
        return v[0], v[1]
    if isinstance(v, str) and "," in v and v.count(",") == 1:
        a, b = v.split(",")
        return a.strip(), b.strip()
    return None, None


def parse_file(filename, content):
    if not content:
        raise ImportFileError("Fayl boşdur.")
    if len(content) > MAX_FILE_SIZE:
        raise ImportFileError("Fayl çox böyükdür (maksimum 10 MB). Faylı hissələrə bölüb yükləyin.")
    source = detect_source(filename, content[:8])
    parsed = parse_excel(content) if source == "excel" else parse_json(content)
    return source, parsed
