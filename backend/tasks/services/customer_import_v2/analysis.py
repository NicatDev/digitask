"""
Sətirlərin yoxlanması və təsnifatı: yeni / artıq mövcud / faylda təkrar / problemli.

Bu modul bazaya YAZMIR. Bazadakı müştərilər (ExistingIndex) və region/avadanlıq siyahıları
(RefCatalog) kənardan verilir — eyni məntiq həm önbaxışda, həm yaratma anında işləyir.
"""
from collections import defaultdict

from .normalize import (
    NumberProblem,
    best_match,
    clean_text,
    clean_value,
    display_number,
    in_azerbaijan,
    is_junk,
    normalize_name,
    number_key,
    parse_coordinate,
    split_numbers,
)

NEW = "new"
CREATED = "created"
EXISTING = "existing"
DUPLICATE_IN_FILE = "duplicate_in_file"
PROBLEM = "problem"

MAX_LEN = {"full_name": 200, "register_number": 60, "phone_number": 200, "address": 255}
REF_LABELS = {"region": "Region", "equipment": "Avadanlıq", "optic_box": "Optik qutu"}
REF_MAX_LEN = {"region": 120, "equipment": 200, "optic_box": 200}
# Yeni yaradılacaq adın minimum uzunluğu (mövcud adla dəqiq uyğunluq üçün tətbiq olunmur)
REF_MIN_NEW_LEN = {"region": 3, "equipment": 2, "optic_box": 2}
REF_GENITIVE = {"region": "regionun", "equipment": "avadanlığın", "optic_box": "optik qutunun"}
FIELD_LABELS_AZ = {"register_number": "qeydiyyat nömrəsi", "phone_number": "telefon"}


def _q(v):
    return f"«{clean_text(v)[:80]}»"


# ---------------------------------------------------------------------------
# Bazadakı müştərilərin nömrə indeksi
# ---------------------------------------------------------------------------

class ExistingIndex:
    """Nömrə açarı → [(customer_id, sahə)] və ad → [customer_id]."""

    def __init__(self):
        self.by_key = defaultdict(list)
        self.by_name = defaultdict(list)

    def add_customer(self, cid, register_number, phone_number, full_name=""):
        for fld, value in (("register_number", register_number), ("phone_number", phone_number)):
            for part in split_numbers(value):
                try:
                    key = number_key(part)
                except NumberProblem:
                    continue
                if key:
                    self.by_key[key].append((cid, fld))
        name = normalize_name(full_name)
        if name:
            self.by_name[name].append(cid)

    def add_keys(self, cid, keyed):
        """keyed: [(key, field)] — yaratma zamanı yeni müştərini indeksə əlavə etmək üçün."""
        for key, fld in keyed:
            self.by_key[key].append((cid, fld))

    def lookup(self, keyed):
        """keyed: [(key, incoming_field)] → {cid: [{incoming_field, existing_field, key}]}"""
        hits = defaultdict(list)
        for key, in_fld in keyed:
            for cid, ex_fld in self.by_key.get(key, ()):
                hits[cid].append({"incoming_field": in_fld, "existing_field": ex_fld, "key": key})
        return dict(hits)


# ---------------------------------------------------------------------------
# Region / avadanlıq / optik qutu kataloqu
# ---------------------------------------------------------------------------

