# Architecture

- schematic_reader.il opens schematics read-only, records terminals and MOS W/L/m/nf/body connectivity, and detects unsupported hierarchy.
- device_mapper.il probes installed PCells, ports, grid, routing widths/spacings and native via geometry in an isolated output library.
- placement.il derives row geometry from those measurements, orders each polarity's connectivity graph, and tries source/drain mirroring. Adjacent devices share diffusion only with equal W/L, compatible polarity/body and the same endpoint net.
- geometry.il creates native PCell instances, rectangles, vias, electrical terminals, physical pin shapes and text displays.
- router.il uses a bounded grid search and priority queue. Different-net conductors and cut spacing form obstacles. Paths connect each physical terminal to the existing tree. Commit-time via checks can reject a candidate.
- verification.il runs real Diva and audits native database opens.
- pipeline.il combines the modules without circuit-specific coordinates.
- scripts/autolayout.py handles configuration, isolated runs, process timeouts, candidate selection and evidence parsing.

Placement uses a greedy graph-trail heuristic across seeds, not exhaustive Euler-path or folding optimization. Area mode tries configured heights and derives a feasible height when none is specified. Current search does not shrink all spacing parameters automatically. Candidate rejection is driven by native DRC/LVS; no custom geometry check can grant a verification pass.

Intermediate native cellviews are retained even after failure. Public CI exercises only open-source orchestration. Integration requires licensed tools.

Paired placement aligns gate-matched NMOS/PMOS instances and checks common diffusion pitch. It searches both mirroring and paired order seeds. Conservative candidates can disable sharing or add outer routing clearance. A guarded same-net gap-fill stage handles narrow notches while checking other-net clearance; Diva still decides legality.

Positive routing seeds use a local deterministic PRNG for equal-priority net ordering, port order and equal-cost heap ties. Seed 0 preserves baseline behavior. Native geometry manifests support reproducibility comparisons; they never substitute for DRC/LVS.
