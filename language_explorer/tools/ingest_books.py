#!/usr/bin/env python3
"""Ingest curated book sources → game/books/<id>/ + refresh game/data/books.json.

Sources live under tools/book_sources/<id>/book.yaml (hand-vetted PD / original
retellings). This does not scrape Gutenberg at runtime — provenance stays in
docs/BIBLIOGRAPHY.md and the YAML header.

Usage:
  python3 tools/ingest_books.py
  python3 tools/ingest_books.py --id peter_rabbit
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools" / "book_sources"
OUT_BOOKS = ROOT / "game" / "books"
CATALOG = ROOT / "game" / "data" / "books.json"


def tokenize(text: str) -> list[str]:
    """Split on whitespace; keep punctuation glued to tokens for display."""
    return [t for t in re.split(r"\s+", text.strip()) if t]


def load_yaml(path: Path) -> dict:
    raw = path.read_text(encoding="utf-8")
    if yaml is not None:
        data = yaml.safe_load(raw)
        if not isinstance(data, dict):
            raise SystemExit(f"expected mapping in {path}")
        return data
    # Minimal fallback if PyYAML is missing (enough for our simple files).
    return _parse_simple_yaml(raw, path)


def _parse_simple_yaml(raw: str, path: Path) -> dict:
    """Tiny subset parser: key: value, pages: list of - lines, folded notes."""
    data: dict = {"pages": []}
    mode = None
    note_lines: list[str] = []
    for line in raw.splitlines():
        if mode == "notes":
            if line.startswith("  ") or line.startswith("\t"):
                note_lines.append(line.strip())
                continue
            data["notes"] = " ".join(note_lines).strip()
            mode = None
        if mode == "pages":
            if line.strip().startswith("- "):
                data["pages"].append(line.strip()[2:].strip().strip('"'))
                continue
            if line.strip() and not line.startswith(" "):
                mode = None
            else:
                continue
        if not line.strip() or line.strip().startswith("#"):
            continue
        if line.startswith("pages:"):
            mode = "pages"
            continue
        if line.startswith("notes:"):
            mode = "notes"
            note_lines = []
            rest = line[len("notes:") :].strip().strip(">").strip()
            if rest:
                note_lines.append(rest)
            continue
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            data[k.strip()] = v.strip().strip('"')
    if mode == "notes":
        data["notes"] = " ".join(note_lines).strip()
    if not data.get("id"):
        raise SystemExit(f"could not parse {path} (install pyyaml for full support)")
    return data


def ingest_one(src_dir: Path) -> dict:
    yaml_path = src_dir / "book.yaml"
    if not yaml_path.exists():
        raise SystemExit(f"missing {yaml_path}")
    meta_in = load_yaml(yaml_path)
    book_id = str(meta_in["id"])
    pages_text: list[str] = list(meta_in.get("pages") or [])
    if not pages_text:
        raise SystemExit(f"{book_id}: no pages")

    out_dir = OUT_BOOKS / book_id
    pages_dir = out_dir / "pages"
    pages_dir.mkdir(parents=True, exist_ok=True)
    # Clear old page JSONs so renumbering stays clean.
    for old in pages_dir.glob("*.json"):
        old.unlink()

    page_paths: list[str] = []
    for i, text in enumerate(pages_text):
        tokens = tokenize(text)
        page = {"index": i, "text": text, "tokens": tokens}
        rel = f"res://books/{book_id}/pages/{i:03d}.json"
        (pages_dir / f"{i:03d}.json").write_text(
            json.dumps(page, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        page_paths.append(rel)

    cover_res = f"res://books/{book_id}/cover.png"
    meta = {
        "id": book_id,
        "lang": str(meta_in.get("lang", "en")),
        "title": str(meta_in.get("title", book_id)),
        "description": str(meta_in.get("description", "")),
        "license": str(meta_in.get("license", "")),
        "source_url": str(meta_in.get("source_url", "")),
        "retrieved_on": str(meta_in.get("retrieved_on", "")),
        "notes": str(meta_in.get("notes", "")),
        "cover": cover_res,
        "cover_motif": str(meta_in.get("cover_motif", book_id)),
        "pages": page_paths,
        "ship": True,
    }
    (out_dir / "meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    # Placeholder cover marker (Godot draws procedural if PNG missing).
    marker = out_dir / "cover.png.missing"
    if not (out_dir / "cover.png").exists():
        marker.write_text(
            "Procedural cover via CoverArt.gd until a licensed PNG is dropped here.\n",
            encoding="utf-8",
        )
    else:
        if marker.exists():
            marker.unlink()

    catalog_row = {
        "id": book_id,
        "lang": meta["lang"],
        "title": meta["title"],
        "description": meta["description"],
        "cover": meta["cover"],
        "cover_motif": meta["cover_motif"],
        "pages": page_paths,
        "license": meta["license"],
        "source_url": meta["source_url"],
        "ship": True,
    }
    print(f"ingested {book_id}: {len(page_paths)} pages → {out_dir}")
    return catalog_row


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", help="ingest only this book id")
    args = ap.parse_args()

    if not SOURCES.is_dir():
        print(f"no sources at {SOURCES}", file=sys.stderr)
        return 1

    rows: list[dict] = []
    for src in sorted(SOURCES.iterdir()):
        if not src.is_dir():
            continue
        if args.id and src.name != args.id:
            continue
        if not (src / "book.yaml").exists():
            continue
        rows.append(ingest_one(src))

    if args.id and not rows:
        print(f"no source for id={args.id}", file=sys.stderr)
        return 1

    # Merge with any existing non-shipped stubs we still want listed? Replace fully
    # with ingested ship:true rows for Phase 4.
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote catalog {CATALOG} ({len(rows)} books)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
