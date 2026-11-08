#!/usr/bin/env python3
"""Render a VUnit xunit XML report for GitHub Actions.

Writes a Markdown table of all tests to the job summary
($GITHUB_STEP_SUMMARY, or stdout when run locally) and emits an
``::error`` workflow annotation for every failed test, pointing at its
testbench file. Exits non-zero if any test failed or errored.

Usage: python tools/xunit_summary.py test_results.xml
"""

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

ICONS = {"passed": "✅", "failed": "❌", "skipped": "⏭️"}


def escape_data(text):
    """Escape a message for a GitHub workflow command."""
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(text):
    return escape_data(text).replace(":", "%3A").replace(",", "%2C")


def testbench_file(classname):
    """Map 'lib.tb_name[.config]' to projects/lib/tb/tb_name.vhd if it exists."""
    parts = classname.split(".")
    if len(parts) < 2:
        return None
    path = Path("projects") / parts[0] / "tb" / f"{parts[1]}.vhd"
    return path if (ROOT / path).is_file() else None


def failure_reason(case):
    """Pick the most useful lines of a failed test's simulator output."""
    out = case.findtext("system-out") or ""
    lines = [l.strip() for l in out.splitlines()
             if any(k in l for k in ("ERROR", "FAILURE", "error:", "failed"))]
    return "\n".join(lines[:5]) or "Test failed (see job log for output)"


def main(xml_path):
    suite = ET.parse(xml_path).getroot()
    results = []
    for case in suite.iter("testcase"):
        if case.find("failure") is not None or case.find("error") is not None:
            status = "failed"
        elif case.find("skipped") is not None:
            status = "skipped"
        else:
            status = "passed"
        results.append((case, status))

    counts = {s: sum(1 for _, st in results if st == s) for s in ICONS}
    overall = "❌ Some tests failed" if counts["failed"] else "✅ All tests passed"

    md = [
        f"## VUnit results: {overall}",
        "",
        f"**{counts['passed']} passed**, **{counts['failed']} failed**, "
        f"**{counts['skipped']} skipped** of {len(results)}",
        "",
        "| | Testbench | Test | Time |",
        "|---|---|---|---:|",
    ]
    # Failures first, then alphabetical.
    order = {"failed": 0, "skipped": 1, "passed": 2}
    for case, status in sorted(results, key=lambda r: (order[r[1]], r[0].get("classname"), r[0].get("name"))):
        md.append(f"| {ICONS[status]} | `{case.get('classname')}` | `{case.get('name')}` "
                  f"| {float(case.get('time', 0)):.1f} s |")

    failed = [case for case, status in results if status == "failed"]
    if failed:
        md += ["", "### Failures", ""]
        for case in failed:
            reason = failure_reason(case)
            md += [f"<details><summary><code>{case.get('classname')}.{case.get('name')}</code></summary>",
                   "", "```", reason, "```", "</details>", ""]

            title = f"{case.get('classname')}.{case.get('name')}"
            props = f"title={escape_property(title)}"
            tb_file = testbench_file(case.get("classname", ""))
            if tb_file:
                props = f"file={escape_property(str(tb_file))},{props}"
            print(f"::error {props}::{escape_data(reason)}")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    text = "\n".join(md) + "\n"
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(text)
    else:
        print(text)

    return 1 if failed else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
