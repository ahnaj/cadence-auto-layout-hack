; SPDX-License-Identifier: MIT
; Load fixtures.il first; this routine creates its own source fixture library.
procedure(alMultiplicityFixture(lib path)
 let((library cv dev)
  when(ddGetObj(lib) || isDir(path) error("Use a fresh fixture library"))
  library=ddCreateLib(lib path)
  unless(library error("Fixture library creation failed"))
  techBindTechFile(library alCfg("technology_library"))
  alFixture(lib "INV_M2" '(("I" "input") ("O" "output") ("VP" "inputOutput") ("VN" "inputOutput"))
   '(("nmos" "O" "I" "VN" "VN") ("pmos" "O" "I" "VP" "VP")))
  cv=dbOpenCellViewByType(lib "INV_M2" "schematic" "" "a")
  foreach(i cv~>instances
   dev=car(setof(d alCfg("devices") alVal(d "source_lib")==i~>libName && alVal(d "source_cell")==i~>cellName))
   when(dev dbReplaceProp(i alVal(dev "multiplicity_param" "m") "string" "2")))
  dbSetConnCurrent(cv) dbSave(cv) dbClose(cv)
  printf("AL_MULT_CREATED\n")))
