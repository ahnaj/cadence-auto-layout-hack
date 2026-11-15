# Native benchmark results

Baseline development-preview integration (commit e69aca5, before seeded routing) on Virtuoso IC6.1.8, NCSU CDK 1.6.0 / NCSU_TechLib_tsmc03d, Python 3.6.8, Linux. Results below are actual native DRC and LVS, not public-CI results. Dimensions are micrometers and areas square micrometers.

| Circuit | Width | Height | Area | DRC | LVS |
|---|---:|---:|---:|---|---|
| INV | 5.76 | 4.92 | 28.3392 | 0 violations | Match |
| NAND2 | 6.72 | 4.92 | 33.0624 | 0 violations | Match |
| NOR2 | 6.72 | 4.92 | 33.0624 | 0 violations | Match |
| AOI21 | 9.12 | 4.92 | 44.8704 | 0 violations | Match |
| NAND3, renamed pins | 7.68 | 4.92 | 37.7856 | 0 violations | Match |
| INV, doubled W and renamed pins | 5.76 | 6.48 | 37.3248 | 0 violations | Match |
| INV, m=2 | 6.72 | 4.92 | 33.0624 | 0 violations | Match |
| XOR2 | 17.76 | 9.60 | 170.4960 | 0 violations | Match |
| Full adder hierarchy | — | — | — | Unsupported | Unsupported |
| Multi-bit combinational hierarchy | — | — | — | Unsupported | Unsupported |

All eight successful cases have completed ordinary extraction and zero LVS size errors. The fresh inverter uses different terminal names from the separate pre-existing inverter also tested during integration. INV_WIDE doubles both MOS widths and renames all four terminals. INV_M2 expands schematic m=2 into four physical MOS instances and matches native LVS. NAND versus NOR changes series/parallel connectivity while keeping the same source dimensions. NAND3_RENAMED is a newly authored three-input circuit; no circuit-name lookup occurs in the engine.

## Candidate comparisons

AOI21 paired-row candidates at heights 4.92, 6.12, 7.20 and 8.40 all passed native verification. Their width was 9.12, giving areas 44.8704, 55.8144, 65.6640 and 76.6080.

NAND3 candidates 7.68 × 4.92 and 9.12 × 6.12 both passed; the smaller candidate wins. Independent-row compact AOI21 attempts failed routing. Several compact XOR candidates failed routing. A nonsharing paired candidate at 17.76 × 9.60 routed successfully; native DRC exposed same-net landing gaps. Iterative guarded gap repair converged in four passes, after which native DRC reported zero violations and LVS matched with zero size errors. Earlier failures are retained and are not included as verified area results. XOR is much less compact than the simpler gates; congested-topology routing remains experimental.

This is the best verified subset found, not a global optimum. The new generic engine does not inherit the capabilities of an earlier application-specific generator.

## Reproduce

1. Install and calibrate local adapter constraints from the actual PDK. Set example_n_width, example_p_width and example_length to legal source-device dimensions.
2. In an isolated Virtuoso process, load skill/load.il, a local ALconfig association list, and examples/fixtures.il.
3. Call `alFixtures("FRESH_TEST_SOURCES" "/absolute/new/source/library")`. Use examples/variants.il and alVariants for width/pin/connectivity variants, and examples/multiplicity.il with alMultiplicityFixture for m=2. These are connectivity-only database fixtures; regenerate them through the scripts instead of running graphical Check and Save without adding schematic wires.
4. Run benchmark with a private JSON manifest:
   `[{"source_lib":"FRESH_TEST_SOURCES","cell":"INV","output_lib":"FRESH_TEST_LAYOUTS","seed":0}]`.
5. Repeat for each fixture. Use paired placement and the full manufacturing grid for AOI21. Compare fresh candidates through summary.json.
6. Keep console.log, virtuoso.log, execution.json, the extracted database and lvs/si.out together.

The final verified regression used paired placement and five configured routing metals, with a deck-required top-via enclosure override. All exact local settings and unmodified tool logs are retained under .local; they are excluded from Git because they contain installation paths and technology measurements. Public users must supply their own licensed configuration. The public report does not ship or fabricate native logs.

On the tested workstation, .local/release_evidence.json indexes the eight final unmodified native log sets. Each run includes an engine snapshot and SHA256 hashes. The release regression also reran the simpler gates after the gap-repair changes; the table uses those final measured bounds. An earlier three-metal independent-row baseline had height 5.64 for INV/NAND2/NOR2; paired placement reduced them to 4.92.

A subsequent supply-pin placement change pins both supplies on their actual rails. Its native inverter regression also passed DRC and LVS, with unchanged physical bounds.

The baseline figures above predate the routing-quality fix. Seed 0 now disables random tie breaking; replay historical geometry with its recorded engine snapshot. Seeded-router integration results are recorded separately in SEEDS.md; changing seeds may change routing success.

The routing-quality update preserves the pictured cell dimensions while reducing fragmented geometry. See [native before/after measurements](ROUTING_QUALITY.md).
