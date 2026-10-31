#!/usr/bin/env python3
"""Blind rebuild of the "new technology classes" measure (definition version 0.3).

For each firm i and focal year t:
  B(i, t) = distinct classes of firm i's patents filed in t-N .. t-1   (N = --base-years, default 5)
  F(i, t) = distinct classes of firm i's patents filed in t .. t+M-1   (M = --forward-years, default 3)
  new_classes = |F \\ B|, missing (NA) when B is empty, 0 when B is non-empty and F is empty.

A patent's class is the CPC subclass on its first-listed code (cpc_seq == 0); with --all-codes every
code on the patent counts. Blank classes are never counted. Patents are placed by filing_year.

Usage:
  python3 new_classes_blind.py --patent-class PATH --firm-year PATH --out PATH
                               [--all-codes] [--base-years N] [--forward-years M]

Only pandas and the standard library are used.
"""
import argparse
import sys

import pandas as pd

MISSING_TEXT = ("", "NA")  # the only values treated as missing

PATENT_COLS = ["patent_id", "firm_id", "filing_year", "cpc_seq", "cpc_subclass"]
FIRM_YEAR_COLS = ["firm_id", "year"]
OUT_COLS = ["firm_id", "year", "n_base_classes", "n_forward_classes", "new_classes"]


def read_text_csv(path, wanted):
    """Read a CSV with every column as text. Nothing is turned into missing by pandas."""
    wanted_set = set(wanted)
    df = pd.read_csv(
        path,
        dtype=str,
        na_filter=False,
        keep_default_na=False,
        usecols=lambda c: c.strip() in wanted_set,
    )
    df.columns = [c.strip() for c in df.columns]
    absent = [c for c in wanted if c not in df.columns]
    if absent:
        sys.exit(f"error: {path} is missing column(s): {', '.join(absent)}")
    return df[wanted]


def is_missing(s):
    return s.isin(MISSING_TEXT)


def to_whole_number(s, label):
    """Text -> nullable integer. '' and 'NA' become missing; anything non-integer is an error."""
    miss = is_missing(s)
    num = pd.to_numeric(s.where(~miss).str.strip(), errors="coerce")
    bad = num.isna() & ~miss
    bad |= num.notna() & (num != num.round())
    if bad.any():
        examples = ", ".join(repr(v) for v in s[bad].unique()[:5])
        sys.exit(f"error: column {label} has values that are not whole numbers: {examples}")
    return num.astype("Int64")