class RefCatalog:
    """
    Ad → mövcud obyekt (60%-dən çox oxşarlıq) və ya "yaradılacaq".
    items: [{"id", "name", "is_active"}]
    """

    def __init__(self, kind, items):
        self.kind = kind
        self.candidates = [(normalize_name(it["name"]), dict(it, planned=False)) for it in items]
        self.candidates = [(n, it) for n, it in self.candidates if n]

    def resolve(self, raw):
        """
        Qaytarır: (decision | None, reason | None, warning | None)
        decision = {"input", "action": "match"|"create", "id", "name", "score"}
        """
        label = REF_LABELS[self.kind]
        text = clean_value(raw)
        if not text:
            return None, None, None
        if len(text) > REF_MAX_LEN[self.kind]:
            return None, (f"{self.kind}_too_long", f"{label} adı çox uzundur (maksimum {REF_MAX_LEN[self.kind]} simvol)."), None
        if not normalize_name(text):
            return None, (f"{self.kind}_invalid", f"{label} adı düzgün deyil: {_q(text)}."), None

        obj, score, ambiguous = best_match(text, self.candidates)
        if ambiguous:
            names = ", ".join(_q(a["name"]) for a in ambiguous[:5])
            return None, (
                f"{self.kind}_ambiguous",
                f"{label} {_q(text)} bir neçə mövcud ada eyni dərəcədə oxşayır: {names}. Dəqiq adı yazın.",
            ), None
        if obj is not None:
            if not obj.get("planned") and not obj.get("is_active", True):
                return None, (
                    f"{self.kind}_inactive",
                    f"{label} {_q(obj['name'])} sistemdə deaktiv edilib. Başqa ad yazın və ya onu aktivləşdirin.",
                ), None
            decision = {
                "input": text,
                "action": "create" if obj.get("planned") else "match",
                "id": obj.get("id"),
                "name": obj["name"],
                "score": round(score, 3),
            }
            warning = None
            if score < 1.0:
                warning = (
                    f"{self.kind}_similar",
                    f"{label} {_q(text)} → {_q(obj['name'])} kimi tanındı (oxşarlıq {round(score * 100)}%).",
                )
            elif decision["action"] == "create":
                warning = (f"{self.kind}_create", f"Yeni {label.lower()} yaradılacaq: {_q(obj['name'])}.")
            return decision, None, warning

        # Tapılmadı. Çox qısa və ya yalnız rəqəmdən ibarət ad səhv yazılış ola bilər ("s", "12") —
        # belə adla yeni region/avadanlıq yaratmaq risklidir.
        compact = normalize_name(text).replace(" ", "")
        min_len = REF_MIN_NEW_LEN[self.kind]
        if len(compact) < min_len or compact.isdigit():
            why = "yalnız rəqəmdən ibarətdir" if compact.isdigit() else f"çox qısadır (ən azı {min_len} hərf)"
            return None, (
                f"{self.kind}_too_short",
                f"{label} {_q(text)} sistemdə tapılmadı, yeni ad kimi də {why}. "
                f"Səhv yazılıb ola bilər — {REF_GENITIVE[self.kind]} tam adını yazın.",
            ), None

        # Yeni yaradılacaq (sonrakı sətirlər də bunu tapsın deyə kataloqa əlavə olunur)
        planned = {"id": None, "name": text, "is_active": True, "planned": True}
        self.candidates.append((normalize_name(text), planned))
        decision = {"input": text, "action": "create", "id": None, "name": text, "score": 0}
        return decision, None, (f"{self.kind}_create", f"Yeni {label.lower()} yaradılacaq: {_q(text)}.")


# ---------------------------------------------------------------------------
# Bir sətrin yoxlanması
# ---------------------------------------------------------------------------

def _numbers(raw_value, field_name, reasons, single=False):
    """Xanadakı nömrə(lər) → ([(key, field)], saxlanılacaq dəyər)."""
    label = FIELD_LABELS_AZ[field_name]
    text = clean_text(raw_value)
    if not text or is_junk(text):
        return [], ""
    parts = split_numbers(text)
    if not parts:
        return [], ""
    if single and len(parts) > 1:
        reasons.append((f"{field_name}_multiple",
                        f"Qeydiyyat nömrəsi xanasında bir neçə nömrə var: {_q(text)}. Bir müştəri üçün bir qeydiyyat nömrəsi olmalıdır."))
        return [], ""
    keyed, shown = [], []
    for part in parts:
        try:
            key = number_key(part)
        except NumberProblem:
            reasons.append((f"{field_name}_corrupt",
                            f"{label.capitalize()} korlanıb: {_q(part)}. Excel uzun nömrəni yuvarlaqlaşdırıb — düzgün nömrəni yazın."))
            continue
        if not key:
            reasons.append((f"{field_name}_invalid", f"{label.capitalize()} düzgün deyil: {_q(part)}."))
            continue
        if (key, field_name) not in keyed:
            keyed.append((key, field_name))
            shown.append(display_number(key, part))
    value = ", ".join(shown)
    if len(value) > MAX_LEN[field_name]:
        reasons.append((f"{field_name}_too_long", f"{label.capitalize()} çox uzundur."))
    return keyed, value


