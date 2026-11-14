# Exact coverage and remaining work

This is a development preview. It does not meet the full universal-generator acceptance criteria.

Implemented: native flat schematic reading; configurable planar NMOS/PMOS mappings; W/L preservation and parallel m expansion; PCell/via measurement; mirrored row placement with electrically checked sharing; bounded net-aware routing; native physical pins and visible terminal-name displays; multiple placement/height candidates; fresh native OA libraries; real Diva DRC/extraction/LVS; CLI and independent fixtures.

Not implemented: physical hierarchy (including FA/multi-bit hierarchy), folding or nf>1, vector terminals, mixed primitive/subcircuit layouts, arbitrary analog primitives, multiple body domains, capacitance-aware extraction, post-layout simulation, pin-access guarantees for a parent router, GUI automation, negotiated-congestion rip-up/rerouting, exhaustive Euler or globally optimal area search.

Arbitrary scalar printable ASCII pin names are read from the schematic. Electrical ties and supply names are inferred from body nets. Circuit classification is not used to synthesize or alter functionality. A topology can be readable yet unroutable within the chosen placement and budget; it is then a failed candidate.

The tested PCells are symmetric planar devices. MY mirroring exchanges physical diffusion endpoints without changing logical instance terminals. Equal W/L and body-net checks are necessary sharing conditions; native DRC/LVS remains mandatory.

No existing output view is overwritten, and source views open read-only. An interrupted run can leave locks until the Cadence process exits. Do not remove locks from a live editor. Private failed-run data is deliberately retained for diagnosis.

The final flat XOR fixture passes DRC/LVS in one larger candidate, but many smaller candidates fail routing. Passing isolated-cell checks does not establish row-abutment legality; that regression is still required before treating these as a production standard-cell library. Native regression covers m=1 and m=2; the implemented expansion limit is 8, with larger values not yet regression-tested.
