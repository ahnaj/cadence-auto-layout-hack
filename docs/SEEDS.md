# Seeded routing

The CLI selects a fresh positive routing seed by default. --seed N makes it reproducible; --placement-seed N keeps placement fixed across candidates. Seeds are integers from 0 through 2147483646. Routing seed 0 preserves the baseline traversal; positive candidate seeds advance deterministically, wrapping in the positive range.

Within SKILL, a local Park-Miller generator controls equal-priority net ordering, physical-terminal traversal, and equal-cost maze-search tie breaking. It does not alter device connectivity, dimensions, rules, or Virtuoso's global random state. Heap ties are secondary to real path cost. Power rails retain their routing priority.

Without an explicit placement seed, placement continues its existing ordering search by candidate index. With fixed placement and height, routing can vary without changing area. This does not promise that every seed produces a distinct or legal layout.

## Native regression

NAND2, fixed placement seed 0 and height 6.12, produced four verified alternatives:

| Routing seed | Width | Height | Area | Diva DRC | Diva LVS |
|---|---:|---:|---:|---|---|
| 17 | 6.72 | 6.12 | 41.1264 | 0 violations | Match |
| 18 | 6.72 | 6.12 | 41.1264 | 0 violations | Match |
| 19 | 6.72 | 6.12 | 41.1264 | 0 violations | Match |
| 20 | 6.72 | 6.12 | 41.1264 | 0 violations | Match |

All four have distinct emitted routing and geometry fingerprints. Repeating seed 17 in a fresh library reproduced both fingerprints exactly and again passed native DRC and LVS. Tests used the same source schematic, configuration, engine and Cadence version. Reproducibility refers to generated geometry, not binary OA file bytes, timestamps or database identifiers.

The native PRNG reference-vector, shuffle and heap-priority tests also pass. Private unmodified tool logs and seed_evidence.json remain under .local and are excluded from publication.

## Reports

Each candidate records base_seed, placement_seed, routing_seed, geometry_sha256 and routing_sha256. Geometry/routing manifests are exported from the native generation process and hashed with record order normalized. They demonstrate reproducibility; they do not certify connectivity or replace Diva.

summary.json retains every candidate and includes equal_area_verified, including alternatives with the same area. best_verified remains a single area-ranked result for compatibility. No failed candidate is promoted because its area or fingerprint looks attractive.
