"""Refresh the embedded prototype while retaining its standalone rendering shell."""
from html import escape, unescape
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "design/source/homeschool-screen-prototypes.html"
EXPORT = ROOT / "design/prototype/index.html"
START = "<!-- HSH_SOURCE_START -->"
END = "<!-- HSH_SOURCE_END -->"


def main():
    source = SOURCE.read_text(encoding="utf-8").strip()
    if source.count(START) != 1 or source.count(END) != 1:
        raise SystemExit("Source must contain exactly one pair of source markers")
    if not source.startswith(START) or not source.endswith(END):
        raise SystemExit("Source markers must enclose the whole fragment")
    document = EXPORT.read_text(encoding="utf-8")
    match = re.search(r'srcdoc="([^"]*)"', document)
    if not match:
        raise SystemExit("Standalone export srcdoc was not found")
    inner = unescape(match.group(1))
    if inner.count(START) != 1 or inner.count(END) != 1:
        raise SystemExit("Export must contain exactly one pair of source markers")
    start = inner.index(START)
    end = inner.index(END) + len(END)
    inner = inner[:start] + source + inner[end:]
    result = document[:match.start(1)] + escape(inner, quote=True) + document[match.end(1):]
    EXPORT.write_text(result, encoding="utf-8")
    print("Updated design/prototype/index.html")


if __name__ == "__main__":
    main()
