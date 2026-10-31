# Fake firms: 15 invented firms with one to six made-up patents each. Each firm tests one tricky case
# from the definition. The expected answers below were worked out from the rules in
# spec/new_classes.md before any version of the measure was run, and no code computed them.
# Run from the repository folder: Rscript tests/make_fixtures.R

row <- function(patent_id, firm_id, filing_year, grant_year, cpc_seq, cpc_subclass)
  data.frame(patent_id, firm_id, filing_year, grant_year, cpc_seq, cpc_subclass, stringsAsFactors = FALSE)

pc <- rbind(
  # F01 simple: base {A01B, B01C}, forward {B01C, C01D} -> 1 new
  row("P0101", "F01", 1997, 1999, 0, "A01B"),
  row("P0102", "F01", 1999, 2001, 0, "B01C"),
  row("P0103", "F01", 2001, 2003, 0, "B01C"),
  row("P0104", "F01", 2002, 2004, 0, "C01D"),
  # F02 empty base: nothing filed 1995-1999 -> NA
  row("P0201", "F02", 2001, 2003, 0, "C01D"),
  # F03 no forward patents: base {A01B}, forward {} -> 0
  row("P0301", "F03", 1998, 2000, 0, "A01B"),
  # F04 window edges. 1994 (t-6) is too early, so A01B is new again in 2001. 1995 (t-5) is in the base,
  # so B01C in 2002 is known. 2000 (t) is in the forward window, so C01D counts as new. 2003 (t+3) is
  # too late, so D01E doesn't count. Base {B01C}, forward {A01B, B01C, C01D} -> 2 new
  row("P0401", "F04", 1994, 1996, 0, "A01B"),
  row("P0402", "F04", 1995, 1997, 0, "B01C"),
  row("P0403", "F04", 2000, 2002, 0, "C01D"),
  row("P0404", "F04", 2001, 2003, 0, "A01B"),
  row("P0405", "F04", 2002, 2004, 0, "B01C"),
  row("P0406", "F04", 2003, 2005, 0, "D01E"),
  # F05 duplicate rows: same patents as F01, every row twice -> still 1
  row("P0501", "F05", 1997, 1999, 0, "A01B"), row("P0501", "F05", 1997, 1999, 0, "A01B"),
  row("P0502", "F05", 1999, 2001, 0, "B01C"), row("P0502", "F05", 1999, 2001, 0, "B01C"),
  row("P0503", "F05", 2001, 2003, 0, "B01C"), row("P0503", "F05", 2001, 2003, 0, "B01C"),
  row("P0504", "F05", 2002, 2004, 0, "C01D"), row("P0504", "F05", 2002, 2004, 0, "C01D"),
  # F06 several codes per patent: first-listed base {A01B}, forward {A01B} -> 0 (all codes would give 1)
  row("P0601", "F06", 1998, 2000, 0, "A01B"), row("P0601", "F06", 1998, 2000, 1, "C01D"),
  row("P0602", "F06", 2001, 2003, 0, "A01B"), row("P0602", "F06", 2001, 2003, 1, "D01E"),
  # F07 same new class in three forward years -> counted once
  row("P0701", "F07", 1999, 2001, 0, "A01B"),
  row("P0702", "F07", 2001, 2003, 0, "C01D"),
  row("P0703", "F07", 2002, 2004, 0, "C01D"),
  row("P0704", "F07", 2000, 2002, 0, "C01D"),
  # F08 filing vs grant year: by filing, base {A01B, C01D}, forward {C01D} -> 0
  row("P0801", "F08", 1997, 2000, 0, "A01B"),
  row("P0802", "F08", 1999, 2001, 0, "C01D"),
  row("P0803", "F08", 2002, 2003, 0, "C01D"),
  # F09 missing class in the forward window contributes nothing -> 0
  row("P0901", "F09", 1998, 2000, 0, "A01B"),
  row("P0902", "F09", 2001, 2003, 0, NA),
  row("P0903", "F09", 2002, 2004, 0, ""),
  # F10 patent owned by two firms counts for each
  row("P1001", "F10a", 1998, 2000, 0, "A01B"),
  row("P1002", "F10b", 1999, 2001, 0, "C01D"),
  row("P1003", "F10a", 2001, 2003, 0, "C01D"),
  row("P1003", "F10b", 2001, 2003, 0, "C01D"),
  # F11 another firm's patents must not matter
  row("P1101", "F11", 1998, 2000, 0, "A01B"),
  row("P1102", "F11", 2001, 2003, 0, "B01C"),
  row("P1103", "F11x", 1997, 1999, 0, "B01C"),
  # F12 several focal years for one firm
  row("P1201", "F12", 1996, 1998, 0, "A01B"),
  row("P1202", "F12", 1999, 2001, 0, "B01C"),
  row("P1203", "F12", 2001, 2003, 0, "C01D"),
  # F13 subclasses that differ only in the fourth character are different classes
  row("P1301", "F13", 1998, 2000, 0, "A01B"),
  row("P1302", "F13", 2001, 2003, 0, "A01C")
)

expected <- data.frame(
  firm_id = c("F01","F02","F03","F04","F05","F06","F07","F08","F09","F10a","F10b","F11","F11x","F12","F12","F12","F13"),
  year    = c(2000, 2000, 2000, 2000, 2000, 2000, 2000, 2000, 2000, 2000, 2000, 2000, 2000, 1998, 2000, 2001, 2000),
  n_base_classes    = c(2, 0, 1, 1, 2, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2, 2, 1),
  n_forward_classes = c(2, 1, 0, 3, 2, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1),
  new_classes       = c(1, NA, 0, 2, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1),
  case = c("simple", "empty base", "no forward patents", "window edges", "duplicate rows",
           "several codes per patent", "repeated class", "filing vs grant year", "missing class",
           "co-owned patent (firm a)", "co-owned patent (firm b)", "firm separation", "firm separation (other firm)",
           "focal year 1998", "focal year 2000", "focal year 2001", "fourth character"),
  stringsAsFactors = FALSE
)

dir.create("tests/fixtures", showWarnings = FALSE, recursive = TRUE)
write.csv(pc, "tests/fixtures/fake_patent_class.csv", row.names = FALSE, na = "")
write.csv(expected[, c("firm_id", "year")], "tests/fixtures/fake_firm_year.csv", row.names = FALSE)
write.csv(expected, "tests/fixtures/fake_expected.csv", row.names = FALSE, na = "NA")
cat("Wrote", nrow(pc), "patent-class rows and", nrow(expected), "expected firm-years\n")
