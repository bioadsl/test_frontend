import re
import sys
import time
from urllib.parse import urljoin, urlparse

import requests


PAGES = [
    "reports/action.html",
    "reports/results.html",
    "reports/cases.html",
]


def find_links(html: str):
    # capture full <a ...> tags and attributes
    links = []
    for m in re.finditer(r"<a[^>]+>", html, flags=re.IGNORECASE):
        tag = m.group(0)
        href_m = re.search(r"href\s*=\s*['\"]([^'\"]+)['\"]", tag, flags=re.IGNORECASE)
        if not href_m:
            continue
        href = href_m.group(1)
        target_m = re.search(r"target\s*=\s*['\"]([^'\"]+)['\"]", tag, flags=re.IGNORECASE)
        rel_m = re.search(r"rel\s*=\s*['\"]([^'\"]+)['\"]", tag, flags=re.IGNORECASE)
        aria_m = re.search(r"aria-label\s*=\s*['\"]([^'\"]+)['\"]", tag, flags=re.IGNORECASE)
        links.append({
            "tag": tag,
            "href": href,
            "target": (target_m.group(1) if target_m else None),
            "rel": (rel_m.group(1) if rel_m else None),
            "aria": (aria_m.group(1) if aria_m else None),
        })
    return links


def check_link(base_url: str, page_url: str, link: dict):
    href = link["href"]
    absolute = urljoin(page_url, href)
    parsed = urlparse(absolute)
    is_external = bool(parsed.scheme and parsed.netloc) and not parsed.netloc.startswith("localhost") and not parsed.netloc.startswith("127.0.0.1")

    result = {
        "href": href,
        "absolute": absolute,
        "status": None,
        "ok": False,
        "errors": [],
        "warnings": [],
        "is_external": is_external,
    }

    # Protocol adequacy
    if is_external and parsed.scheme != "https":
        result["warnings"].append("External link should use https")

    # Accessibility/semantics
    if link.get("target") == "_blank":
        rel = (link.get("rel") or "").lower()
        if "noopener" not in rel or "noreferrer" not in rel:
            result["warnings"].append("_blank links should include rel=\"noopener noreferrer\"")
    if not link.get("aria"):
        result["warnings"].append("Link should include aria-label for accessibility")

    # Resolve and request
    try:
        resp = requests.get(absolute, timeout=8)
        result["status"] = resp.status_code
        if 200 <= resp.status_code < 400:
            result["ok"] = True
        else:
            result["errors"].append(f"HTTP {resp.status_code}")
    except Exception as e:
        result["errors"].append(str(e))

    return result


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000/"
    session = requests.Session()

    print(f"[check] Base URL: {base}")
    overall_ok = True
    report = []

    for page in PAGES:
        page_url = urljoin(base, page)
        try:
            html = session.get(page_url, timeout=8).text
        except Exception as e:
            overall_ok = False
            print(f"[error] Falha ao abrir página {page_url}: {e}")
            continue
        links = find_links(html)
        print(f"[page] {page_url} — {len(links)} links encontrados")
        for link in links:
            r = check_link(base, page_url, link)
            report.append(r)
            status = r["status"]
            if not r["ok"]:
                overall_ok = False
                print(f"  [broken] {r['absolute']} — status={status} errors={r['errors']}")
            else:
                print(f"  [ok] {r['absolute']} — status={status}")
            for w in r["warnings"]:
                print(f"    [warn] {w}")

    print("\nResumo:")
    total = len(report)
    oks = sum(1 for r in report if r["ok"]) if report else 0
    print(f"  Total links: {total}")
    print(f"  OK: {oks}")
    print(f"  Broken: {total - oks}")

    sys.exit(0 if overall_ok else 1)


if __name__ == "__main__":
    main()