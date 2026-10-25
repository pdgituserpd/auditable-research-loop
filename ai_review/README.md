# AI code-review test

Can an AI reviewer, given the definition and one version of the build, tell whether that
version follows the definition? Run 25 Oct 2026.

## Method

- **Builds:** the correct fast build and the 10 planted bugs (`R/mutants/`), 11 versions.
- **Blinding:** each version was copied to a folder with a random name (`key.csv` maps names
  to builds). Lines that named the bug were removed, the function was given the same name in
  every copy, and two lines that would have given the bug away were dropped (M4's leftover
  `pc <- pc`, M5's comment). Each reviewer saw one folder only: `spec.md` and `build.R`.
- **Reviewers:** one fresh agent per version, told to read only those two files, not to run
  any code, and to report every deviation with its line. The code "may be correct or may
  contain one or more deviations."
- **Round 1:** code as written, comments included. Two reviewer models.
- **Round 2:** all comments removed (the round 1 reviewers often noticed that a comment and its
  line disagreed). The smaller model only.

The exact prompt is in `prompt.txt`.

## Results (`results.csv`)

| Round | Reviewer | Planted bugs found | Correct build passed |
|---|---|---|---|
| 1, with comments | Claude Opus (session model) | 10 of 10, right line and rule | yes |
| 1, with comments | Claude Haiku | 10 of 10, right line and rule | yes |
| 2, no comments | Claude Haiku | 10 of 10, right line and rule | yes |

## What it means

A reading review is a strong check when the definition is precise and the bug is local: one
line that contradicts one rule. That makes these ten bugs too easy to rank reviewers or model
generations. The errors that got through in practice were of another kind. The duplicated
firm-years (evidence record E01) began in a different file, and an AI audit of the downstream
code had praised the step that hid them. Stage 2 needs planted bugs of that kind: upstream,
spread across files, visible only in the data, or allowed by an ambiguous definition.

All reviewers are Claude models, the same family that wrote the code. Shared blind spots are a
known risk (Knight & Leveson 1986). The non-model layers (data checks, fake firms, rules,
planted bugs) are there for that reason.
