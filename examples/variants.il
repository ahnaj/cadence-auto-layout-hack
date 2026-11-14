; SPDX-License-Identifier: MIT
; Requires fixtures.il. Uses only newly-created source fixtures.
procedure(alVariants(lib path)
 let((library cv dev param)
  when(ddGetObj(lib) || isDir(path) error("Use a fresh fixture library"))
  library=ddCreateLib(lib path)
  unless(library error("Cannot create variant fixture library"))
  techBindTechFile(library alCfg("technology_library"))
  alFixture(lib "INV_WIDE" '(("DATA" "input") ("RESULT" "output") ("PWR" "inputOutput") ("RETURN" "inputOutput"))
   '(("nmos" "RESULT" "DATA" "RETURN" "RETURN") ("pmos" "RESULT" "DATA" "PWR" "PWR")) 2)
  alFixture(lib "NAND3_RENAMED"
   '(("DATA0" "input") ("DATA1" "input") ("ENABLE" "input") ("RESULT" "output") ("PWR" "inputOutput") ("RETURN" "inputOutput"))
   '(("nmos" "RESULT" "DATA0" "J1" "RETURN") ("nmos" "J1" "DATA1" "J2" "RETURN") ("nmos" "J2" "ENABLE" "RETURN" "RETURN")
     ("pmos" "RESULT" "DATA0" "PWR" "PWR") ("pmos" "RESULT" "DATA1" "PWR" "PWR") ("pmos" "RESULT" "ENABLE" "PWR" "PWR")))
  printf("AL_VARIANTS_CREATED\n")))
