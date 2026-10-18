# First run on real data (18 Oct 2026)

Inputs: public PatentsView tables and DISCERN 2.0.1, prepared by `data/prepare_real.R` with link
rule A (decision D11, pending). Counts at each step: `report/real_prep_log_A.csv`.

## The data

- 1,738,450 granted utility patents filed 1982-2018, linked to 5,420 DISCERN firms (GVKEY);
  8,552 patents belong to more than one firm and count for each.
- 630 distinct first-listed CPC subclasses. No first-listed code falls in the CPC Y section
  (tagging codes), but the all-codes robustness version would include Y codes.
- 157,180 firm-years (every year 1987-2015 for each firm, decision D08). 62% have an empty base and
  so no value; within DISCERN's public firm panel (65,799 firm-years) 27% do (decision D15, pending).

## Linkage check

The public links were compared with the researcher's own DISCERN pipeline, which uses licensed
Compustat data (`data/compare_links.R`, counts in `report/link_agreement_*.csv`):

| Rule | Same firm(s) as the pipeline | Notes |
|---|---|---|
| A | 99.8% of patents | 100% where DISCERN has the official owner at filing |
| B | 89.0% of patents | DISCERN's own grant-year owner |

The comparison script's first run reported 90% disagreement. That was implausible, and the cause
was GVKEY stored as a number in one build and as text in the other (change C05).

## Check layers on the real data

`report/catch_matrix_real_A.csv`. The correct build passes every layer: the fast build, the slow
plain build and the blind Python rebuild agree on all 157,180 firm-years.

Planted bugs, real data vs made-up data:

- **9 of 10 caught**, each by 3 to 5 layers.
- **M9 (class cut to three characters)** was caught only by the fake firms on the made-up data.
  On the real data it is also caught by the slow build and the blind rebuild, because real CPC
  subclasses share first three characters (e.g., A01B and A01C).
- **M1 (repeated firm-years not collapsed) is not caught, and cannot be on this data.** The real
  firm-year list has no repeated rows, so the bug changes nothing. It is caught on the made-up
  data, which has repeats on purpose. A bug that only shows when the input has a defect is
  invisible on clean input; a rule that repeats firm-year rows on purpose would catch it on any data.
- **M10 (base window shifted one year)** again slips past the fake firms and is caught by the
  rules, the slow build and the blind rebuild.

## Run time

About 3 minutes to prepare the data (5 GB memory), 11 seconds for the blind rebuild, and about
22 minutes for all check layers before change C06.