def _coords(raw_lat, raw_lng, reasons):
    try:
        lat = parse_coordinate(raw_lat)
    except ValueError:
        reasons.append(("coords_invalid", f"Enlik rəqəm deyil: {_q(raw_lat)}."))
        return None, None
    try:
        lng = parse_coordinate(raw_lng)
    except ValueError:
        reasons.append(("coords_invalid", f"Uzunluq rəqəm deyil: {_q(raw_lng)}."))
        return None, None
    if lat is None and lng is None:
        return None, None
    if lat is None or lng is None:
        which = "uzunluq (lng)" if lng is None else "enlik (lat)"
        reasons.append(("coords_partial",
                        f"Koordinatın yarısı yazılıb: {which} boşdur. Ya ikisini də yazın, ya da ikisini də boş saxlayın."))
        return None, None
    shown = f"enlik {lat}, uzunluq {lng}"
    if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
        reasons.append(("coords_out_of_range",
                        f"Koordinat mümkün olmayan dəyərdədir ({shown}). Enlik −90…90, uzunluq −180…180 arası olmalıdır."))
        return None, None
    if not in_azerbaijan(lat, lng):
        if in_azerbaijan(lng, lat):
            reasons.append(("coords_swapped",
                            f"Enlik və uzunluq yerləri dəyişik yazılıb ({shown}). "
                            f"Düzgünü: enlik {lng}, uzunluq {lat}."))
        else:
            reasons.append(("coords_outside_az",
                            f"Koordinat Azərbaycandan kənardadır ({shown}). Azərbaycanda enlik təxminən 38–42, "
                            "uzunluq 44–51 arasında olur. Koordinatı yoxlayın və ya boş saxlayın."))
        return None, None
    return round(lat, 7), round(lng, 7)


def analyze_row(raw, catalogs):
    """
    Qaytarır: dict(data, keyed, reasons, warnings)
    keyed: [(key, field)] — dublikat yoxlaması üçün.
    """
    reasons, warnings = [], []

    if raw.get("__invalid__"):
        return {
            "data": {}, "keyed": [], "warnings": [],
            "reasons": [("invalid_object", "Bu element müştəri məlumatı deyil (obyekt olmalıdır).")],
        }

    full_name = clean_value(raw.get("full_name"))
    if not full_name:
        reasons.append(("name_required", "Ad Soyad yazılmayıb."))
    elif len(full_name) > MAX_LEN["full_name"]:
        reasons.append(("name_too_long", "Ad Soyad çox uzundur (maksimum 200 simvol)."))

    reg_keyed, register_number = _numbers(raw.get("register_number"), "register_number", reasons, single=True)
    phone_keyed, phone_number = _numbers(raw.get("phone_number"), "phone_number", reasons)
    keyed = reg_keyed + phone_keyed
    has_corrupt = any(code.endswith(("_corrupt", "_invalid", "_multiple")) for code, _ in reasons
                      if code.startswith(("register", "phone")))
    if not keyed and not has_corrupt:
        reasons.append(("no_identifier",
                        "Qeydiyyat nömrəsi də, telefon da yoxdur. Müştərinin sistemdə olub-olmadığını yoxlamaq üçün ən azı biri lazımdır."))

    refs = {}
    for kind in ("region", "equipment", "optic_box"):
        decision, reason, warning = catalogs[kind].resolve(raw.get(kind))
        if reason:
            reasons.append(reason)
        if warning:
            warnings.append(warning)
        refs[kind] = decision
    if refs["region"] is None and not any(c.startswith("region_") for c, _ in reasons):
        reasons.append(("region_required", "Region yazılmayıb."))

    address = clean_value(raw.get("address"))
    if len(address) > MAX_LEN["address"]:
        reasons.append(("address_too_long", "Ünvan çox uzundur (maksimum 255 simvol)."))

    lat, lng = _coords(raw.get("lat"), raw.get("lng"), reasons)

    data = {
        "full_name": full_name,
        "register_number": register_number,
        "phone_number": phone_number,
        "region": refs["region"],
        "equipment": refs["equipment"],
        "optic_box": refs["optic_box"],
        "address": address,
        "lat": lat,
        "lng": lng,
    }
    return {"data": data, "keyed": keyed, "reasons": reasons, "warnings": warnings}


