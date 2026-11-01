# Hand-check

## Manual verification (the prototype's hand-check, decision D09)

The prototype's hand-check is a manual verification of one real firm-year. Run this from the repository folder:

```bash
Rscript handcheck/walkthrough.R data/real/A/patent_class.csv data/real/A/firm_year.csv data/real/A/out_blind.csv
```

The script picks one real firm-year and writes `handcheck/results/walkthrough_<firm>_<year>.md`.
The file lists every patent the firm filed from six years before the focal year to three years
after it, each with a link to the patent on Google Patents. Then it applies the definition's rules
one at a time, with a box to tick at each step. Read it next to the slow version
(`R/new_classes_slow.R`) and the definition (`spec/new_classes.md`), and count each step yourself.
The three versions' answers come last, so they can't steer your count. It takes about 10 minutes.
The current case is firm 062738, focal year 1997.

## The random hand-check (kept for Stage 2)

This tool is kept for later and isn't used in the prototype. `make_worksheet.R` draws 100 random
firm-years and about 10 tricky ones, and writes two files in `handcheck/sheets/`:

- `<source>_<date>_patents.csv` lists, for each case, every patent the firm filed from *t*-6 to
  *t*+3, with its filing year and the class of its first-listed code. The windows are left
  unmarked on purpose, so a window mistake in the code can't be copied into the sheet.
- `<source>_<date>_answers_TO_FILL.csv` has one row per case, with blank columns for your answers.

Neither file contains the code's answers. Don't run the code until you finish.

### For each case (focal year *t*)

1. Filter the patents file to the case (`case_id`) and sort it by `filing_year`.
2. Base window: patents filed from *t*-5 to *t*-1. Count the distinct classes. A blank class
   doesn't count. Enter the number in `your_base_classes`.
3. Forward window: patents filed from *t* to *t*+2, year *t* included. Count the distinct classes
   and enter the number in `your_forward_classes`.
4. Patents filed in *t*-6 or in *t*+3 belong to neither window.
5. In `your_new_classes`, enter how many forward classes are missing from the base. If the base
   has no class at all, enter `NA`.
6. Check one patent against the source. Open the patent named in `source_patent` on Google Patents
   (the patents file has the link) and enter Y or N in each column:
   - `source_filing_year_ok`: the application's filing year matches `filing_year`.
   - `source_owner_ok`: the owner is this firm or one of its units.
   - `source_subclass_present`: the class in `first_listed_subclass` appears among the patent's
     CPC codes. Google Patents doesn't show which code was listed first, so this column checks
     only that the class is there.
7. In `minutes`, enter how long the case took. In `notes`, write anything odd.

For a large firm, use a spreadsheet: filter by year range, then use UNIQUE (or Remove Duplicates)
on the class column. Your count still stays separate from the code.

### When you're done

```bash
Rscript handcheck/compare_handcheck.R handcheck/sheets/<source>_<date>_answers_TO_FILL.csv <patent_class.csv> <firm_year.csv>
```

The script counts the matches, lists every mismatch and writes a run record. It scores only the
rows where all three counts are filled in, so you can do the sheet in several sittings.

With zero mismatches in *n* random cases, error rates above about 3/*n* are ruled out with 95%
confidence. This is the rule of three (Hanley & Lippman-Hand 1983).

| Random cases checked | Error rates ruled out above |
|---|---|
| 20 | 15% |
| 50 | 6% |
| 100 | 3% |
| 150 | 2% |

A mismatch can come from the code, the sheet or the person. Find which one before changing
anything, and log any change in `logs/changes.csv`. The tricky cases are reported separately and
don't count toward these limits.

### Example files

The sheet in `handcheck/sheets/synthetic_2026-10-18_*` is an example built from the made-up data.
The two files in `handcheck/results/` whose names end in `_TOOLTEST` come from a script that filled
in that sheet automatically, once correctly and once with one wrong answer planted, to test the
comparison script. They are tool tests and contain no one's hand-check.
