# Definition: new technology classes

Version 0.2, 30 Oct 2026. Version 0.1 (18 Oct) said the same thing in terser language, and no rule
changed in the rewrite (change C12). The blind rebuild in `python/` was written from version 0.1
alone, without seeing any other file.

Every choice in this definition is a numbered decision (D01 to D15) in the decision log,
`logs/decisions.csv`. Each row there records the options considered, the choice, the reason, the
published precedent and who decided.

## The measure in one sentence

For each firm and focal year *t*, count the technology classes in which the firm filed patents
during *t*+1 to *t*+3 that do not appear among the classes of the patents it filed during *t*-5
to *t*-1.

## An example

A firm filed four patents: one in 1997 in class A01B, one in 1999 in B01C, one in 2001 in B01C and
one in 2002 in C01D. For focal year 2000:

- The base window is 1995 to 1999. Its classes are A01B and B01C.
- The forward window is 2001 to 2003. Its classes are B01C and C01D.
- C01D is the only forward class missing from the base, so `new_classes` = 1.

This is fake firm F01 in `tests/fixtures/`.

## Input files

**`patent_class`** has one row for each patent and each classification code on it. A patent with
three CPC codes has three rows.

| Column | What it holds |
|---|---|
| `patent_id` | Patent number (text) |
| `firm_id` | Firm identifier (text). A patent owned by two firms appears once for each firm. |
| `filing_year` | Year the patent application was filed (whole number) |
| `grant_year` | Year the patent was granted (whole number). The measure does not use it. |
| `cpc_seq` | Position of the code on the patent: 0 for the first code listed, 1 for the second, and so on (whole number). The patent office lists first the code that best describes the invention. |
| `cpc_subclass` | The first four characters of the code, called the CPC subclass. For example, the code `H04L 9/32` has subclass `H04L`. Text, and it can be blank. |

The file can contain rows that are exact copies of each other. They must not change the result.

**`firm_year`** lists the firm-years to compute, one row for each firm and focal year (`firm_id`, `year`).

## Rules

1. **Which year a patent belongs to.** The year it was filed (`filing_year`), never the year it
   was granted.
2. **A patent's class.** Each patent has one class: the CPC subclass of the first code listed on
   it (the row with `cpc_seq` = 0). For a robustness check, the setting `first_listed_only = FALSE`
   uses every code on the patent.
3. **Missing class.** A patent whose class is blank adds no class. A blank is never counted as a class.
4. **Base set.** B(i, t) is the set of distinct classes among firm *i*'s patents filed from *t*-5
   to *t*-1, both years included.
5. **Forward set.** F(i, t) is the set of distinct classes among firm *i*'s patents filed from
   *t*+1 to *t*+3, both years included.
6. **Year *t* itself.** Patents filed in year *t* belong to neither set.
7. **The measure.** `new_classes` is the number of classes in F(i, t) that are not in B(i, t).
8. **Empty base.** If B(i, t) is empty, `new_classes` is missing (NA). It is never set to 0 or to
   the size of F.
9. **No forward patents.** If B(i, t) has classes and F(i, t) is empty, `new_classes` is 0.
10. **Firms are separate.** Firm *i*'s result depends only on firm *i*'s own patents.
11. **Output.** One row for each distinct (`firm_id`, `year`) pair in `firm_year`. If `firm_year`
    lists the same pair twice, the output still has one row for it. The columns are `firm_id`,
    `year`, `n_base_classes` (the number of classes in B, 0 when B is empty), `n_forward_classes`
    (the number of classes in F) and `new_classes`. This rule was reworded on 18 Oct 2026 (change
    C01), because the earlier wording, "one row per row of firm_year", could be read as keeping
    repeated rows, and the blind rebuild read it that way.

## Settings

| Setting | Default | Decision |
|---|---|---|
| `base_years`, the length of the base window | 5 | D04 |
| `forward_years`, the length of the forward window | 3 | D04 |
| `first_listed_only`, count only the first code on each patent | TRUE | D03 |
| Focal years | 1987 to 2015 | D06 |

## How the input tests check these rules

The input tests T1 to T10 (`tests/input_tests.R`) change the input on purpose and check that the
output responds the way the rules above say it should. Tests T3 to T6 run on 25 randomly drawn
firm-years whose base is not empty.

| Test | Change to the input | Expected result | Rule |
|---|---|---|---|
| T1 | Every patent row duplicated | Output unchanged | Input note above |
| T2 | Patent rows shuffled | Output unchanged | Input note above |
| T3 | A patent added in year *t*+1 in a class already in the base | `n_base_classes` and `new_classes` unchanged | 4, 7 |
| T4 | A patent added in year *t*+2 in a class in neither set | `n_forward_classes` and `new_classes` each go up by 1 | 5, 7 |
| T5 | A patent added in year *t* | Output unchanged | 6 |
| T6 | Every other firm's patents removed | This firm's results unchanged | 10 |
| T7 | None | `new_classes` is missing exactly when `n_base_classes` is 0 | 8 |
| T8 | None | `new_classes` is between 0 and `n_forward_classes` | 7 |
| T9 | None | One output row per firm-year | 11 |
| T10 | 50 firm-year rows repeated in `firm_year` | Output unchanged | 11 |
