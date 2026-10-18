# Measure specification: new technology classes

Version 0.1 (draft, 18 Oct 2026). Decisions are logged in `logs/decisions.csv`.
This file is the only input the blind rebuild sees.

## In one sentence

For each firm and focal year *t*, the number of distinct technology classes in
which the firm files patents in years *t*+1 to *t*+3 that do not appear among the
classes of the patents it filed in years *t*-5 to *t*-1.

## Inputs

**`patent_class`**: one row per patent x classification code, with columns:

| column | meaning |
|---|---|
| `patent_id` | patent number (text) |
| `firm_id` | firm identifier (text). A patent owned by several firms appears once per firm. |
| `filing_year` | year the application was filed (integer) |
| `grant_year` | year the patent was granted (integer). **Not used by the measure.** |
| `cpc_seq` | order of the code on the patent; 0 = first-listed (integer) |
| `cpc_subclass` | CPC subclass, four characters, e.g. `H04L` (text; may be missing) |

The file may contain exact duplicate rows. They must not change the result.

**`firm_year`**: the firm-years to produce, one row per (`firm_id`, `year`).

## Rules

1. **Dating.** A patent belongs to the year it was filed (`filing_year`), never the grant year.
2. **Class of a patent.** The CPC subclass of its first-listed code (`cpc_seq == 0`).
   Setting `first_listed_only = FALSE` uses every code on the patent instead (robustness only).
3. **Missing class.** A patent whose class is missing contributes no class. Missing is never a class.
4. **Base set** B(i, t): the distinct classes of firm *i*'s patents filed in years *t*-5 to *t*-1, inclusive.
5. **Forward set** F(i, t): the distinct classes of firm *i*'s patents filed in years *t*+1 to *t*+3, inclusive.
6. **Year *t* itself** belongs to neither window.
7. **Measure.** `new_classes` = the number of classes in F(i, t) that are not in B(i, t).
8. **Empty base.** If B(i, t) is empty, `new_classes` is missing (NA). It is never 0 and never |F|.
9. **No forward patents.** If B(i, t) is not empty and F(i, t) is empty, `new_classes` = 0.
10. **Firms are separate.** Firm *i*'s result depends only on firm *i*'s patents.
11. **Output.** Exactly one row per distinct (`firm_id`, `year`) in `firm_year`; repeated rows in
    `firm_year` are collapsed to one. Columns: `firm_id`, `year`, `n_base_classes` (= |B|, 0 when empty),
    `n_forward_classes` (= |F|), `new_classes`. *(Clarified 18 Oct 2026, change C01: the blind rebuild
    showed the earlier wording "one row per row of firm_year" could be read as keeping repeats.)*

## Settings (defaults)

| setting | default | logged decision |
|---|---|---|
| `base_years` | 5 | D04 |
| `forward_years` | 3 | D04 |
| `first_listed_only` | TRUE | D03 |
| focal years | 1987-2015 | D06 |

## Rules the output must always obey (checked in `tests/rules.R`)

- Duplicating input rows, or shuffling them, changes nothing.
- Adding a forward-window patent in a class already in the base changes nothing.
- Adding a forward-window patent in a class in neither set raises `new_classes` by exactly 1 (when the base is not empty).
- Adding a patent filed in year *t* changes nothing for focal year *t*.
- Removing another firm's patents changes nothing for this firm.
- `new_classes` is NA exactly when `n_base_classes` is 0.
- 0 <= `new_classes` <= `n_forward_classes`.
- Output has exactly one row per firm-year.
