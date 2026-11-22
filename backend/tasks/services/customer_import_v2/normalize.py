"""
Müştəri importu üçün mətn, nömrə və ad normallaşdırması.

Bu modul heç bir bazaya toxunmur — yalnız saf funksiyalardır (test etmək asandır).
"""
import math
import re
import unicodedata
from decimal import Decimal, InvalidOperation
from difflib import SequenceMatcher

# Boş sayılan "zibil" dəyərlər (kiçik hərflə müqayisə olunur)
JUNK_VALUES = {
    "", "null", "none", "nil", "nan", "n/a", "na", "-", "--", "---", "_", ".", "0",
    "undefined", "yoxdur", "yox", "bos", "boş", "#n/a", "#value!", "#ref!", "#name?",
}

# Görünməz / qəribə boşluq simvolları
_INVISIBLE = dict.fromkeys(map(ord, "​‌‍⁠﻿­"), None)
_SPACE_LIKE = re.compile(r"[   -   　\t\r\n]+")
_MULTI_SPACE = re.compile(r" {2,}")

# Bir xanada bir neçə nömrə ayırıcıları
_NUMBER_SPLIT = re.compile(r"[,;/|\\\n]+|\s+və\s+|\s+ve\s+|\s+or\s+", re.IGNORECASE)
_SCIENTIFIC = re.compile(r"^\s*\d+(?:[.,]\d+)?\s*e\s*\+?\s*\d+\s*$", re.IGNORECASE)

AZ_TRANSLIT = str.maketrans({
    "ə": "e", "ü": "u", "ö": "o", "ğ": "g", "ş": "s", "ç": "c", "ı": "i",
    "Ə": "e", "Ü": "u", "Ö": "o", "Ğ": "g", "Ş": "s", "Ç": "c", "İ": "i", "I": "i",
})


def clean_text(value):
    """İstənilən xana dəyərini təmiz mətnə çevirir (None → '')."""
    if value is None:
        return ""
    if isinstance(value, bool):
        return ""
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if math.isnan(value) or math.isinf(value):
            return ""
        if value.is_integer():
            return str(int(value))
        return repr(value)
    if isinstance(value, Decimal):
        if value == value.to_integral_value():
            return str(int(value))
        return str(value)
    text = str(value)
    text = unicodedata.normalize("NFC", text).translate(_INVISIBLE)
    text = _SPACE_LIKE.sub(" ", text)
    text = _MULTI_SPACE.sub(" ", text)
    return text.strip()


def is_junk(text):
    t = (text or "").strip().lower()
    if t in JUNK_VALUES:
        return True
    # Yalnız durğu işarələri / sıfırlar
    return bool(t) and all(ch in "-_./0 " for ch in t)


def clean_value(value):
    """Təmiz mətn; zibil dəyər isə ''."""
    text = clean_text(value)
    return "" if is_junk(text) else text


# ---------------------------------------------------------------------------
# Nömrələr
# ---------------------------------------------------------------------------

class NumberProblem(Exception):
    """Nömrə korlanıb (məs. Excel 9.94E+11) — bərpa olunmur."""


def _canonical_digits(digits):
    """994XXXXXXXXX / 0XXXXXXXXX / XXXXXXXXX → XXXXXXXXX (Azərbaycan formatı)."""
    if digits.startswith("00994") and len(digits) == 14:
        digits = digits[5:]
    elif digits.startswith("994") and len(digits) == 12:
        digits = digits[3:]
    elif digits.startswith("0") and len(digits) == 10:
        digits = digits[1:]
    return digits


def number_key(text):
    """
    Bir nömrə üçün müqayisə açarı.
      - rəqəmli: 'N:554264644' (+994, 0, boşluq, tire fərq etmir)
      - hərf də varsa (məs. '99999Y'): 'R:99999Y'
      - zibil / çox qısa: None
    Korlanmış (9.94E+11) üçün NumberProblem atır.
    """
    text = clean_text(text)
    if not text or is_junk(text):
        return None
    if _SCIENTIFIC.match(text):
        raise NumberProblem(text)
    compact = re.sub(r"[\s\-().+]", "", text)
    if not compact:
        return None
    if compact.isdigit():
        digits = _canonical_digits(compact)
        if len(digits) < 5 or len(set(digits)) == 1:
            return None
        return "N:" + digits
    if re.search(r"[A-Za-zƏəÜüÖöĞğŞşÇçIıİ]", compact):
        return "R:" + compact.upper()
    # Qarışıq simvollar — yalnız rəqəmləri götür
    digits = re.sub(r"\D", "", compact)
    if len(digits) < 5:
        return None
    return "N:" + _canonical_digits(digits)


def split_numbers(text):
    """Bir xanadakı bir neçə nömrəni ayırır."""
    text = clean_text(text)
    if not text:
        return []
    parts = [p.strip() for p in _NUMBER_SPLIT.split(text)]
    return [p for p in parts if p and not is_junk(p)]


