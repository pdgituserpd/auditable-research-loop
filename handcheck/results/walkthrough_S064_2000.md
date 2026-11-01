# Manual verification: firm S064, focal year 2000

Read this next to the slow version (`R/new_classes_slow.R`) and the definition (`spec/new_classes.md`). Count each step yourself, and tick its box when your count agrees.

Patents are linked to the firm by rule A (decision D11). Each patent number links to the patent's page on Google Patents, so you can check any of them against the source.

## Step 0. Every code on every patent the firm filed from 1994 to 2003

`cpc_seq` is the code's position on the patent: 0 for the first code listed, 1 for the second, and so on.

| patent | filing_year | grant_year | cpc_seq | cpc_subclass |
| --- | --- | --- | --- | --- |
| [X0003256](https://patents.google.com/patent/USX0003256) | 1999 | 2000 | 0 | G03F |
| [X0003256](https://patents.google.com/patent/USX0003256) | 1999 | 2000 | 1 | A07B |
| [X0003257](https://patents.google.com/patent/USX0003257) | 1999 | 2001 | 0 | A11B |
| [X0003258](https://patents.google.com/patent/USX0003258) | 1999 | 2002 | 0 | G06F |
| [X0003259](https://patents.google.com/patent/USX0003259) | 2000 | 2004 | 0 | G03F |
| [X0003259](https://patents.google.com/patent/USX0003259) | 2000 | 2004 | 1 | G14F |
| [X0003260](https://patents.google.com/patent/USX0003260) | 2000 | 2001 | 0 | G03F |
| [X0003260](https://patents.google.com/patent/USX0003260) | 2000 | 2001 | 1 | A04B |
| [X0003260](https://patents.google.com/patent/USX0003260) | 2000 | 2001 | 2 | G14F |
| [X0003261](https://patents.google.com/patent/USX0003261) | 2000 | 2003 | 0 | G09F |
| [X0003262](https://patents.google.com/patent/USX0003262) | 2000 | 2004 | 0 | G03F |
| [X0003262](https://patents.google.com/patent/USX0003262) | 2000 | 2004 | 1 | A13B |
| [X0003263](https://patents.google.com/patent/USX0003263) | 2000 | 2002 | 0 | H02L |
| [X0003263](https://patents.google.com/patent/USX0003263) | 2000 | 2002 | 1 | A09B |
| [X0003264](https://patents.google.com/patent/USX0003264) | 2000 | 2004 | 0 | A02B |
| [X0003265](https://patents.google.com/patent/USX0003265) | 2001 | 2005 | 0 | A11B |
| [X0003266](https://patents.google.com/patent/USX0003266) | 2001 | 2005 | 0 | A11B |
| [X0003267](https://patents.google.com/patent/USX0003267) | 2001 | 2004 | 0 | G03F |
| [X0003267](https://patents.google.com/patent/USX0003267) | 2001 | 2004 | 1 | A15B |
| [X0003268](https://patents.google.com/patent/USX0003268) | 2002 | 2003 | 0 | G13F |
| [X0003269](https://patents.google.com/patent/USX0003269) | 2002 | 2006 | 0 | H02L |
| [X0003269](https://patents.google.com/patent/USX0003269) | 2002 | 2006 | 1 | G13F |
| [X0003269](https://patents.google.com/patent/USX0003269) | 2002 | 2006 | 2 | A12B |
| [X0003270](https://patents.google.com/patent/USX0003270) | 2002 | 2006 | 0 | G03F |
| [X0003270](https://patents.google.com/patent/USX0003270) | 2002 | 2006 | 1 | G10F |
| [X0003270](https://patents.google.com/patent/USX0003270) | 2002 | 2006 | 2 | A13B |
| [X0003271](https://patents.google.com/patent/USX0003271) | 2003 | 2006 | 0 | A11B |
| [X0003272](https://patents.google.com/patent/USX0003272) | 2003 | 2004 | 0 | A14B |
| [X0003272](https://patents.google.com/patent/USX0003272) | 2003 | 2004 | 1 | H06L |

## Step 1. Rule 2: keep only each patent's first code (cpc_seq = 0)

- [ ] 29 rows become 17 rows, one per patent.

## Step 2. Rule 3: drop rows with a blank class

- [ ] 0 row(s) dropped, 17 left.

## Step 3. Rule 4: base window, patents filed 1995 to 1999

| patent_id | filing_year | cpc_subclass |
| --- | --- | --- |
| X0003256 | 1999 | G03F |
| X0003257 | 1999 | A11B |
| X0003258 | 1999 | G06F |

- [ ] Base set B = {A11B, G03F, G06F}, 3 classes.

## Step 4. Rules 5 and 6: forward window, patents filed 2000 to 2002 (year 2000 included)

| patent_id | filing_year | cpc_subclass |
| --- | --- | --- |
| X0003259 | 2000 | G03F |
| X0003260 | 2000 | G03F |
| X0003261 | 2000 | G09F |
| X0003262 | 2000 | G03F |
| X0003263 | 2000 | H02L |
| X0003264 | 2000 | A02B |
| X0003265 | 2001 | A11B |
| X0003266 | 2001 | A11B |
| X0003267 | 2001 | G03F |
| X0003268 | 2002 | G13F |
| X0003269 | 2002 | H02L |
| X0003270 | 2002 | G03F |

- [ ] Forward set F = {A02B, A11B, G03F, G09F, G13F, H02L}, 6 classes.

## Step 5. Patents filed in 1994 and 2003 belong to neither window

| patent_id | filing_year | cpc_subclass |
| --- | --- | --- |
| X0003271 | 2003 | A11B |
| X0003272 | 2003 | A14B |

- [ ] None of these rows appears in Step 3 or Step 4.

## Step 6. Rule 7: classes in F that are not in B

- [ ] New = {A02B, G09F, G13F, H02L}, so **new_classes = 4**.

## Step 7. What the three versions report (read this after your own count)

| version | n_base_classes | n_forward_classes | new_classes |
| --- | --- | --- | --- |
| slow version (R) | 3 | 6 | 4 |
| fast version (R) | 3 | 6 | 4 |

- [ ] Your count in Step 6 matches all three.

