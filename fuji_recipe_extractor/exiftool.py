from __future__ import annotations

import json
from pathlib import Path
import subprocess

from .models import ExifRecord


DEFAULT_EXIFTOOL_PATH = "/usr/local/bin/exiftool"


class ExifToolError(RuntimeError):
    pass


class ExifToolClient:
    def __init__(self, exiftool_path: str = DEFAULT_EXIFTOOL_PATH) -> None:
        self.exiftool_path = exiftool_path

    def assert_available(self) -> None:
        path = Path(self.exiftool_path)
        if not path.exists() or not path.is_file() or not path.stat().st_mode & 0o111:
            raise ExifToolError(f"exiftool not found or not executable: {self.exiftool_path}")

    def extract(self, files: list[Path], verbose: bool = False) -> list[ExifRecord]:
        if not files:
            return []

        command = [
            self.exiftool_path,
            "-j",
            "-FilmMode",
            "-CameraProfile",
            "-DynamicRange",
            "-DevelopmentDynamicRange",
            "-HighlightTone",
            "-ShadowTone",
            "-Saturation",
            "-NoiseReduction",
            "-Sharpness",
            "-Clarity",
            "-GrainEffectRoughness",
            "-GrainEffectSize",
            "-ColorChromeEffect",
            "-ColorChromeFXBlue",
            "-WhiteBalance",
            "-WhiteBalanceFineTune",
            "-ISO",
            "-ExposureCompensation",
            *[str(path.resolve()) for path in files],
        ]

        if verbose:
            print("[verbose] Running:", " ".join(command))

        try:
            completed = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
            )
        except OSError as exc:
            raise ExifToolError(f"failed to run exiftool: {exc}") from exc

        if completed.returncode != 0:
            raise ExifToolError(
                f"exiftool failed with exit code {completed.returncode}\n{completed.stdout}{completed.stderr}"
            )

        try:
            payload = json.loads(completed.stdout)
        except json.JSONDecodeError as exc:
            raise ExifToolError(f"failed to parse exiftool JSON output: {exc}") from exc

        return [ExifRecord.from_exiftool_json(item) for item in payload]
