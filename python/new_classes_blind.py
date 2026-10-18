#!/usr/bin/env python3
"""
Blind implementation of the "new technology classes" measure (spec/new_classes.md).

For each firm i and focal year t:
    new_classes = number of distinct technology classes in which firm i files
                  patents in years t+1 .. t+3 that do not appear among the classes
                  of the patents it filed in years t-5 .. t-1.

Usage:
    python3 python/new_classes_blind.py --patent-class PATH --firm-year PATH --out PATH
        [--all-codes] [--base-years 5] [--forward-years 3]

Only pandas and the standard library are used.
"""

import argparse
import sys

import pandas as pd

# Values that count as missing. Per the task, only empty strings and "NA" are
# missing; pandas' longer default list (e.g. "NaN", "null", "N/A") is NOT used,
# so that a literal identifier is never silently turned into a missing value.
MISSING_TOKENS = ["", "NA"]


# ---------------------------------------------------------------------------
# Reading inputs
# ---------------------------------------------------------------------------

def read_patent_class(path):
    """Read patent_class with the column types given in the task."""
    df = pd.read_csv(
        path,
        dtype={
            "patent_id": str,
            "firm_id": str,
            "filing_year": "Int64",   # nullable integer
            "grant_year": "Int64",    # read but not used by the measure
            "cpc_seq": "Int64",
            "cpc_subclass": str,
        },
        keep_default_na=False,
        # Missing markers are applied only to these columns. Identifiers
        # (patent_id, firm_id) are kept exactly as written.
        na_values={
            "cpc_subclass": MISSING_TOKENS,
            "filing_year": MISSING_TOKENS,
            "grant_year": MISSING_TOKENS,
            "cpc_seq": MISSING_TOKENS,
        },
    )
    required = ["patent_id", "firm_id", "filing_year", "cpc_seq", "cpc_subclass"]
    missing_cols = [c for c in required if c not in df.columns]
    if missing_cols:
        sys.exit(f"patent_class is missing columns: {missing_cols}")
    return df


def read_firm_year(path):
    """Read firm_year (firm_id str, year int)."""
    df = pd.read_csv(
        path,
        dtype={"firm_id": str, "year": "Int64"},
        keep_default_na=False,
        na_values={"year": MISSING_TOKENS},
    )
    missing_cols = [c for c in ["firm_id", "year"] if c not in df.columns]
    if missing_cols:
        sys.exit(f"firm_year is missing columns: {missing_cols}")
    return df[["firm_id", "year"]]


# ---------------------------------------------------------------------------
# Step A: firm x filing-year x class table (rules 1, 2, 3, 10)
# ---------------------------------------------------------------------------

def firm_year_classes(pc, all_codes):
    """
    Return the distinct (firm_id, filing_year, cls) triples: class `cls` appears
    on at least one patent that firm `firm_id` filed in `filing_year`.

    Exact duplicate input rows cannot change anything, because the result is a
    set of distinct triples (input requirement on duplicates).
    """
    # Exact duplicate rows are removed up front (they must not change the result;
    # everything below works on distinct values anyway, this just saves work).
    pc = pc.drop_duplicates()

    # Rule 2: the class of a patent is the CPC subclass of its first-listed code
    # (cpc_seq == 0). With --all-codes (first_listed_only = FALSE), every code on
    # the patent is used instead.
    if all_codes:
        rows = pc
    else:
        is_first = pc["cpc_seq"].eq(0).fillna(False).astype(bool)
        rows = pc[is_first]

    # Rule 3: a missing class contributes no class; missing is never a class.
    rows = rows[rows["cpc_subclass"].notna()]

    # Rule 1: a patent is dated by its filing_year (grant_year is never used).
    # A row without a filing year cannot be placed in any window, so it is dropped.
    rows = rows[rows["filing_year"].notna()]

    # Rule 10: firms are kept separate by carrying firm_id through every step.
    # A patent owned by several firms appears once per firm, so it counts for each.
    out = rows[["firm_id", "filing_year", "cpc_subclass"]].rename(
        columns={"cpc_subclass": "cls"}
    )
    return out.drop_duplicates().reset_index(drop=True)


# ---------------------------------------------------------------------------
# Step B: window sets (rules 4, 5, 6)
# ---------------------------------------------------------------------------

