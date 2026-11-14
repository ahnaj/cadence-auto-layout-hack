# Quick start

Follow INSTALL.md and calibrate local constraints first. Choose a small flat CMOS schematic. Its pin names and MOS connections will be read from the database; no named logic pattern is required.

Run doctor, then generate with --dry-run. Remove --dry-run for actual synthesis. Use --iterations to try rotated/mirrored transistor orders. Configure candidate_heights for area mode, or use --optimize fixed --height H. A height below the placement's supported minimum is rejected, not silently increased.

Every candidate uses a fresh library. The report identifies the lowest-area candidate with DRC zero, completed extraction and matching LVS with zero size errors. Inspect console.log and lvs/si.out before using the result.

## Interactive CIW

The SKILL modules never exit the interactive process:

```lisp
ALroot="/absolute/path/to/cadence-skill-autolayout"
load(strcat(ALroot "/skill/load.il"))
; ALconfig must be a SKILL association list with the documented adapter fields.
; Copy the ALconfig assignment from a private batch run's run.il, not its exit wrapper.
alGenerate("MY_LIB" "my_gate" "schematic" "FRESH_LAYOUTS"
           "/absolute/new/library/path" 0 nil nil)
alVerify("FRESH_LAYOUTS" "my_gate" "MY_LIB" "my_gate" "schematic"
         "/absolute/existing/verification/run/directory")
```

Use a fresh verification directory so evidence cannot be confused with a previous run. The CLI enforces this automatically. Do not load a generated batch run.il into an interactive CIW; that wrapper intentionally exits its batch process.
