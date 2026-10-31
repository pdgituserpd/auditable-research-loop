# Guide to every file

This page explains what each folder and file in the repository holds. Start with
[`README.md`](README.md) for what the prototype is and [`spec/new_classes.md`](spec/new_classes.md)
for the definition of the measure.

Two words used throughout:
- **Made-up data** (`synthetic` in file names) is a small invented dataset, so anyone can run every
  check in about a minute without downloading anything.
- **Real data** (`real` in file names) is built from the public PatentsView and DISCERN 2.0 downloads.
  `_A` and `_B` in a file name mark the rule for deciding which firm owns a patent (decision D11).
  Rule A is the one used. Rule B is kept as a robustness check.

## Top level

| File | What it is |
|---|---|
| `README.md` | Front page: what the prototype is, the list of checks, results, how to rerun everything |
| `FILES.md` | This guide |
| `.gitignore` | Tells Git which files to leave out of the repository (the real data, which the scripts rebuild, and hand-check worksheets in progress) |

## `spec/`: the definition

| File | What it is |
|---|---|
| `new_classes.md` | The measure in plain words: an example, the input files, the 11 rules, the settings, and the input tests T1 to T11 with the rule each one checks. The blind rebuild was written from this file alone |

## `R/`: the measure and the checks, in R

| File | What it is |
|---|---|
| `new_classes_fast.R` | The fast version of the measure, the one a paper would use. It handles all firms at once with table joins |
| `new_classes_slow.R` | The slow version. It goes one firm-year at a time and follows the definition line by line, with each line labeled by its rule number. This is the version the researcher reads in the worked case |
| `checks.R` | The six data checks on the finished table (one row per firm-year, row count, no negative or infinite values, missing exactly when the base is empty, never more new classes than forward classes) |
| `runlog.R` | Writes a record of every run to `logs/runs/`, including checksums of the input and output files |
| `io.R` | Reads the input files with fixed column types, and compares two outputs firm-year by firm-year |
| `mutants/` | The ten deliberate bugs. `M1.R` to `M10.R` are each a copy of the fast version with one realistic mistake. `index.csv` names each bug and what it is modeled on. `make_mutants.R` writes the ten copies from the fast version |

## `python/`: the blind rebuild

| File | What it is |
|---|---|
| `new_classes_blind.py` | The measure written in Python by a separate AI agent that saw only the definition, never the R code. It must agree with both R versions on every firm-year |

## `tests/`: the fake firms and the input tests

| File | What it is |
|---|---|
| `make_fixtures.R` | Writes the fake firms: 15 invented firms with one to six made-up patents each, one tricky case per firm, with the correct answers worked out from the definition by hand |
| `fixtures/fake_patent_class.csv` | The fake firms' patents |
| `fixtures/fake_firm_year.csv` | The firm-years to compute for the fake firms |
| `fixtures/fake_expected.csv` | The hand-worked correct answers, with a label for the case each firm tests |
| `input_tests.R` | The input tests T1 to T11. Each changes the input on purpose and checks that the output responds as the definition says (listed in the definition) |
| `run_all_checks.R` | Runs every check on the correct fast version and on each of the ten deliberate bugs, and writes the results table (the "catch matrix") and a run record |

## `data/`: building the inputs

| File | What it is |
|---|---|
| `prepare_real.R` | Builds the two input files from the public PatentsView and DISCERN 2.0 downloads (about 3 minutes). Its comments mark the one step where it differs from the researcher's own pipeline |
| `compare_links.R` | Compares the public patent-to-firm links with the researcher's own pipeline, which uses licensed Compustat data. It writes only counts |
| `make_synthetic.R` | Writes the made-up dataset, including duplicate rows, blank classes and co-owned patents on purpose |
| `synthetic/patent_class.csv`, `synthetic/firm_year.csv` | The made-up input files |
| `synthetic/out_blind.csv` | The blind rebuild's answers on the made-up data |

## `handcheck/`: the researcher's manual check

| File | What it is |
|---|---|
| `HOW_TO.md` | Instructions for the worked case and for the larger random hand-check kept for later |
| `walkthrough.R` | Picks one real firm-year and writes the worked case: every patent, each rule applied in turn with a box to tick, and the three versions' answers last |
| `results/walkthrough_<firm>_<year>.md` | The worked case for the researcher to go through |
| `make_worksheet.R`, `compare_handcheck.R` | The random hand-check tool kept for Stage 2: one script draws the cases and writes a sheet to fill in, the other scores the filled sheet against the code |
| `sheets/synthetic_2026-10-18_*.csv` | An example sheet built from the made-up data |
| `results/*_TOOLTEST.csv` | Tests of the scoring script with a machine-filled sheet (one with a planted wrong answer). They contain no one's hand-check |

## `ai_review/`: the AI code-review test

| File | What it is |
|---|---|
| `README.md` | How the test was run and what the results mean |
| `prompt.txt` | The exact instructions each AI reviewer received |
| `key.csv` | Which randomly named folder holds which version (the correct one or bug M1 to M10) |
| `results.csv` | One row per review: the reviewer, its verdict, whether the verdict was right, and the lines and rules it flagged |
| `round1_with_comments/`, `round2_no_comments/` | One folder per version reviewed, holding the code the reviewer saw (`build.R`) and each reviewer's report (`review_*.json`). Round 2 is the same code with every comment removed |

## `logs/`: the records

| File | What it is |
|---|---|
| `decisions.csv` | The decision log: every choice the definition leaves open (D01 to D15), with the options, the choice, the reason, the published precedent, who decided and whether it is settled |
| `approvals.csv` | The researcher's one-time sign-offs that aren't decisions or changes: the planted bug list, the worked case, the saved checksums and the license, each with its date |
| `changes.csv` | The change log: every change made after the plan (C01 onward), with its class, its reason, whether it came before or after results, the two tests every change must pass, and who approved it |
| `runs/*.json` | One record per run, written automatically: time, code version, R version, settings, a checksum of each input file, every check with its result, and a checksum of each output. The file name is the run's date and time |
| `snapshots/new_classes_synthetic.txt`, `snapshots/new_classes_real_A.txt` | The saved checksum of the approved output, on the made-up data and on the real data. A checksum is a 32-character code computed from every value in the table, so any change to any value gives a different code. Each later run compares its output with it |

## `report/`: the results

| File | What it is |
|---|---|
| `catch_matrix.csv` | Which check caught which deliberate bug, on the made-up data. One row per version (the correct one first, then M1 to M10) and one column per check. TRUE means the check flagged that version. `n_layers_caught` counts the checks that caught it, and `input_tests_failed` names the input tests that failed |
| `catch_matrix_real_A.csv` | The same table on the real data (link rule A). The two tables differ because some bugs show only on one kind of data, which `real_data_notes.md` explains |
| `link_agreement_A.csv`, `link_agreement_B.csv` | How often the public patent-to-firm links give the same firm as the researcher's own pipeline, under rule A and rule B, split by the kind of link DISCERN provides |
| `real_prep_log_A.csv`, `real_prep_log_B.csv` | Row counts after each step of preparing the real data, so every dropped or added row can be traced |
| `real_data_notes.md` | A summary of the real-data runs: the data, the link check, which bugs were caught and how long everything takes |
