; SPDX-License-Identifier: MIT
procedure(alReadCell(lib cell view designs visiting)
 prog((key cv d mos children terms dev kind width length mult fingers nets rec sourceCfg outputNames)
  key=strcat(lib "/" cell "/" view)
  when(member(key visiting) error("Recursive schematic hierarchy: %s" key))
  when(designs[key] return(designs[key]))
  cv=dbOpenCellViewByType(lib cell view "" "r")
  unless(cv error("Cannot open source schematic %s" key))
  d=makeTable('alDesign nil) d["lib"]=lib d["cell"]=cell d["view"]=view d["key"]=key
  foreach(term cv~>terminals
   when(numberp(term~>numBits) && term~>numBits>1 error("Vector terminals are unsupported; use explicit bit terminals: %s" term~>name))
   terms=cons(list(alName(term~>name) term~>direction) terms))
  sourceCfg=alCfg("devices")
  foreach(inst cv~>instances
   unless(inst~>libName=="basic" && member(inst~>cellName '("ipin" "opin" "iopin"))
    dev=nil
    foreach(item sourceCfg
     when(inst~>libName==alVal(item "source_lib") && inst~>cellName==alVal(item "source_cell") dev=item))
    nets=nil
    foreach(it inst~>instTerms
     unless(it~>net error("Unconnected instance terminal %s/%s" inst~>name it~>name))
     nets=cons(list(it~>name alName(it~>net~>name)) nets))
    rec=makeTable('alInstance nil) rec["name"]=inst~>name rec["nets"]=nets
    if(dev then
     width=alNumber(alProp(inst alVal(dev "width_param")) "width")
     length=alNumber(alProp(inst alVal(dev "length_param")) "length")
     mult=alNumber(alProp(inst alVal(dev "multiplicity_param" "m") 1) "multiplicity")
     fingers=alNumber(alProp(inst alVal(dev "fingers_param" "nf") 1) "fingers")
     unless(fingers==1 error("Nonunit nf is not yet supported: %s" inst~>name))
     unless(mult==fix(mult) && mult<=8 error("Multiplicity must be an integer from 1 to 8"))
     foreach(pin '("D" "G" "S" "B") unless(assoc(pin nets) error("Missing MOS terminal %s/%s" inst~>name pin)))
     rec["kind"]=alVal(dev "kind") rec["w"]=width rec["l"]=length rec["device"]=dev
     rec["m"]=mult mos=cons(rec mos)
    else
     unless(ddGetObj(inst~>libName inst~>cellName view)
      error("Unsupported instance %s: %s/%s" inst~>name inst~>libName inst~>cellName))
     rec["kind"]="hierarchy"
     rec["child"]=alReadCell(inst~>libName inst~>cellName view designs cons(key visiting))
     children=cons(rec children))))
  dbClose(cv)
  when(mos && children error("Mixed MOS/subcircuit cells are not yet supported: %s" key))
  unless(mos || children error("Empty/unsupported source %s" key))
  d["terms"]=reverse(terms) d["mos"]=reverse(mos) d["children"]=reverse(children)
  designs[key]=d
  return(d)))
procedure(alRails(d)
 let((vdd gnd bulk)
  foreach(i d["mos"]
   bulk=alVal(i["nets"] "B")
   if(i["kind"]=="pmos" then
    when(vdd && vdd!=bulk error("Multiple PMOS bulk nets require an adapter extension"))
    vdd=bulk
   else
    when(gnd && gnd!=bulk error("Multiple NMOS bulk nets require an adapter extension"))
    gnd=bulk))
  unless(vdd && gnd && vdd!=gnd error("Require distinct PMOS and NMOS bulk supplies"))
  unless(assoc(vdd d["terms"]) && assoc(gnd d["terms"])
   error("Expose both bulk/supply nets as schematic terminals"))
  d["vdd"]=vdd d["gnd"]=gnd
  list(vdd gnd)))
