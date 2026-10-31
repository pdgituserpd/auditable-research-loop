# Auditable research loop: prototype

This repository is the prototype for a Stage 1 proposal to the Organization Science special
issue "AI-Enabled Frontiers in Organizational Science." It stays private until the proposal is
submitted.

## What this is

In the research process this prototype comes from, AI agents build the variables and run the
models, and the researcher makes the judgment calls: which question to ask, what each variable
should capture, and what a result means. No procedure can "prove" that research code is correct.
So the aim here is measured assurance: several checks that fail in different ways, a count of
what each check catches, and a written record of every decision the researcher made.

The prototype runs every check on one variable from innovation research, **new technology
classes**. For each firm and year *t*, it counts the technology classes in which the firm filed
patents during *t*+1 to *t*+3 that do not appear among its patents filed during *t*-5 to *t*-1.
The full definition, with an example, is in [`spec/new_classes.md`](spec/new_classes.md). The data
are public: patents and their classes from PatentsView, and the links from patents to publicly
traded firms from DISCERN 2.0.

## What each folder holds

| Folder | Contents |
|---|---|
| `spec/` | The definition of the measure in plain words: 11 numbered rules |
| `R/` | The two R versions of the measure (fast and slow), the data checks, the code that writes the run log, and `R/mutants/`, which holds ten copies of the fast version with one deliberate bug each |
| `python/` | The blind rebuild: the measure written in Python from the definition alone |
| `tests/` | The fake firms, the input tests T1 to T10, and `run_all_checks.R`, which runs every check on the correct version and on each deliberate bug |
| `data/` | Scripts that build the input files from the public downloads, a script that compares the patent-to-firm links with the researcher's own pipeline, and a small made-up dataset for trying everything out |
| `handcheck/` | The one worked case for the researcher, and a tool for a larger random hand-check kept for later |
| `ai_review/` | A test of whether an AI reviewer reading the code can find the deliberate bugs |
| `logs/` | The decision log, the change log, a record of every run, and the saved checksums of approved outputs |
| `report/` | Results: which check caught which bug, how well the patent-to-firm links agree, and row counts at each data step |

## The checks

| Check | What it does | Where |
|---|---|---|
| Decision log | Every choice the definition leaves open (which year a patent belongs to, the window lengths, what to do when the base window is empty, and so on) is written down with the options, the choice, the reason, the published precedent and who decided. The decisions are numbered D01 to D15 | `logs/decisions.csv` |
| Data checks | Six checks on the finished table: each firm-year appears once, the number of rows matches the firm-years requested, there are no negative or infinite values, the value is missing exactly when the base window is empty, and the count never exceeds the number of forward classes | `R/checks.R` |
| Three versions that must agree | The **fast version** in R is the one a paper would use. It handles all firms at once with table joins, which is quick but hard to read. The **slow version** in R goes one firm-year at a time and follows the definition line by line, so a person can read it against the rules. The **blind rebuild** in Python was written by a separate AI agent (a Claude model) from the definition alone, without seeing the R code. All three must give the same answer for every firm-year | `R/new_classes_fast.R`, `R/new_classes_slow.R`, `python/new_classes_blind.py` |
| Fake firms | 15 invented firms with one to six made-up patents each. Each firm tests one tricky case, such as the window edges, duplicate rows, a patent with several codes or a patent owned by two firms. Their correct answers were worked out from the definition before any version was run | `tests/make_fixtures.R`, `tests/fixtures/` |
| Input tests T1 to T10 | Each test changes the input on purpose in a way whose effect is known in advance (duplicating every row, adding a patent filed in year *t*, deleting other firms' patents) and checks that the output responds exactly as the definition says. The definition lists all ten | `tests/input_tests.R` |
| One worked case | The researcher takes one real firm-year through the slow version and the definition step by step, counting first and seeing the three versions' answers last (decision D09). A random hand-check of 100 or more cases is kept as a tool for later | `handcheck/` |
| Deliberate bugs | Ten realistic mistakes (M1 to M10), each put into a copy of the fast version. Every check runs on every copy, and a results table shows which check caught which bug | `R/mutants/`, `report/catch_matrix_real_A.csv` |
| AI code review test | A fresh AI agent reads the definition and one unlabeled version and reports any line that breaks a rule. Both reviewers were Claude models, so this prototype does not test independence across model families | `ai_review/` |
| Saved checksum | A 32-character code (an MD5 checksum) computed from every value in the approved output table. Any change to any value gives a different code. A later run whose output differs from the approved one is flagged, even when every other check passes | `logs/snapshots/` |
| Run and change logs | Every run writes a record automatically: the time, the code version, the R version, the settings, a checksum of each input file, every check with its result, and a checksum of each output. Every change made after the plan goes in the change log with its reason, numbered from C01 | `logs/runs/`, `logs/changes.csv` |

## Results on the real data

The real-data build has 1,738,450 patents filed from 1982 to 2018, 5,420 firms and 157,180
firm-years. The three versions agree on every firm-year. The patent-to-firm links match the
researcher's own pipeline, which uses licensed data, for 99.8% of patents. All ten deliberate bugs
were caught: nine by four to six of the six coded checks, and M1 by input test T10 alone. The
details are in [`report/real_data_notes.md`](report/real_data_notes.md).

## How to run it

You need R 4.1 or later with the `data.table` and `jsonlite` packages, and Python 3 with `pandas`.
Run every command from the repository folder.

On the made-up data, which takes about a minute and needs no downloads:

```bash
Rscript tests/make_fixtures.R          # the fake firms
Rscript data/make_synthetic.R          # the made-up dataset
Rscript R/mutants/make_mutants.R       # the ten deliberate bugs
python3 python/new_classes_blind.py --patent-class data/synthetic/patent_class.csv \
    --firm-year data/synthetic/firm_year.csv --out data/synthetic/out_blind.csv
Rscript tests/run_all_checks.R         # writes report/catch_matrix.csv and a run record
```

On the real data, put the three PatentsView downloads (`g_patent`, `g_application` and
`g_cpc_current`, as zip files) in one folder, with DISCERN 2.0.1's `csv_files` (Arora et al. 2024,
https://zenodo.org/records/13619821) in a subfolder named `discern/`. Then:

```bash
Rscript data/prepare_real.R <download_folder> A    # writes data/real/A/ (about 3 minutes, 5 GB of memory)
python3 python/new_classes_blind.py --patent-class data/real/A/patent_class.csv \
    --firm-year data/real/A/firm_year.csv --out data/real/A/out_blind.csv
Rscript tests/run_all_checks.R data/real/A/patent_class.csv data/real/A/firm_year.csv \
    data/real/A/out_blind.csv logs/snapshots/new_classes_real_A.txt report/catch_matrix_real_A.csv
```

The letter `A` or `B` picks the rule for deciding which firm owns a patent (decision D11). Rule A
takes the owner when the application was filed. Rule B takes the owner that DISCERN's grant file
records when the patent was granted. `data/compare_links.R` compares the links with the
researcher's own pipeline and keeps only the counts, in `report/`.

The worked case, and the random hand-check kept for later, are explained in
[`handcheck/HOW_TO.md`](handcheck/HOW_TO.md):

```bash
Rscript handcheck/walkthrough.R data/real/A/patent_class.csv data/real/A/firm_year.csv data/real/A/out_blind.csv
```

## What is left out

- The real data. It runs to hundreds of megabytes, and `data/prepare_real.R` rebuilds it from the
  public downloads in about three minutes.
- Licensed data such as Compustat, and anything built from it. The link comparison keeps only counts.
- The researcher's own pipeline, prompts and paper code.