def display_number(key, original):
    """Saxlanılacaq forma: 9 rəqəmli mobil → 0XXXXXXXXX; digərləri təmizlənmiş orijinal."""
    if key and key.startswith("N:"):
        digits = key[2:]
        if len(digits) == 9:
            return "0" + digits
        return digits
    return clean_text(original)


# ---------------------------------------------------------------------------
# Adlar (region / avadanlıq / optik qutu) və bənzərlik
# ---------------------------------------------------------------------------

def normalize_name(value):
    text = clean_text(value).lower().translate(AZ_TRANSLIT)
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def _compact(name):
    return name.replace(" ", "")


def _digit_groups(name):
    return re.findall(r"\d+", name)


SIMILARITY_THRESHOLD = 0.60  # 60%-dən çox


def name_similarity(a, b):
    """
    0..1 arası bənzərlik (a, b artıq normalize_name-dən keçib).
      - eyni → 1.0
      - içində olma: qısa / uzun uzunluq nisbəti
      - hərflərə görə oxşarlıq (SequenceMatcher)
    İçində rəqəm olan adlarda rəqəmlər fərqlidirsə (DGI95SW021 / DGI95SW022) → 0:
    fərqli nömrəli avadanlıqlar/regionlar heç vaxt "oxşar" sayılmır.
    """
    if not a or not b:
        return 0.0
    if a == b:
        return 1.0
    ca, cb = _compact(a), _compact(b)
    if ca == cb:
        return 1.0
    da, db = _digit_groups(a), _digit_groups(b)
    if (da or db) and da != db:
        return 0.0
    score = _raw_similarity(ca, cb)

    # Ortaq sözlər balı şişirtməsin: "PBR Internet Equipment" ≠ "Office Internet Equipment".
    # Hər iki adda ortaq sözlərdən başqa söz qalırsa, həmin fərqləndirici hissələr də oxşar olmalıdır.
    ta, tb = set(a.split()), set(b.split())
    shared = ta & tb
    rest_a, rest_b = ta - shared, tb - shared
    if shared and rest_a and rest_b:
        rest_score = _raw_similarity("".join(sorted(rest_a)), "".join(sorted(rest_b)))
        score = min(score, rest_score)
    return score


def _raw_similarity(ca, cb):
    """Hərflərə görə oxşarlıq + içində olma (qısa/uzun nisbəti)."""
    score = SequenceMatcher(None, ca, cb).ratio()
    short, long_ = (ca, cb) if len(ca) <= len(cb) else (cb, ca)
    if short and short in long_:
        score = max(score, len(short) / len(long_))
    return score


def best_match(raw_name, candidates):
    """
    candidates: [(normalized_name, obj)]
    Qaytarır: (obj, score, ambiguous_objs)
      - obj None → 60%-i keçən uyğunluq yoxdur
      - ambiguous_objs: eyni (ən yüksək) balla bir neçə fərqli namizəd
    """
    key = normalize_name(raw_name)
    if not key:
        return None, 0.0, []
    scored = []
    for norm, obj in candidates:
        s = name_similarity(key, norm)
        if s > SIMILARITY_THRESHOLD:
            scored.append((s, obj))
    if not scored:
        return None, 0.0, []
    scored.sort(key=lambda x: x[0], reverse=True)
    top_score = scored[0][0]
    top = [obj for s, obj in scored if abs(s - top_score) < 1e-9]
    if len(top) > 1:
        return None, top_score, top
    return scored[0][1], top_score, []


# ---------------------------------------------------------------------------
# Koordinatlar
# ---------------------------------------------------------------------------

# Azərbaycanın təxmini sərhədləri (Naxçıvan daxil)
AZ_LAT = (38.3, 41.95)
AZ_LNG = (44.7, 50.9)


def parse_coordinate(value):
    """'40,4093' / 40.4093 / '40.4093°' → float; boşdursa None; səhvdirsə ValueError."""
    if value is None:
        return None
    if isinstance(value, (int, float, Decimal)) and not isinstance(value, bool):
        f = float(value)
        if math.isnan(f) or math.isinf(f):
            raise ValueError(value)
        return f
    text = clean_text(value)
    if not text or is_junk(text):
        return None
    text = text.replace("°", "").replace(" ", "")
    if text.count(",") == 1 and "." not in text:
        text = text.replace(",", ".")
    try:
        f = float(Decimal(text))
    except (InvalidOperation, ValueError):
        raise ValueError(value)
    if math.isnan(f) or math.isinf(f):
        raise ValueError(value)
    return f


def in_azerbaijan(lat, lng):
    return AZ_LAT[0] <= lat <= AZ_LAT[1] and AZ_LNG[0] <= lng <= AZ_LNG[1]
