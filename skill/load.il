; SPDX-License-Identifier: MIT
; Set ALroot to the repository absolute path before loading.
foreach(file '("common.il" "schematic_reader.il" "device_mapper.il" "geometry.il"
 "router.il" "placement.il" "verification.il" "pipeline.il")
 load(strcat(ALroot "/skill/" file)))
