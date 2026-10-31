# AI code-review test

This test asks whether an AI reviewer, given the definition and one version of the code, can tell
whether that version follows the definition. It was run on 25 Oct 2026 with definition version 0.1,
when the forward window was *t*+1 to *t*+3. Its folders keep the versions the reviewers saw. Since
30 Oct (change C13) the forward window is *t* to *t*+2, so bug M6 in this test ("forward window
shifted to *t* to *t*+2") is now the correct rule, and the current M6 is the old rule.

## How it was run

- Eleven versions were reviewed: the correct fast version and the ten copies with a deliberate bug
  (`R/mutants/`).
- Each version was copied into a folder with a random name, and `key.csv` records which folder
  holds which version. In every copy the function has the same name, and the lines that named or
  gave away the bug were removed: the bug's label, a leftover line in M4 (`pc <- pc`) and a comment
  in M5. Each reviewer saw one folder with two files, `spec.md` (the definition) and `build.R` (the
  code).
- Each version went to a fresh AI agent, told to read only those two files, not to run any code,
  and to report every place where the code departs from the definition, with the line number. The
  prompt said the code "may be correct or may contain one or more deviations." The exact prompt is
  in `prompt.txt`.
- In round 1 the reviewers saw the code as written, comments included. Two Claude models reviewed
  it: Opus and Haiku.
- In round 1 some reviewers pointed to a comment that disagreed with the line below it. So in
  round 2 every comment was removed, and Haiku reviewed the code again.

## Results (`results.csv`)

| Round | Reviewer | Deliberate bugs found | Correct version passed |
|---|---|---|---|
| 1, with comments | Claude Opus (the session's model) | 10 of 10, right line and rule | yes |
| 1, with comments | Claude Haiku | 10 of 10, right line and rule | yes |
| 2, no comments | Claude Haiku | 10 of 10, right line and rule | yes |

## What the results mean

Every reviewer found every bug at the right line and passed the correct version, with or without
comments. Each of these bugs is a single line that contradicts a single rule of a precise
definition, and a careful reader who compares the two finds that kind of bug. So these ten bugs
can't tell reviewers or model generations apart.

The errors that got through in practice were a different kind. The duplicated firm-years in the
evidence record (E01) began in a different file, and an AI audit of the later code had praised the
step that hid them. Stage 2 needs deliberate bugs of that kind: bugs that start upstream, are
spread across files, show only in the data, or come from a definition that can be read two ways.

All the reviewers were Claude models, the same family that wrote the code, and models from one
family can share blind spots (Knight & Leveson 1986). In the prototype, the checks that don't rely
on a model's reading (data checks, fake firms, input tests, deliberate bugs) guard against that.
Stage 2 adds a reviewer from another model family.
