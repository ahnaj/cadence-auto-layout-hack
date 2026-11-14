# Technology adapters

The initial adapter is config/tech/ncsu_tsmc03.example.json. JSON is used to avoid a YAML dependency. Supply --config with a local file. A local file can also specify adapter_file relative to itself; its settings override the adapter.

Device mappings include source library/cell, width/length property names, layout library/cell, layout parameter names and active layer. Width and length must be positive decimal micron values; expression strings are rejected. Multiplicity is expanded as parallel physical devices. nf other than 1 is rejected.

Set routing_layers, cut_layers, routing_vias, gate_contact, substrate_tie, well_tie, poly_layer and well_layer to installed names. The first routing layer must be the MOS source/drain and gate-contact metal. Native technology APIs provide widths, spacings, grid and via geometry. Missing rules fail explicitly.

Local physical constraints:
- rail_width: conductor width at the top and bottom boundaries.
- layout_margin: edge margin beyond the measured PCell bounds.
- well_margin: required well-to-active enclosure/separation from the installed deck.
- tie_reserve: horizontal space for a body tie at the left of each row.
- diffusion_break: active separation between nonsharing devices.
- candidate_heights: optional positive heights for area-mode search.
- routing_grid_multiple, max_search_nodes, via_cost: search limits/cost.
- via_landing_overrides: list of objects with via, layer, enclosure; adds landing geometry around the actual cut.
- label_height, text_layer: display configuration.
- startup_file, drc_rules, extraction_rules, lvs_rules: installed files, with environment expansion.

Some installed via definitions do not meet every Diva enclosure requirement. Validate actual landed geometry against the deck and configure explicit overrides. A technology database minimum is not proof of deck compliance.

Supply names are inferred from MOS body nets, not hardcoded aliases. Both must be exposed as terminals. Nonstandard or multiple body domains need an implementation extension.

To add an adapter, provide mappings and locally calibrated constraints, then run the full native fixture suite. Merely changing a technology name does not establish support. This engine currently assumes symmetric planar source/drain PCells and same-width diffusion sharing.

placement_style can be independent or paired. Paired rows match gate nets and share one gate contact when gate multiplicities agree; otherwise placement falls back to independent rows. diffusion_sharing can be disabled for a conservative candidate. routing_margin adds routing clearance above the measured minimum; try several local settings and compare verified area. A larger cell is useful only if it routes and verifies.
