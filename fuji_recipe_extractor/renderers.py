from __future__ import annotations

from collections import defaultdict

from .models import PhotoRecipe


def render_photo_markdown(photo: PhotoRecipe) -> str:
    return "\n".join(
        [
            "---",
            f"film: {photo.film}",
            f"dr: {photo.dynamic_range}",
            "---",
            "",
            f"# {photo.title}",
            "",
            f"![[{photo.source_file_name}]]",
            "",
            f"- Film Simulation: {photo.film}",
            f"- Dynamic Range: {photo.dynamic_range}",
            f"- Highlight: {photo.highlight}",
            f"- Shadow: {photo.shadow}",
            f"- Color: {photo.color}",
            f"- Noise Reduction: {photo.noise_reduction}",
            f"- Sharpness: {photo.sharpness}",
            f"- Clarity: {photo.clarity}",
            f"- Grain Effect: {photo.grain_effect}",
            f"- Color Chrome Effect: {photo.color_chrome_effect}",
            f"- Color Chrome Effect Blue: {photo.color_chrome_fx_blue}",
            f"- White Balance: {photo.white_balance}",
            f"- ISO: {photo.iso}",
            f"- Exposure Compensation: {photo.exposure_compensation}",
        ]
    )


def render_film_index(photos: list[PhotoRecipe]) -> str:
    groups: dict[str, list[PhotoRecipe]] = defaultdict(list)
    for photo in photos:
        groups[photo.film].append(photo)

    lines = ["# Film Simulations", ""]
    for film in sorted(groups):
        lines.append(f"## {film}")
        lines.append("")
        for photo in sorted(groups[film], key=lambda item: item.title):
            lines.append(f"- [{photo.title}](../notes/{photo.title}.md)")
        lines.append("")
    return "\n".join(lines).rstrip()


def render_recipe_index(photos: list[PhotoRecipe]) -> str:
    groups: dict[str, list[PhotoRecipe]] = defaultdict(list)
    for photo in photos:
        groups[photo.recipe_key].append(photo)

    lines = ["# Recipes", ""]
    for recipe_key in sorted(groups):
        lines.append(f"## {recipe_key}")
        lines.append("")
        for photo in sorted(groups[recipe_key], key=lambda item: item.title):
            lines.append(f"- [{photo.title}](../notes/{photo.title}.md) | {photo.film} | {photo.dynamic_range}")
        lines.append("")
    return "\n".join(lines).rstrip()
