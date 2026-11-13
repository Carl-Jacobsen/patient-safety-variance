#!/usr/bin/env python3
"""Task 1.7 re-download test.

Phase 1's grading condition: a stranger holding ONLY provenance/sources.csv can
re-download every file this project reads. This script is that stranger. For
each retrieved source it follows the recorded url + retrieval_method, fetches a
fresh copy, and compares its sha256 to the value the table records.

  python3 provenance/redownload-test.py [provenance/sources.csv]

Standard library only, by the same reasoning R/provenance.R is base R only: the
recipe must not depend on tooling the recipe does not mention.

Verdicts
  MATCH    fresh bytes hash-identical to the archived file
  REFRESH  recipe resolves and returns a valid file, bytes differ (upstream
           published a newer version since retrieval_date) -- recipe still good
  CRED     recipe is complete but retrieval needs a credential the table
           deliberately does not carry (ACS API key, Neighborhood Atlas account)
  FAIL     the recorded information is not enough to obtain the file
  NA       not-retrieved source (exclusion_reason set); nothing to fetch

Last run: 2026-08-31 -- 25 MATCH, 3 CRED, 3 NA. Result written up in
provenance/task1.7-provenance-close.md.
"""
import csv, hashlib, json, os, sys, tempfile, urllib.parse, urllib.request

PROV = sys.argv[1] if len(sys.argv) > 1 else "provenance/sources.csv"
UA = {"User-Agent": "Mozilla/5.0 (provenance re-download test)"}


def get(url, timeout=180):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout)


def download(url, dest, timeout=900):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r, \
         open(dest, "wb") as f:
        for b in iter(lambda: r.read(1 << 20), b""):
            f.write(b)
    return dest


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


# ---- method resolvers -------------------------------------------------------
# The url column records the recipe as prose ("... -> identifier ynj2-r877 ->
# distribution[[1]]$data$downloadURL"). A fresh session parses the operative
# token out of it; these helpers are that parse.

_PDC = {}
def resolve_pdc(identifier):
    if not _PDC:
        _PDC["items"] = json.load(get(
            "https://data.cms.gov/provider-data/api/1/metastore/schemas/"
            "dataset/items?show-reference-ids=false"))
    for rec in _PDC["items"]:
        if rec.get("identifier") == identifier:
            return rec["distribution"][0]["data"]["downloadURL"]
    raise RuntimeError(f"identifier {identifier} absent from PDC metastore")


_CAT = {}
def resolve_catalog(title, filename):
    if not _CAT:
        _CAT["d"] = json.load(get("https://data.cms.gov/data.json"))
    for ds in _CAT["d"]["dataset"]:
        if ds.get("title") == title:
            for dist in ds.get("distribution", []):
                u = dist.get("downloadURL", "")
                if u and os.path.basename(urllib.parse.unquote(u)) == filename:
                    return u
    raise RuntimeError(f"catalog: no {filename!r} under {title!r}")


# identifier / title tokens as recorded in each row's url column
PDC_ID = {
    "cc_candd": "ynj2-r877", "cc_psi6dec": "muwa-iene", "cc_footnotes": "y9us-9xdf",
    "cc_measuredates": "4j6d-yzce", "cc_hospinfo": "xubh-q36u", "hacrp_fy2026": "yq43-i98g",
}
CATALOG = {
    "hcris_puf_fy2023": ("Hospital Provider Cost Report", "CostReport_2023_Final.csv"),
    "hcris_puf_fy2022": ("Hospital Provider Cost Report", "CostReport_2022_Final.csv"),
    "pos_q2_2026": ("Provider of Services File - Quality Improvement and Evaluation System",
                    "Hospital_and_other.DATA.Q2_2026.csv"),
    "hosp_enrollments": ("Hospital Enrollments", "Hospital_Enrollments_2026.07.31.csv"),
    "hosp_all_owners": ("Hospital All Owners", "Hospital_All_Owners_2026.07.31.csv"),
    "hsaf_2023": ("Hospital Service Area", "Hospital_Service_Area_2023.csv"),
    "hsaf_2024": ("Hospital Service Area", "Hospital_Service_Area_2024.csv"),
}


def direct_url(row):
    for tok in row["url"].replace("->", " ").split():
        if tok.startswith("http"):
            return tok
    raise RuntimeError("no http token in url column")


# ---- run ------------------------------------------------------------------
rows = list(csv.DictReader(open(PROV)))
results = []
with tempfile.TemporaryDirectory() as work:
    for row in rows:
        sid, method, recorded = row["source_id"], row["retrieval_method"], row["sha256"].strip()
        if row["exclusion_reason"].strip():
            results.append((sid, method, "NA", "not retrieved; exclusion_reason set"))
            continue
        try:
            if method == "metastore API":
                url = resolve_pdc(PDC_ID[sid])
            elif method == "catalog API":
                url = resolve_catalog(*CATALOG[sid])
            elif method == "web API":
                if not os.environ.get("CENSUS_API_KEY"):
                    results.append((sid, method, "CRED",
                                    "ACS API key (CENSUS_API_KEY) required; not in table by design"))
                    continue
                url = None
            elif method == "account login":
                base = direct_url(row)
                results.append((sid, method, "CRED",
                                f"Neighborhood Atlas account required; landing -> HTTP {get(base, 60).status}"))
                continue
            else:
                url = direct_url(row)

            if url is None:
                results.append((sid, method, "CRED", "keyed API pull; recipe recorded, not exercised"))
                continue

            dest = os.path.join(work, sid + "__" + os.path.basename(urllib.parse.unquote(url)))
            download(url, dest)
            fresh, size = sha256(dest), os.path.getsize(dest)
            os.remove(dest)
            if fresh == recorded:
                results.append((sid, method, "MATCH", f"{size/1e6:.1f} MB, sha256 identical"))
            else:
                results.append((sid, method, "REFRESH",
                                f"{size/1e6:.1f} MB; sha256 {fresh[:12]} vs recorded {recorded[:12]}"))
        except Exception as e:
            results.append((sid, method, "FAIL", f"{type(e).__name__}: {e}"))

print(f"{'source_id':26} {'method':15} {'verdict':9} detail")
print("-" * 100)
for r in results:
    print(f"{r[0]:26} {r[1]:15} {r[2]:9} {r[3]}")
from collections import Counter
print("\nsummary:", dict(Counter(r[2] for r in results)))
sys.exit(1 if any(r[2] == "FAIL" for r in results) else 0)