def _signature(data, keyed):
    def ref(r):
        return normalize_name(r["name"]) if r else ""
    return (
        normalize_name(data.get("full_name")),
        tuple(sorted(k for k, _ in keyed)),
        ref(data.get("region")), ref(data.get("equipment")), ref(data.get("optic_box")),
        clean_text(data.get("address")).lower(),
        data.get("lat"), data.get("lng"),
    )


def _msg(code, message):
    return {"code": code, "message": message}


# ---------------------------------------------------------------------------
# Bütün faylın təsnifatı
# ---------------------------------------------------------------------------

def analyze_rows(rows, index, catalogs, progress=None):
    """
    rows: [(row_number, raw_dict)]
    Qaytarır: [outcome] — hər biri:
      row_number, raw, data, keys, keyed, result, reasons, warnings, matches, duplicate_of_row
    """
    outcomes = []
    for i, (row_number, raw) in enumerate(rows, start=1):
        r = analyze_row(raw, catalogs)
        outcome = {
            "row_number": row_number,
            "raw": raw,
            "data": r["data"],
            "keyed": r["keyed"],
            "keys": sorted({k for k, _ in r["keyed"]}),
            "reasons": [_msg(c, m) for c, m in r["reasons"]],
            "warnings": [_msg(c, m) for c, m in r["warnings"]],
            "matches": [],
            "duplicate_of_row": None,
        }
        hits = index.lookup(r["keyed"]) if r["keyed"] else {}
        if hits:
            # Nömrə sistemdə var → mövcud sayılır (digər problemlər əhəmiyyətsizdir, yaradılmayacaq)
            outcome["result"] = EXISTING
            outcome["matches"] = [{"customer_id": cid, "matched_on": on} for cid, on in hits.items()]
            outcome["reasons"] = [_msg("exists", "Bu müştəri sistemdə artıq var (nömrə üst-üstə düşür).")]
        elif outcome["reasons"]:
            outcome["result"] = PROBLEM
        else:
            outcome["result"] = NEW
        outcomes.append(outcome)
        if progress and i % 500 == 0:
            progress(i)

    _resolve_in_file_duplicates(outcomes)
    _add_name_warnings(outcomes, index)
    return outcomes


