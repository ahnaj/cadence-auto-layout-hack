# Installation

Use Linux with an authorized Virtuoso IC6.1.8 and NCSU CDK environment. Python 3.6+ and a POSIX shell are sufficient for orchestration; no pip dependencies or administrator privileges are needed.

1. Source the site's setup script. Confirm `virtuoso` is on PATH and `CDK_DIR` points to the installed CDK.
2. Ensure your existing `cds.lib` registers the technology, physical device library and source schematic library.
3. Run `./install.sh /absolute/path/to/cds.lib`.
4. Edit `.local/config.json`. Null physical constraints deliberately prevent generation until calibrated against your installed technology.
5. Run `bin/autolayout --cds-lib /path/to/cds.lib doctor`, then a dry-run.

The supplied adapter records names discovered on the tested installation: NCSU_Analog_Parts/nmos4 and pmos4 schematic symbols, and NCSU_TechLib_tsmc03d/nmos and pmos layout PCells with float w_microns/l_microns. Doctor checks these are registered; generation instantiates and measures the actual PCells. Change mappings if your installation differs.

The CLI loads the configured installed CDK startup file in each isolated batch process. This is required for Diva helper functions even when libraries can be opened without it. The startup file is referenced, never copied. The shell wrapper clears Python-specific library variables before starting Python; site-specific executable/environment requirements may need a local wrapper configured as `virtuoso`.

Runs go under `.local/runs`. Each run has its own library definition file. Open with:

```sh
virtuoso -cdslib /absolute/path/to/run/cds.lib
```

Verify the library/cell/layout in Library Manager. Native audits check ddGetObj, editable database opens, attached technology, geometry, instance masters and physical pins. Automated GUI screenshots are not a substitute for these checks and are not part of the current installer smoke test.
