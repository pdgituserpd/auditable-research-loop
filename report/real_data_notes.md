# Real-data runs (18 and 25 Oct 2026)

The inputs are public: PatentsView's patent tables and DISCERN 2.0.1, prepared by
`data/prepare_real.R` with link rule A (decision D11, waiting for the researcher's approval). The
row counts after each preparation step are in `report/real_prep_log_A.csv`.

## The data

- 1,738,450 granted utility patents filed from 1982 to 2018, linked to 5,420 DISCERN firms, which
  are identified by GVKEY. 8,552 patents belong to more than one firm and count for each owner.
- 630 distinct first-listed CPC subclasses. None of the first-listed codes is in CPC section Y,
  which holds tagging codes that cut across technologies. The robustness version that counts every
  code on a patent would include Y codes.
- 157,180 firm-years: every year from 1987 to 2015 for each firm (decision D08). 62% of them have
  an empty base window and so no value. Within the years each firm appears in DISCERN's public firm
  panel (65,799 firm-years), 27% have no value. Decision D15 keeps all the firm-years, because a
  study linked to Compustat drops the years a firm isn't publicly traded anyway.

## Link check

The public patent-to-firm links were compared with the researcher's own DISCERN pipeline, which
uses licensed Compustat data for one step (`data/compare_links.R`, with the counts in
`report/link_agreement_*.csv`).

| Rule | Patents linked to the same firm or firms as the researcher's pipeline | Notes |
|---|---|---|
| A | 99.8% | 100% where DISCERN records the owner at filing |
| B | 89.0% | Uses DISCERN's own owner at the grant year |

The first run of the comparison reported 90% of patents linked to different firms. A number that
large was too far off to accept, so it was traced. One build stored GVKEY as a number (1010) and
the other as six-character text (001010), so the same firm failed to match itself. Change C05
fixed the comparison script, and the measure itself was unaffected.

## The checks on the real data

`report/catch_matrix_real_A.csv` shows which check caught which deliberate bug. The correct version
passes every check, and the fast version, the slow version and the blind rebuild agree on all
157,180 firm-years.

Compared with the made-up data:

- All ten bugs were caught. Nine were caught by four to six of the six coded checks. The tenth,
  M1 (repeated firm-years kept), is caught only by input test T10, added on 25 Oct (change C09). On
  the first real-data run (18 Oct) every check passed M1, because the real firm-year list has no
  repeated rows, so the bug changed nothing. A bug that shows only when the input has a defect
  can't be seen on clean input. T10 repeats some firm-year rows on purpose, so it catches M1 on any
  data.
- M9 (class cut to three characters) was caught only by the fake firms on the made-up data. On the
  real data the slow version and the blind rebuild catch it too, because real CPC subclasses can
  share their first three characters (for example A01B and A01C).
- M10 (base window shifted one year) gets past the fake firms. The input tests, the slow version
  and the blind rebuild catch it.
- In the AI code review test (`ai_review/`), every reviewer found every bug at the right line and
  passed the correct version, in both rounds. These bugs are too easy to tell reviewers apart.

## Run time

Preparing the data takes about 3 minutes and 5 GB of memory. The blind rebuild takes 11 seconds.
All the checks together take about 5 minutes. They took 22 minutes before change C06, with
identical results.