def window_set(fyc, offsets, wanted_keys):
    """
    Build the distinct (firm_id, year, cls) triples for a window.

    A patent filed in year f lies in focal year t's window exactly when
    t = f + k for one of the given offsets k. So each (firm, f, cls) triple is
    copied once for each offset, giving the focal years whose window it falls in.

    Only (firm_id, year) pairs listed in firm_year (wanted_keys) are kept.
    """
    parts = []
    for k in offsets:
        part = fyc[["firm_id", "cls"]].copy()
        part["year"] = fyc["filing_year"] + k
        part = part.merge(wanted_keys, on=["firm_id", "year"], how="inner")
        parts.append(part[["firm_id", "year", "cls"]])
    if not parts:
        empty = pd.DataFrame({"firm_id": pd.Series(dtype=str),
                              "year": pd.Series(dtype="Int64"),
                              "cls": pd.Series(dtype=str)})
        return empty
    return pd.concat(parts, ignore_index=True).drop_duplicates().reset_index(drop=True)


# ---------------------------------------------------------------------------
# Step C: the measure (rules 7, 8, 9, 11)
# ---------------------------------------------------------------------------

def compute(pc, fy, all_codes=False, base_years=5, forward_years=3):
    keys = ["firm_id", "year"]
    fyc = firm_year_classes(pc, all_codes)

    # The (firm, year) pairs we need results for.
    wanted = fy[keys].drop_duplicates()

    # Rule 4: base set B(i, t) = classes of patents filed in t-base_years .. t-1.
    #   filing year f is in [t-base_years, t-1]  <=>  t = f + k, k = 1..base_years
    base = window_set(fyc, range(1, base_years + 1), wanted)

    # Rule 5: forward set F(i, t) = classes of patents filed in t+1 .. t+forward_years.
    #   filing year f is in [t+1, t+forward_years]  <=>  t = f - k, k = 1..forward_years
    fwd = window_set(fyc, [-k for k in range(1, forward_years + 1)], wanted)

    # Rule 6: year t itself is in neither window -- offset k = 0 is never used above.

    # |B| and |F| per (firm, year).
    n_base = base.groupby(keys).size().rename("n_base_classes").reset_index()
    n_fwd = fwd.groupby(keys).size().rename("n_forward_classes").reset_index()

    # Rule 7: new classes = classes in F(i, t) that are not in B(i, t).
    marked = fwd.merge(base, on=keys + ["cls"], how="left", indicator=True)
    new = (
        marked[marked["_merge"] == "left_only"]
        .groupby(keys).size().rename("new_count").reset_index()
    )

    # Rule 11: exactly one output row per distinct (firm_id, year) in firm_year;
    # repeated firm_year rows are collapsed to one.
    out = fy[keys].drop_duplicates().reset_index(drop=True)
    out = out.merge(n_base, on=keys, how="left")
    out = out.merge(n_fwd, on=keys, how="left")
    out = out.merge(new, on=keys, how="left")

    # n_base_classes is 0 when B is empty; n_forward_classes is 0 when F is empty.
    out["n_base_classes"] = out["n_base_classes"].fillna(0).astype("int64")
    out["n_forward_classes"] = out["n_forward_classes"].fillna(0).astype("int64")

    # Rule 9: B not empty and F empty -> 0 (no forward rows -> no new classes).
    out["new_classes"] = out["new_count"].fillna(0).astype("Int64")

    # Rule 8: B empty -> new_classes is missing (NA), never 0 and never |F|.
    out.loc[out["n_base_classes"] == 0, "new_classes"] = pd.NA

    out = out[["firm_id", "year", "n_base_classes", "n_forward_classes", "new_classes"]]

    # Output sorted by firm_id then year.
    out = out.sort_values(keys, kind="mergesort").reset_index(drop=True)
    return out


# ---------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------

def nonneg_int(text):
    value = int(text)
    if value < 0:
        raise argparse.ArgumentTypeError("must be a non-negative integer")
    return value


def main(argv=None):
    p = argparse.ArgumentParser(description="New technology classes measure.")
    p.add_argument("--patent-class", required=True, help="patent x CPC code CSV")
    p.add_argument("--firm-year", required=True, help="firm-years to produce CSV")
    p.add_argument("--out", required=True, help="output CSV path")
    p.add_argument("--all-codes", action="store_true",
                   help="use every CPC code on a patent (first_listed_only = FALSE)")
    p.add_argument("--base-years", type=nonneg_int, default=5)
    p.add_argument("--forward-years", type=nonneg_int, default=3)
    args = p.parse_args(argv)

    pc = read_patent_class(args.patent_class)
    fy = read_firm_year(args.firm_year)
    out = compute(pc, fy, all_codes=args.all_codes,
                  base_years=args.base_years, forward_years=args.forward_years)
    out.to_csv(args.out, index=False, na_rep="NA")


if __name__ == "__main__":
    main()
