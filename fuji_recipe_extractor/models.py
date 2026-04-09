from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re


UNKNOWN = "Unknown"


@dataclass(frozen=True)
class ExifRecord:
    source_file: str | None = None
    film_mode: str | None = None
    dynamic_range: str | None = None
    development_dynamic_range: str | None = None
    highlight_tone: str | None = None
    shadow_tone: str | None = None
    saturation: str | None = None
    noise_reduction: str | None = None
    sharpness: str | None = None
    clarity: str | None = None
    grain_effect_roughness: str | None = None
    grain_effect_size: str | None = None
    color_chrome_effect: str | None = None
    color_chrome_fx_blue: str | None = None
    white_balance: str | None = None
    white_balance_fine_tune: str | None = None
    iso: str | None = None
    exposure_compensation: str | None = None

    @classmethod
    def from_exiftool_json(cls, payload: dict[str, object]) -> "ExifRecord":
        def get_value(key: str) -> str | None:
            value = payload.get(key)
            if value is None:
                return None
            return str(value)

        return cls(
            source_file=get_value("SourceFile"),
            film_mode=get_value("FilmMode"),
            dynamic_range=get_value("DynamicRange"),
            development_dynamic_range=get_value("DevelopmentDynamicRange"),
            highlight_tone=get_value("HighlightTone"),
            shadow_tone=get_value("ShadowTone"),
            saturation=get_value("Saturation"),
            noise_reduction=get_value("NoiseReduction"),
            sharpness=get_value("Sharpness"),
            clarity=get_value("Clarity"),
            grain_effect_roughness=get_value("GrainEffectRoughness"),
            grain_effect_size=get_value("GrainEffectSize"),
            color_chrome_effect=get_value("ColorChromeEffect"),
            color_chrome_fx_blue=get_value("ColorChromeFXBlue"),
            white_balance=get_value("WhiteBalance"),
            white_balance_fine_tune=get_value("WhiteBalanceFineTune"),
            iso=get_value("ISO"),
            exposure_compensation=get_value("ExposureCompensation"),
        )


@dataclass(frozen=True)
class PhotoRecipe:
    source_file_name: str
    source_path: str
    title: str
    film: str
    dynamic_range: str
    highlight: str
    shadow: str
    color: str
    noise_reduction: str
    sharpness: str
    clarity: str
    grain_effect: str
    color_chrome_effect: str
    color_chrome_fx_blue: str
    white_balance: str
    iso: str
    exposure_compensation: str

    @property
    def recipe_key(self) -> str:
        return f"{_normalize_token(self.film)}_{_normalize_token(self.dynamic_range)}"

    @property
    def film_key(self) -> str:
        return _normalize_token(self.film)


def build_photo_recipe(record: ExifRecord) -> PhotoRecipe:
    source_path = record.source_file or UNKNOWN
    path = Path(source_path) if source_path != UNKNOWN else None
    source_name = path.name if path else UNKNOWN
    title = path.stem if path else UNKNOWN

    return PhotoRecipe(
        source_file_name=source_name,
        source_path=source_path,
        title=title,
        film=_or_unknown(record.film_mode),
        dynamic_range=_normalize_dynamic_range(record.dynamic_range, record.development_dynamic_range),
        highlight=_normalize_tone(record.highlight_tone),
        shadow=_normalize_tone(record.shadow_tone),
        color=_normalize_tone(record.saturation),
        noise_reduction=_normalize_tone(record.noise_reduction),
        sharpness=_normalize_tone(record.sharpness),
        clarity=_normalize_tone(record.clarity),
        grain_effect=_normalize_grain_effect(record.grain_effect_roughness, record.grain_effect_size),
        color_chrome_effect=_normalize_simple(record.color_chrome_effect),
        color_chrome_fx_blue=_normalize_simple(record.color_chrome_fx_blue),
        white_balance=_normalize_white_balance(record.white_balance, record.white_balance_fine_tune),
        iso=_normalize_simple(record.iso),
        exposure_compensation=_normalize_simple(record.exposure_compensation),
    )


def _or_unknown(value: str | None) -> str:
    if value is None:
        return UNKNOWN
    stripped = value.strip()
    return stripped or UNKNOWN


def _normalize_dynamic_range(dynamic_range: str | None, development_dynamic_range: str | None) -> str:
    value = _or_unknown(dynamic_range)
    if value.upper().startswith("DR"):
        return value.upper()

    mapping = {
        "100": "DR100",
        "200": "DR200",
        "400": "DR400",
    }
    if development_dynamic_range is not None:
        mapped = mapping.get(development_dynamic_range.strip())
        if mapped:
            return mapped
    return value


def _normalize_tone(value: str | None) -> str:
    normalized = _or_unknown(value)
    lowered = normalized.lower()
    if "(normal)" in lowered:
        return "0"
    if "(hard)" in lowered or "(soft)" in lowered:
        return normalized.split(" ", 1)[0]
    return normalized


def _normalize_grain_effect(roughness: str | None, size: str | None) -> str:
    roughness_value = _or_unknown(roughness)
    size_value = _or_unknown(size)
    if roughness_value.lower() == "off" or size_value.lower() == "off":
        return "Off"
    if roughness_value == UNKNOWN and size_value == UNKNOWN:
        return UNKNOWN

    parts = [part for part in (roughness_value, size_value) if part != UNKNOWN]
    return ", ".join(parts) if parts else UNKNOWN


def _normalize_white_balance(white_balance: str | None, fine_tune: str | None) -> str:
    wb = _normalize_simple(white_balance)
    if wb == UNKNOWN:
        return UNKNOWN

    fine = _or_unknown(fine_tune)
    if fine == UNKNOWN:
        return wb

    normalized = fine.replace("Red", "R").replace("Blue", "B").replace(",", "")
    normalized = re.sub(r"\s+", " ", normalized).strip()
    normalized = re.sub(r"([RB])\s*([+-]\d+)", r"\1\2", normalized)
    return f"{wb} ({normalized})"


def _normalize_simple(value: str | None) -> str:
    return _or_unknown(value)


def _normalize_token(value: str) -> str:
    collapsed = re.sub(r"[^A-Za-z0-9]+", "", value)
    return collapsed or UNKNOWN
