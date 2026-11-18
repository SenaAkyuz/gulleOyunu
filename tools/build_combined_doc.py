#!/usr/bin/env python3
"""Ordino Games - ORDINO_TUM_DOKUMAN.txt'yi repodaki ayri dosyalardan yeniden olusturur.

Yapi: baslik -> CLAUDE.md ve docs/01..08 (her biri '<!-- DOSYA: ... -->' ile) -> game_data JSON eki.
Kullanim:  python3 tools/build_combined_doc.py
Doküman veya game_data degisince calistir; birlesik dosya elle duzenlenmez.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "ORDINO_TUM_DOKUMAN.txt"

HEADER = (
    "# ORDINO GAMES — TÜM PROJE DOKÜMANI (tek dosya)\n\n"
    "> Claude uygulamasındaki Proje bilgisine eklemek için birleştirilmiş sürüm. Asıl kaynak: repodaki ayrı dosyalar.\n\n"
)
MARKDOWN = ["CLAUDE.md"] + sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "docs").glob("[0-9][0-9]_*.md"))


def json_files() -> list[str]:
    data = ROOT / "game_data"
    top = sorted(p.relative_to(ROOT).as_posix() for p in data.glob("*.json"))
    levels = sorted(p.relative_to(ROOT).as_posix() for p in (data / "levels").rglob("*.json"))
    return top + levels


def read(rel: str) -> str:
    text = (ROOT / rel).read_text(encoding="utf-8").replace("\r\n", "\n")
    return text if text.endswith("\n") else text + "\n"


def build() -> str:
    parts = [HEADER]
    for rel in MARKDOWN:
        parts.append(f"\n---\n\n<!-- DOSYA: {rel} -->\n\n{read(rel)}")
    parts.append("\n---\n<!-- EK: game_data JSON dosyaları -->\n")
    blocks = [f"\n### {rel}\n```json\n{read(rel)}```\n" for rel in json_files()]
    parts.append("".join(blocks))
    return "".join(parts)


if __name__ == "__main__":
    text = build()
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"OK - {OUT.name} yazildi ({len(MARKDOWN)} dokuman, {len(json_files())} JSON, {text.count(chr(10))} satir)")
