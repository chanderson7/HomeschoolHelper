"""Publish SwiftPM xUnit results without requiring a GitHub write token."""
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

report = Path(sys.argv[1])
if report.exists():
    root = ET.parse(report).getroot()
    cases = list(root.iter("testcase"))
    failed = sum(case.find("failure") is not None or case.find("error") is not None for case in cases)
    skipped = sum(case.find("skipped") is not None for case in cases)
    summary = f"### Unit tests\n\n{len(cases)} tests · {failed} failed · {skipped} skipped\n"
else:
    summary = "### Unit tests\n\nNo report generated. Check the test step for build or runner errors.\n"
print(summary)
if destination := os.environ.get("GITHUB_STEP_SUMMARY"):
    with open(destination, "a") as output:
        output.write(summary)
