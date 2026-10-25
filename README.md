# Auditable research loop: prototype

**Status:** prototype for the Organization Science special issue "AI-Enabled Frontiers in
Organizational Science" (Stage 1). Private until submission.

## What this is

A working prototype of the checking layer in a human-directed, AI-assisted research loop.
No code can be proven correct, so the aim is *measured assurance*: several independent
checks that fail in different ways, a count of how strong they are, and a written record
of every decision a person made.

The demo runs the full set of checks on one variable used in innovation research,
**new technology classes**: for each firm and year *t*, the number of CPC subclasses the
firm files patents in during *t*+1 to *t*+3 that were not in its patents filed in *t*-5 to *t*-1.
Definition: [`spec/new_classes.md`](spec/new_classes.md).

## The check layers

| Layer | What it does | Where |
|---|---|---|
| Definition and decisions | Plain-words definition; every open choice decided by the researcher and logged with its precedent | `spec/`, `logs/decisions.csv` |
| Data checks | One row per firm-year, row counts, value ranges, missing values | `R/checks.R` |
| Fast build | The normal, vectorized version (R) | `R/new_classes_fast.R` |
| Slow, plain build | Follows the definition line by line, for a person to read against it (R) | `R/new_classes_slow.R` |
| Blind rebuild | Written by a separate AI agent from the definition only, in another language (Python) | `python/new_classes_blind.py` |
| Fake firms | Small firms whose answers were worked out by hand | `tests/make_fixtures.R` |
| Rules | Changes to the input with known effects on the output (duplicates, shuffles, year *t*, other firms...) | `tests/rules.R` |
| One worked case | The researcher walks one real firm-year through the slow build and the definition, step by step (decision D09). A random hand-check of 100+ cases is kept as a Stage 2 tool | `handcheck/` |
| Planted bugs | Realistic mistakes put in on purpose; every layer is scored on which it catches | `R/mutants/` |
| AI code review test | A fresh AI agent reads the definition and one unlabeled build and reports any deviation; two rounds, with and without code comments | `ai_review/` |
| Saved snapshot | Fingerprint of the approved output; later changes upstream are flagged | `logs/snapshots/` |
| Run and change logs | Every run recorded automatically; every change after the plan logged with its reason | `logs/runs/`, `logs/changes.csv` |

The person holds the judgment calls (what the measure should capture, which precedent
to follow, what a result means). The checks handle what can be checked.

## How to run

Requirements: R (>= 4.1) with `data.table` and `jsonlite`; Python 3 with `pandas`.

```bash
# made-up data, to test everything end to end
Rscript tests/make_fixtures.R
Rscript data/make_synthetic.R
Rscript R/mutants/make_mutants.R
python3 python/new_classes_blind.py --patent-class data/synthetic/patent_class.csv \
    --firm-year data/synthetic/firm_year.csv --out data/synthetic/out_blind.csv
Rscript tests/run_all_checks.R          # writes report/catch_matrix.csv and a run record

# one worked case, walked through the code (the prototype's hand-check, decision D09)
Rscript handcheck/walkthrough.R <patent_class.csv> <firm_year.csv> [blind_output.csv]

# random hand-check, kept for Stage 2 (100 random + 10 tricky by default; handcheck/HOW_TO.md)
Rscript handcheck/make_worksheet.R <patent_class.csv> <firm_year.csv>
# ...fill in handcheck/sheets/<source>_<date>_answers_TO_FILL.csv by hand (can be done in sittings), then:
Rscript handcheck/compare_handcheck.R handcheck/sheets/<source>_<date>_answers_TO_FILL.csv <patent_class.csv> <firm_year.csv>
```

The worksheet in `handcheck/sheets/synthetic_*` is an example on made-up data. The two
comparison files marked `_TOOLTEST` come from a script filling that sheet (one with a planted
wrong answer) to test the hand-check scripts; they are not hand-checks.

### Real data

Inputs are public: PatentsView bulk tables (`g_patent`, `g_application`, `g_cpc_current`) and
DISCERN 2.0.1's `csv_files` (Arora et al. 2024, https://zenodo.org/records/13619821). Put the three
PatentsView zips in one folder with DISCERN's csv files in a `discern/` subfolder, then:

```bash
Rscript data/prepare_real.R <raw_dir> A          # writes data/real/A/ (about 3 minutes, 5 GB memory)
python3 python/new_classes_blind.py --patent-class data/real/A/patent_class.csv \
    --firm-year data/real/A/firm_year.csv --out data/real/A/out_blind.csv
Rscript tests/run_all_checks.R data/real/A/patent_class.csv data/real/A/firm_year.csv \
    data/real/A/out_blind.csv logs/snapshots/new_classes_real_A.txt report/catch_matrix_real_A.csv
Rscript handcheck/make_worksheet.R data/real/A/patent_class.csv data/real/A/firm_year.csv   # 100 random + 10 tricky
```

`A` and `B` are two rules for which firm owns a patent (decision D11 in `logs/decisions.csv`).
`data/compare_links.R` compares the public links with an independent build of the same links
(the researcher's own pipeline, which uses licensed data); only the counts are kept, in `report/`.

## Not in this repository

The researcher's own paper-specific prompts, data choices and licensed data (e.g., Compustat).
