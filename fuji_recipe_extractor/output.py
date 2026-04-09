from __future__ import annotations

from pathlib import Path
import shutil

from .models import PhotoRecipe
from .renderers import render_film_index, render_photo_markdown, render_recipe_index


class OutputWriter:
    def write(
        self,
        photos: list[PhotoRecipe],
        output_dir: Path,
        copy_by: str | None,
        dry_run: bool,
        verbose: bool,
    ) -> None:
        notes_dir = output_dir / "notes"
        images_dir = output_dir / "images"
        recipes_dir = output_dir / "recipes"
        indexes_dir = output_dir / "indexes"

        if not dry_run:
            for directory in (output_dir, notes_dir, images_dir, recipes_dir, indexes_dir):
                directory.mkdir(parents=True, exist_ok=True)

        for photo in photos:
            source = Path(photo.source_path)
            note_path = notes_dir / f"{photo.title}.md"
            image_copy_path = images_dir / photo.source_file_name

            self._write_text(note_path, render_photo_markdown(photo), dry_run, verbose)
            self._copy_file(source, image_copy_path, dry_run, verbose)

            if copy_by == "recipe":
                self._copy_file(source, recipes_dir / photo.recipe_key / photo.source_file_name, dry_run, verbose)
            elif copy_by == "film":
                self._copy_file(source, recipes_dir / photo.film_key / photo.source_file_name, dry_run, verbose)

        self._write_text(indexes_dir / "film.md", render_film_index(photos), dry_run, verbose)
        self._write_text(indexes_dir / "recipes.md", render_recipe_index(photos), dry_run, verbose)

    def _write_text(self, path: Path, content: str, dry_run: bool, verbose: bool) -> None:
        if dry_run:
            self._log(f"[dry-run] write {path}", verbose)
            return

        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        self._log(f"Wrote {path}", verbose)

    def _copy_file(self, source: Path, target: Path, dry_run: bool, verbose: bool) -> None:
        if dry_run:
            self._log(f"[dry-run] copy {source} -> {target}", verbose)
            return

        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        self._log(f"Copied {source.name} -> {target}", verbose)

    @staticmethod
    def _log(message: str, verbose: bool) -> None:
        if verbose:
            print(f"[verbose] {message}")
