# fuji-recipe-extractor

Fujifilm JPEG files from an input directory are scanned with `exiftool`, converted into normalized recipe data, and exported as Markdown plus copied images for Obsidian-friendly browsing.

The repository currently contains:

- a Python CLI implementation
- a lightweight native macOS app
- Markdown export utilities for Obsidian-style photo recipe browsing

## Features

- recursively scans `.jpg` and `.jpeg` files
- extracts Fujifilm recipe-related EXIF metadata
- exports Markdown notes and image copies
- generates recipe and film indexes
- optional image grouping by recipe or film simulation
- native macOS UI for folder selection and scan management

Extracted metadata includes:

- Film Simulation
- Dynamic Range
- Highlight / Shadow
- White Balance
- Grain Effect
- Color Chrome Effect
- ISO
- Exposure Compensation
- and additional Fujifilm recipe settings

## Requirements

### Python CLI

- macOS
- Python 3
- `exiftool`

The current implementation expects `exiftool` at:

```bash
/usr/local/bin/exiftool
```

Note:

- Apple Silicon Homebrew installations often use `/opt/homebrew/bin/exiftool`
- the path is currently hardcoded in the CLI and macOS app implementation

### macOS App Build

The native macOS app build additionally requires:

- Xcode command line tools
- `swiftc`
- `xcrun`
- macOS SDK

## CLI Usage

The simplest entry point is:

```bash
./run-scan.sh /path/to/input /path/to/output
```

Optional flags:

```bash
./run-scan.sh /path/to/input /path/to/output --copy-by recipe --verbose
```

Direct CLI invocation:

```bash
python3 -m fuji_recipe_extractor scan \
  --input /path/to/input \
  --output /path/to/output \
  --copy-by recipe \
  --verbose
```

### CLI Options

| Option | Description |
| --- | --- |
| `--copy-by recipe` | Copy images grouped by recipe |
| `--copy-by film` | Copy images grouped by film simulation |
| `--dry-run` | Show planned actions without writing files |
| `--verbose` | Enable verbose logging |

## Output Structure

The generated output directory contains:

```text
output/
├── images/
├── indexes/
│   ├── film.md
│   └── recipes.md
├── notes/
└── recipes/
```

### Generated Content

- `notes/`
  - Markdown note per image
- `images/`
  - copied source JPEG files
- `recipes/`
  - optional grouped copies by recipe or film
- `indexes/film.md`
  - grouped index by film simulation
- `indexes/recipes.md`
  - grouped index by recipe key

## macOS App

The native macOS app sources are located under:

```text
macos-app/Sources/
```

The app uses `exiftool` directly and does not depend on the Python CLI at runtime.

The app icon artwork is bundled from:

```text
macos-app/Assets/Untitled Exports/
```

Build the app bundle with:

```bash
./scripts/build-macos-app.sh
```

The built app bundle will be created at:

```bash
./dist/Fuji Recipe Extractor.app
```

### macOS App Features

From the app UI you can:

- choose input and output folders
- choose copy mode: none, recipe, or film
- enable dry-run and verbose logging
- run scans and view logs in-app
- browse scan results with thumbnails
- filter results by film simulation and source type
- sort scan results