def compute(patents, firm_year, base_years, forward_years, first_listed_only):
    # ---- firm-years to compute: one row per distinct (firm_id, year) ----
    fy = pd.DataFrame(
        {
            "firm_id": firm_year["firm_id"].where(~is_missing(firm_year["firm_id"])),
            "year": to_whole_number(firm_year["year"], "firm_year.year"),
        }
    ).drop_duplicates(ignore_index=True)

    valid_fy = fy["firm_id"].notna() & fy["year"].notna()
    firm_index = pd.Index(fy.loc[valid_fy, "firm_id"].unique())

    # ---- patent rows -> distinct (firm, class, filing year) ----
    pat = patents
    keep = ~is_missing(pat["firm_id"]) & ~is_missing(pat["cpc_subclass"])  # rule 3: blank adds no class
    pat = pat[keep]
    if first_listed_only:  # rule 2: class of the first-listed code (cpc_seq == 0)
        seq = to_whole_number(pat["cpc_seq"], "patent_class.cpc_seq")
        pat = pat[(seq == 0).fillna(False).to_numpy()]
    fyear = to_whole_number(pat["filing_year"], "patent_class.filing_year")  # rule 1: filing year
    f_code = firm_index.get_indexer(pat["firm_id"])  # -1 for firms not in firm_year (rule 10: irrelevant)
    use = (fyear.notna().to_numpy()) & (f_code >= 0)
    c_code, _classes = pd.factorize(pat["cpc_subclass"].to_numpy()[use])
    fcy = pd.DataFrame(
        {
            "f": f_code[use],
            "c": c_code,
            "y": fyear.to_numpy()[use].astype("int64"),
        }
    ).drop_duplicates(ignore_index=True)  # exact duplicate rows cannot change the result

    targets = pd.DataFrame(
        {
            "f": firm_index.get_indexer(fy.loc[valid_fy, "firm_id"]),
            "t": fy.loc[valid_fy, "year"].astype("int64").to_numpy(),
        }
    ).drop_duplicates(ignore_index=True)

    def membership(offsets):
        """Distinct (f, c, t) such that class c of firm f appears in a year y with t = y + offset."""
        parts = []
        for off in offsets:
            parts.append(pd.DataFrame({"f": fcy["f"].to_numpy(), "c": fcy["c"].to_numpy(),
                                       "t": fcy["y"].to_numpy() + off}))
        if not parts:
            return pd.DataFrame({"f": pd.Series(dtype="int64"), "c": pd.Series(dtype="int64"),
                                 "t": pd.Series(dtype="int64")})
        m = pd.concat(parts, ignore_index=True)
        m = m.merge(targets, on=["f", "t"], how="inner")
        return m.drop_duplicates(ignore_index=True)

    # rule 4: y in [t-N, t-1]  <=>  t = y + k, k = 1..N
    base = membership(range(1, base_years + 1))
    # rules 5-6: y in [t, t+M-1]  <=>  t = y - k, k = 0..M-1
    fwd = membership(range(-(forward_years - 1), 1))

    n_base = base.groupby(["f", "t"]).size().rename("n_base_classes")
    n_fwd = fwd.groupby(["f", "t"]).size().rename("n_forward_classes")
    fwd_flag = fwd.merge(base.assign(in_base=True), on=["f", "c", "t"], how="left")
    fwd_flag["is_new"] = fwd_flag["in_base"].isna()
    n_new = fwd_flag.groupby(["f", "t"])["is_new"].sum().rename("n_new")  # rule 7

    res = targets.merge(n_base.reset_index(), on=["f", "t"], how="left")
    res = res.merge(n_fwd.reset_index(), on=["f", "t"], how="left")
    res = res.merge(n_new.reset_index(), on=["f", "t"], how="left")
    for col in ("n_base_classes", "n_forward_classes", "n_new"):
        res[col] = res[col].fillna(0).astype("int64")
    res["new_classes"] = res["n_new"].astype("Int64")
    res.loc[res["n_base_classes"] == 0, "new_classes"] = pd.NA  # rule 8 (rule 9 falls out: 0)
    res["firm_id"] = firm_index.take(res["f"].to_numpy())
    res["year"] = res["t"].astype("Int64")
    res = res[OUT_COLS]

    # firm-years with a missing firm_id or year: kept, all values missing
    bad = fy.loc[~valid_fy].copy()
    if len(bad):
        for col in ("n_base_classes", "n_forward_classes", "new_classes"):
            bad[col] = pd.NA
        res = pd.concat([res, bad[OUT_COLS]], ignore_index=True)

    for col in ("n_base_classes", "n_forward_classes", "new_classes"):
        res[col] = res[col].astype("Int64")
    res = res.sort_values(["firm_id", "year"], kind="mergesort", na_position="last")
    return res.reset_index(drop=True)


def main(argv=None):
    ap = argparse.ArgumentParser(description="New technology classes (definition v0.3), blind rebuild.")
    ap.add_argument("--patent-class", required=True, help="patent_class CSV")
    ap.add_argument("--firm-year", required=True, help="firm_year CSV")
    ap.add_argument("--out", required=True, help="output CSV")
    ap.add_argument("--all-codes", action="store_true",
                    help="robustness setting first_listed_only = FALSE: use every code on a patent")
    ap.add_argument("--base-years", type=int, default=5, help="base window length N (t-N..t-1)")
    ap.add_argument("--forward-years", type=int, default=3, help="forward window length M (t..t+M-1)")
    a = ap.parse_args(argv)
    if a.base_years < 0 or a.forward_years < 0:
        ap.error("--base-years and --forward-years must be 0 or more")

    patents = read_text_csv(a.patent_class, PATENT_COLS)
    firm_year = read_text_csv(a.firm_year, FIRM_YEAR_COLS)
    out = compute(patents, firm_year, a.base_years, a.forward_years, not a.all_codes)
    out.to_csv(a.out, index=False, na_rep="NA")


if __name__ == "__main__":
    main()
