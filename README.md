# fuji-recipe-extractor

Fujifilm JPEG files from an input directory are scanned with `exiftool`, converted into normalized recipe data, and exported as Markdown plus copied images for Obsidian-friendly browsing. The current implementation is Python-based and uses only the standard library plus the system `exiftool`.

## Requirements

- macOS
- Python 3
- `exiftool` installed at `/usr/local/bin/exiftool`

## Usage

The simplest entry point is:

```bash
./run-scan.sh /path/to/input /path/to/output
```

You can pass optional CLI flags after the two required directories:

```bash
./run-scan.sh /path/to/input /path/to/output --copy-by recipe --verbose
```

If you want to call the CLI directly:

```bash
python3 -m fuji_recipe_extractor scan --input /path/to/input --output /path/to/output --copy-by recipe --verbose
```

## macOS App

A native macOS app is also included under [macos-app/Sources](/Users/itagakitomoya/Documents/fuji_recipe_extractor/macos-app/Sources). It uses `exiftool` directly and does not depend on the Python CLI at runtime.
A bundled app icon is copied from the asset export set under [Untitled Exports](/Users/itagakitomoya/Documents/fuji_recipe_extractor/macos-app/Assets/Untitled%20Exports) during the build and applied to the app bundle.
The app icon artwork was generated with Google Stitch and then exported into the asset set used by the macOS app build.

Build the app bundle with:

```bash
./scripts/build-macos-app.sh
```

The built app will be created at:

```bash
./dist/Fuji Recipe Extractor.app
```

From the app UI you can:

- choose the input and output folders
- choose copy mode: none, recipe, or film
- enable dry-run and verbose logging
- run the scan and view logs in-app
