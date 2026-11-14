# Verification

All successful statuses require real tool output from a fresh run directory.

1. ddGetObj and dbOpenCellViewByType validate the generated layout and editable geometry.
2. ivDRC runs the installed Diva DRC deck. Every native marker is logged with its rule text and bounding box.
3. ivExtract creates the extracted view. The database must reopen successfully.
4. ivLVS compares against the selected golden schematic and saves lvs/si.out.
5. The CLI requires zero DRC markers, successful process completion, no native error, the exact native match message, and zero device-size errors.

Statuses stay separate: generation, drc, extraction, lvs. A generated candidate can fail verification. Missing evidence means unavailable, never passed. The Python parser unit tests use synthetic strings only to test failure handling; they are not benchmark results.

Inspect console.log, virtuoso.log, lvs/si.out and the native layout markers. result.json and summary.json are indexes into that evidence, not substitutes for it. The console hash records which log was summarized. Local logs contain absolute paths and must remain private.

The generic engine currently produces ordinary extracted views only. Capacitance-aware extraction, Spectre simulation, timing/power checks and GUI visual acceptance are not implemented in this release. An LVS match checks electrical correspondence, not performance or global area optimality.

Each new CLI job snapshots the project's SKILL modules into its private run directory and records their hashes with process status and runtime. This keeps the exact engine used for a candidate available even after the repository changes.
