# Hand-check

**For the prototype (decision D09): one worked case.** Run

```bash
Rscript handcheck/walkthrough.R data/real/A/patent_class.csv data/real/A/firm_year.csv data/real/A/out_blind.csv
```

It picks one real firm-year and writes `handcheck/results/walkthrough_<firm>_<year>.md`: the
firm's raw patents, then each rule of the definition applied in turn, with a box to tick at each
step. Read it next to `R/new_classes_slow.R` and `spec/new_classes.md`. The three builds'
answers come last, so your own count comes first. About 10 minutes.

**For Stage 2: the random hand-check below.** It is kept as a tool, not part of the prototype.

---

## Random hand-check (Stage 2): how to fill in the sheet

You get two files in `handcheck/sheets/`:

- `<date>_patents.csv`: for each case, every patent the firm filed from *t*-6 to *t*+4,
  with its filing year and first-listed CPC subclass. **The windows are not marked on purpose.**
- `<date>_answers_TO_FILL.csv`: one row per case, with blank columns for you.

The code's answers are not in either file. Don't run the code before you finish.

## For each case (focal year *t*)

1. Filter the patents file to the case (`case_id`). Sort by `filing_year`.
2. **Base window** = patents filed *t*-5 to *t*-1. Count the distinct subclasses.
   A blank subclass is not a class. Put the count in `your_base_classes`.
3. **Forward window** = patents filed *t*+1 to *t*+3. Count the distinct subclasses.
   Put it in `your_forward_classes`.
4. Patents filed in year *t* itself, in *t*-6, or in *t*+4 belong to **neither** window.
5. `your_new_classes` = the forward subclasses that are not among the base subclasses.
   If the base window has no class at all, write `NA`.
6. **Source check.** Open the patent in `source_patent` on Google Patents (link in the
   patents file). Fill Y or N:
   - `source_filing_year_ok`: the application filing year matches `filing_year`.
   - `source_owner_ok`: the assignee is this firm or a unit of it.
   - `source_subclass_present`: the `first_listed_subclass` appears among the patent's CPC codes.
     (Google Patents does not mark which code is "first", so this checks presence only.)
7. `minutes`: roughly how long the case took. `notes`: anything odd.

For big firms, a spreadsheet is fine: filter by year range, then use UNIQUE (or Remove
Duplicates) on the subclass column. That is still independent of the code.

## When done

```bash
Rscript handcheck/compare_handcheck.R handcheck/sheets/<date>_answers_TO_FILL.csv <patent_class.csv> <firm_year.csv>
```

It reports matches, lists every mismatch, and writes a run record. With zero mismatches
in *n* random cases, the error rate is below about 3/*n* (95% confidence; rule of three):

| random cases checked | error rate ruled out above |
|---|---|
| 20 | 15% |
| 50 | 6% |
| 100 | 3% |
| 150 | 2% |

A mismatch is not automatically a code error: first decide whether the code, the sheet,
or the person was wrong, and log it in `logs/changes.csv` if anything changes.
Tricky cases are reported separately and do not count toward the bound.
