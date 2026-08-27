THE SWEEP THAT ADDED check_verdict_route, THE GATE FOR THE DEFECT THE CONVERSION FIXED.

  configured sweep: 111 PASS / 0 FAIL / 0 SKIP, with six documented stand-downs
  HARNESS_EXIT=4   HARNESS_RESULT=yes   294s

111, not 110: this run registers one more layer than any before it. The six stand-downs are the
same registered six.

The gate itself: 12 assertions, 90 inheritors scanned, 3 exempt and every exemption still needed.
Two mutation controls, run before it was registered:
  - put a hand-rolled `quit(0)` tail back into check_agility  -> FAIL naming check_agility.gd
  - add an exemption for check_bits, which does not need one  -> FAIL demanding the list be tightened
Each turned exactly one assertion red.

It flagged ITSELF on its first run, which is in the file: its own control constants are
triple-quoted blocks containing the shape it hunts, and the comment stripper did not understand
triple quotes. The offered fix was a per-file exemption for the detector. The stripper was fixed
instead, with a control for it, because widening a permission list to hide a defect in the
detector is the trade the whole layer exists to refuse.
