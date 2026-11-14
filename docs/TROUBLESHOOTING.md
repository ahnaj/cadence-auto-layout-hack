# Troubleshooting

- **Virtuoso unavailable:** source your site's licensed environment before install/run.
- **Missing technology/device library:** correct source cds.lib and adapter mappings. A technology library need not contain layout PCells.
- **prependNCSUCDKInstallPath undefined:** load the actual installed CDK startup file via startup_file. Registering libraries alone does not initialize Diva helpers.
- **Missing numeric constraints:** fill null local fields from installed rules. Public examples intentionally do not redistribute those rules.
- **No legal route / queue limit:** inspect the saved candidate; try another ordering or larger height, and increase the search budget only when useful.
- **DRC violations:** inspect AL_VIOLATION messages and native markers. Correct the adapter or placement; do not suppress markers.
- **LVS mismatch or size errors:** inspect si.out and the extracted view. Check source parameters, polarity/body mapping, opens/shorts and PCell evaluation.
- **Files exist but Library Manager is empty:** open with the reported run cds.lib and check ddGetObj. Never repair by copying raw OA files or creating metadata manually.
- **Pins seem absent:** enable layout/displayPinNames in CIW and inspect actual terminal pins. Text alone is not connectivity.
- **Timeout:** result is unavailable/failed. Confirm the batch process and children have exited before inspecting locks. Rerun in a fresh output library.
