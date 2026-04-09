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
