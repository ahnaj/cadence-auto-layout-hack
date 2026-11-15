# Image provenance

These PNGs are native Virtuoso IC6.1.8 exports of original regression fixtures
defined by this project. They are not course submission screenshots. Only rendered
geometry and pin labels are included: no OA databases, PCell source, rule decks,
technology libraries, private paths or verification logs are distributed.

| File | Fixture | Width (µm) | Height (µm) | Area (µm²) | Diva DRC | Diva LVS |
| --- | --- | ---: | ---: | ---: | --- | --- |
| nand2-seed-17.png | NAND2, routing seed 17, placement seed 0 | 6.72 | 6.12 | 41.1264 | 0 violations | Matched |
| nand2-seed-18.png | NAND2, routing seed 18, placement seed 0 | 6.72 | 6.12 | 41.1264 | 0 violations | Matched |
| aoi21.png | AOI21, routing seed 17, placement seed 0 | 9.12 | 4.92 | 44.8704 | 0 violations | Matched |
| xor2.png | XOR2, routing seed 18, placement seed 2 | 17.76 | 9.60 | 170.496 | 0 violations | Matched |

All four candidates completed native Diva extraction. Measurements and statuses
come from their retained native-run evidence, not from the images. The source
views were opened read-only and exported with hiExportImage; no geometry was
changed for presentation. PNG metadata was checked before publication.

For reproduction and limitations see [benchmarks](../BENCHMARKS.md),
[seeds](../SEEDS.md) and [verification](../VERIFICATION.md).

These images replace the earlier staircase-heavy exports. They were regenerated
after introducing nearest-terminal routing and bend-aware shortest-path ties.
The XOR2 picture is the shortest-wire verified candidate among routing seeds 17
and 18 at the tested placement and height. Seed 17 has slightly more wire but
fewer vias; see [the measured tradeoff](../ROUTING_QUALITY.md).
