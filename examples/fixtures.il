; SPDX-License-Identifier: MIT
; Create original connectivity-only schematic fixtures in a NEW library.
procedure(alFixture(lib name terms devices @optional (scale 1))
 let((cv inst dev master idx net pinMaster dir)
  when(ddGetObj(lib name) error("Fixture cell already exists"))
  cv=dbOpenCellViewByType(lib name "schematic" "schematic" "w")
  idx=0
  foreach(pair terms
   dir=cadr(pair)
   pinMaster=dbOpenCellViewByType("basic" cond((dir=="input" "ipin") (dir=="output" "opin") (t "iopin")) "symbol" "" "r")
   unless(schCreatePin(cv pinMaster car(pair) dir nil list(-4 idx*2) "R0") error("Cannot create schematic pin"))
   idx=idx+1)
  idx=0
  foreach(spec devices
   dev=car(setof(d alCfg("devices") alVal(d "kind")==car(spec)))
   unless(dev error("No mapped device for fixture"))
   master=dbOpenCellViewByType(alVal(dev "source_lib") alVal(dev "source_cell") "symbol" "" "r")
   inst=dbCreateInst(cv master sprintf(nil "M%d" idx) list(idx*2 0) "R0")
   unless(inst error("Cannot create schematic fixture device"))
   dbReplaceProp(inst alVal(dev "width_param") "string"
    sprintf(nil "%g" scale*alCfg(if(car(spec)=="nmos" "example_n_width" "example_p_width"))))
   dbReplaceProp(inst alVal(dev "length_param") "string" sprintf(nil "%g" alCfg("example_length")))
   foreach(pin '("D" "G" "S" "B")
    net=nth(length(member(pin '("B" "S" "G" "D"))) spec)
    dbCreateInstTerm(dbMakeNet(cv net) inst dbFindTermByName(master pin)))
   idx=idx+1)
  dbSetConnCurrent(cv)
  dbSave(cv) dbClose(cv)))
procedure(alFixtures(lib path)
 let((library terms)
  when(ddGetObj(lib) || isDir(path) error("Use a fresh fixture library and directory"))
  library=ddCreateLib(lib path)
  unless(library error("Cannot create fixture library"))
  techBindTechFile(library alCfg("technology_library"))
  terms='(("A" "input") ("B" "input") ("Y" "output") ("VP" "inputOutput") ("VN" "inputOutput"))
  alFixture(lib "INV" '(("IN" "input") ("OUT" "output") ("VP" "inputOutput") ("VN" "inputOutput"))
   '(("nmos" "OUT" "IN" "VN" "VN") ("pmos" "OUT" "IN" "VP" "VP")))
  alFixture(lib "NAND2" terms
   '(("nmos" "Y" "A" "X" "VN") ("nmos" "X" "B" "VN" "VN")
     ("pmos" "Y" "A" "VP" "VP") ("pmos" "Y" "B" "VP" "VP")))
  alFixture(lib "NOR2" terms
   '(("nmos" "Y" "A" "VN" "VN") ("nmos" "Y" "B" "VN" "VN")
     ("pmos" "Y" "A" "X" "VP") ("pmos" "X" "B" "VP" "VP")))
  alFixture(lib "AOI21" cons('("C" "input") terms)
   '(("nmos" "Y" "A" "X" "VN") ("nmos" "X" "B" "VN" "VN") ("nmos" "Y" "C" "VN" "VN")
     ("pmos" "Y" "C" "Z" "VP") ("pmos" "Z" "A" "VP" "VP") ("pmos" "Z" "B" "VP" "VP")))
  alFixture(lib "XOR2" terms
   '(("nmos" "NA" "A" "VN" "VN") ("pmos" "NA" "A" "VP" "VP")
     ("nmos" "NB" "B" "VN" "VN") ("pmos" "NB" "B" "VP" "VP")
     ("nmos" "Y" "A" "X" "VN") ("nmos" "X" "B" "VN" "VN")
     ("nmos" "Y" "NA" "Z" "VN") ("nmos" "Z" "NB" "VN" "VN")
     ("pmos" "Y" "A" "T" "VP") ("pmos" "Y" "B" "T" "VP")
     ("pmos" "T" "NA" "VP" "VP") ("pmos" "T" "NB" "VP" "VP")))
  printf("AL_FIXTURES_CREATED\n")))
