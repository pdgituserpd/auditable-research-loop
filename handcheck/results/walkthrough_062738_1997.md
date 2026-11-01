# Manual verification: firm 062738, focal year 1997

Read this next to the slow version (`R/new_classes_slow.R`) and the definition (`spec/new_classes.md`). Count each step yourself, and tick its box when your count agrees.

Patents are linked to the firm by rule A (decision D11). Each patent number links to the patent's page on Google Patents, so you can check any of them against the source.

## Step 0. Every code on every patent the firm filed from 1991 to 2000

`cpc_seq` is the code's position on the patent: 0 for the first code listed, 1 for the second, and so on.

| patent | filing_year | grant_year | cpc_seq | cpc_subclass |
| --- | --- | --- | --- | --- |
| [5690270](https://patents.google.com/patent/US5690270) | 1996 | 1997 | 0 | H05K |
| [5690270](https://patents.google.com/patent/US5690270) | 1996 | 1997 | 7 | H01L |
| [5690270](https://patents.google.com/patent/US5690270) | 1996 | 1997 | 33 | Y02P |
| [5690270](https://patents.google.com/patent/US5690270) | 1996 | 1997 | 34 | Y10T |
| [5818310](https://patents.google.com/patent/US5818310) | 1996 | 1998 | 0 | H03H |
| [5831494](https://patents.google.com/patent/US5831494) | 1996 | 1998 | 0 | H03H |
| [5864092](https://patents.google.com/patent/US5864092) | 1996 | 1999 | 0 | H03H |
| [5864092](https://patents.google.com/patent/US5864092) | 1996 | 1999 | 1 | H01L |
| [5864092](https://patents.google.com/patent/US5864092) | 1996 | 1999 | 10 | Y10T |
| [5866867](https://patents.google.com/patent/US5866867) | 1997 | 1999 | 0 | B23K |
| [5917265](https://patents.google.com/patent/US5917265) | 1997 | 1999 | 0 | H03H |
| [6011693](https://patents.google.com/patent/US6011693) | 1997 | 2000 | 0 | H05K |
| [6011693](https://patents.google.com/patent/US6011693) | 1997 | 2000 | 7 | H01L |
| [6011693](https://patents.google.com/patent/US6011693) | 1997 | 2000 | 33 | Y02P |
| [6011693](https://patents.google.com/patent/US6011693) | 1997 | 2000 | 34 | Y10T |
| [5905325](https://patents.google.com/patent/US5905325) | 1998 | 1999 | 0 | H03H |
| [6031315](https://patents.google.com/patent/US6031315) | 1998 | 2000 | 0 | H03H |
| [6054794](https://patents.google.com/patent/US6054794) | 1999 | 2000 | 0 | H03H |
| [6072264](https://patents.google.com/patent/US6072264) | 1999 | 2000 | 0 | H03H |
| [6097131](https://patents.google.com/patent/US6097131) | 1999 | 2000 | 0 | H03H |
| [6105226](https://patents.google.com/patent/US6105226) | 1999 | 2000 | 0 | H03H |
| [6105226](https://patents.google.com/patent/US6105226) | 1999 | 2000 | 1 | H01L |
| [6105226](https://patents.google.com/patent/US6105226) | 1999 | 2000 | 10 | Y10T |
| [6349623](https://patents.google.com/patent/US6349623) | 2000 | 2002 | 0 | B25G |

## Step 1. Rule 2: keep only each patent's first code (cpc_seq = 0)

- [ ] 24 rows become 14 rows, one per patent.

## Step 2. Rule 3: drop rows with a blank class

- [ ] 0 row(s) dropped, 14 left.

## Step 3. Rule 4: base window, patents filed 1992 to 1996

| patent_id | filing_year | cpc_subclass |
| --- | --- | --- |
| 5690270 | 1996 | H05K |
| 5818310 | 1996 | H03H |
| 5831494 | 1996 | H03H |
| 5864092 | 1996 | H03H |

- [ ] Base set B = {H03H, H05K}, 2 classes.

## Step 4. Rules 5 and 6: forward window, patents filed 1997 to 1999 (year 1997 included)

| patent_id | filing_year | cpc_subclass |
| --- | --- | --- |
| 5866867 | 1997 | B23K |
| 5917265 | 1997 | H03H |
| 6011693 | 1997 | H05K |
| 5905325 | 1998 | H03H |
| 6031315 | 1998 | H03H |
| 6054794 | 1999 | H03H |
| 6072264 | 1999 | H03H |
| 6097131 | 1999 | H03H |
| 6105226 | 1999 | H03H |

- [ ] Forward set F = {B23K, H03H, H05K}, 3 classes.

## Step 5. Patents filed in 1991 and 2000 belong to neither window

| patent_id | filing_year | cpc_subclass |
| --- | --- | --- |
| 6349623 | 2000 | B25G |

- [ ] None of these rows appears in Step 3 or Step 4.

## Step 6. Rule 7: classes in F that are not in B

- [ ] New = {B23K}, so **new_classes = 1**.

## Step 7. What the three versions report (read this after your own count)

| version | n_base_classes | n_forward_classes | new_classes |
| --- | --- | --- | --- |
| slow version (R) | 2 | 3 | 1 |
| fast version (R) | 2 | 3 | 1 |
| blind rebuild (Python) | 2 | 3 | 1 |

- [ ] Your count in Step 6 matches all three.