def _resolve_in_file_duplicates(outcomes):
    """Faylın daxilində eyni nömrəli sətirlər (union-find nömrə açarlarına görə)."""
    parent = list(range(len(outcomes)))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    owner = {}
    for i, o in enumerate(outcomes):
        for key in o["keys"]:
            if key in owner:
                ra, rb = find(owner[key]), find(i)
                if ra != rb:
                    parent[rb] = ra
            else:
                owner[key] = i

    groups = defaultdict(list)
    for i, o in enumerate(outcomes):
        if o["keys"]:
            groups[find(i)].append(i)

    for members in groups.values():
        if len(members) < 2:
            continue
        members.sort(key=lambda i: outcomes[i]["row_number"])
        rows_txt = ", ".join(str(outcomes[i]["row_number"]) for i in members)
        existing = [i for i in members if outcomes[i]["result"] == EXISTING]
        if existing:
            ref_row = outcomes[existing[0]]["row_number"]
            for i in members:
                o = outcomes[i]
                if o["result"] == EXISTING:
                    continue
                o["result"] = PROBLEM
                o["reasons"].append(_msg(
                    "linked_to_existing",
                    f"Bu sətrin nömrəsi faylın {ref_row}-ci sətri ilə eynidir, o müştəri isə sistemdə artıq var.",
                ))
            continue

        candidates = [i for i in members if outcomes[i]["result"] == NEW]
        problems = [i for i in members if outcomes[i]["result"] == PROBLEM]
        if problems and candidates:
            # Qrupun bir hissəsi problemlidirsə, digərlərini də yaratmaq risklidir
            for i in candidates:
                outcomes[i]["result"] = PROBLEM
                outcomes[i]["reasons"].append(_msg(
                    "file_conflict",
                    f"Faylda eyni nömrə bir neçə sətirdə var (sətirlər: {rows_txt}) və onlardan bəziləri problemlidir. "
                    "Əvvəlcə həmin sətirləri düzəldin.",
                ))
            continue
        if len(candidates) < 2:
            continue
        sigs = {_signature(outcomes[i]["data"], outcomes[i]["keyed"]) for i in candidates}
        if len(sigs) == 1:
            first = outcomes[candidates[0]]
            for i in candidates[1:]:
                o = outcomes[i]
                o["result"] = DUPLICATE_IN_FILE
                o["duplicate_of_row"] = first["row_number"]
                o["reasons"] = [_msg(
                    "duplicate_in_file",
                    f"Faylın {first['row_number']}-ci sətri ilə tam eynidir — müştəri bir dəfə yaradılacaq.",
                )]
        else:
            key_count = defaultdict(int)
            for i in candidates:
                for k in outcomes[i]["keys"]:
                    key_count[k] += 1
            shared = [display_number(k, k[2:]) for k, c in sorted(key_count.items()) if c > 1]
            shared_txt = ", ".join(shared[:3]) or "nömrə"
            for i in candidates:
                o = outcomes[i]
                o["result"] = PROBLEM
                o["reasons"].append(_msg(
                    "file_conflict",
                    f"{shared_txt} nömrəsi faylda fərqli məlumatlı bir neçə sətirdə var (sətirlər: {rows_txt}). "
                    "Eyni nömrə eyni müştəri sayıldığı üçün hansının yaradılacağı bilinmir. "
                    "Bunlar fərqli adamlardırsa (məs. ailə üzvləri eyni telefonla), onları əl ilə əlavə edin; "
                    "eyni adamdırsa, faylda bir sətirə endirin.",
                ))


def _add_name_warnings(outcomes, index):
    by_name_in_file = defaultdict(list)
    for o in outcomes:
        if o["result"] == NEW:
            name = normalize_name(o["data"].get("full_name"))
            if name:
                by_name_in_file[name].append(o)
    for name, items in by_name_in_file.items():
        existing_ids = index.by_name.get(name, [])
        for o in items:
            if existing_ids:
                o["warnings"].append(_msg(
                    "same_name_existing",
                    "Sistemdə eyni adlı müştəri var (amma nömrəsi fərqlidir). Yaradılacaq — eyni adam olub-olmadığını yoxlayın.",
                ))
                o["matches"] = [{"customer_id": cid, "matched_on": [], "same_name": True} for cid in existing_ids[:3]]
            if len(items) > 1:
                others = ", ".join(str(x["row_number"]) for x in items if x is not o)
                o["warnings"].append(_msg(
                    "same_name_in_file",
                    f"Faylda eyni adlı başqa sətir də var (sətirlər: {others}), nömrələri fərqlidir.",
                ))
