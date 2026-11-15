# Routing-quality correction

The earlier seeded search randomized equal-length paths without considering bends.
Its terminal traversal could also add avoidable branches. Many tiny stair-step
rectangles then required extra same-net gap repair. Passing DRC/LVS did not mean
those routes were efficient.

The revised native SKILL search keeps incoming direction in its state, minimizes
weighted wire/via path cost, then minimizes bends, and uses a seed only after
those costs tie. Each net starts at its largest terminal and connects the nearest
remaining terminal to its tree. No circuit-specific routes or coordinates were
added. Placement, source devices, rules and connectivity are unchanged in these
comparisons.

## Native results

Tested with Virtuoso IC6.1.8 and the installed NCSU TSMC 0.3 adapter. All rows
below completed Diva extraction, had **zero DRC violations**, and **matched LVS**.
Dimensions are micrometers; wire is committed route-centerline length.

| Circuit | Routing seed | Width | Height | Area | Routed wire | New routing vias | In-layer bends |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| NAND2 | 17 | 6.72 | 6.12 | 41.1264 | 8.34 | 0 | 3 |
| NAND2 | 18 | 6.72 | 6.12 | 41.1264 | 8.34 | 0 | 3 |
| AOI21 | 17 | 9.12 | 4.92 | 44.8704 | 11.22 | 2 | 2 |
| XOR2 | 17 | 17.76 | 9.60 | 170.496 | 79.26 | 12 | 10 |
| XOR2 | 18 | 17.76 | 9.60 | 170.496 | 79.20 | 14 | 8 |

NAND2 seed 17 previously used 10.92 micrometers of routed wire and three routing
vias. Seed 18 previously used 8.34 micrometers and no routing vias, but needed
19 emitted wire rectangles; the revised seeds each need nine.

XOR2 seed 18 wins the documented area-then-wire-length ranking, while seed 17 uses
two fewer routing vias at the cost of 0.06 micrometers more wire. Both alternatives
are retained. This tradeoff is explicit; neither is described as a global optimum.

## Actual database shape counts

The following counts were read from the old and new native layout databases.
They include top-level placement shapes, physical pin rectangles and gap-repair
rectangles, but exclude geometry inside PCell instances. Via counts here include
preplaced top-level vias as well as routing vias, unlike the routing-only table.

| Pictured candidate | Old rectangles | New rectangles | Old top-level vias | New top-level vias |
| --- | ---: | ---: | ---: | ---: |
| NAND2 seed 17 | 28 | 21 | 7 | 4 |
| NAND2 seed 18 | 33 | 21 | 4 | 4 |
| AOI21 | 58 | 26 | 9 | 7 |
| XOR2 | 533 | 63 | 25 | 22 |

Area is unchanged. The improvement here is routing quality and reduced shape
fragmentation, not a claim of smaller placement.

## Reproducibility and limits

Native tests require a shortest unobstructed diagonal route to have one bend
for seeds 0, 17, 18, 19 and 20. Repeating NAND2 seed 17 in a fresh library reproduced
its geometry and routing fingerprints and again passed native DRC/LVS. XOR2 seed
17 also reproduced its routing fingerprint after a measurement-only correction.

Use fixed-height generation with placement seed 0 for NAND2/AOI21 and placement
seed 2 for XOR2, and routing seeds 17/18. These checks used routing_grid_multiple=1;
coarser grids are not equivalent. Supply physical rule values from the installed
PDK, not this document. Each native run retains its engine snapshot, local
configuration, real tool logs and result JSON under the ignored run directory.

The new route metrics are measured before same-net gap repair and exclude existing
placement geometry. They are not extracted parasitics. Greedy net ordering and
tree growth remain heuristics: this does not prove the globally shortest network
or replace DRC/LVS. The engine's existing flat-CMOS coverage limits still apply.
