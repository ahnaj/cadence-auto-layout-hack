; SPDX-License-Identifier: MIT
procedure(alProbeTech(outLib designs)
 let((tch cv tf layer value rule inst params template shapes ports via definition device key override)
  tch=makeTable('alTech nil) tch["width"]=makeTable('alWidths nil)
  tch["spacing"]=makeTable('alSpacings nil) tch["templates"]=makeTable('alTemplates nil)
  tch["vias"]=makeTable('alVias nil)
  cv=dbOpenCellViewByType(outLib "__al_probe" "layout" "maskLayout" "w")
  tf=techGetTechFile(cv) unless(tf error("No attached technology"))
  tch["grid"]=techGetMfgGridResolution(tf)
  tch["layers"]=alCfg("routing_layers")
  foreach(layer append(tch["layers"] alCfg("cut_layers"))
   rule=techGetSpacingRule(tf "minSpacing" layer)
   unless(numberp(rule) error("No installed minSpacing for %s" layer))
   tch["spacing"][layer]=rule
   when(member(layer tch["layers"])
    value=techGetSpacingRule(tf "minWidth" layer)
    unless(numberp(value) error("No installed minWidth for %s" layer))
    tch["width"][layer]=value))
  tch["polyWidth"]=techGetSpacingRule(tf "minWidth" alCfg("poly_layer"))
  tch["polySpace"]=techGetSpacingRule(tf "minSpacing" alCfg("poly_layer"))
  tch["wellMargin"]=alCfg("well_margin")
  unless(numberp(tch["wellMargin"]) && tch["wellMargin"]>0
   error("Set well_margin from the installed rule deck; technology databases may disagree with Diva"))
  foreach(key designs
   foreach(i designs[key]["mos"]
    device=i["device"]
    template=makeTable('alTemplate nil)
    params=list(list(alVal(device "layout_width_param") "float" i["w"])
                list(alVal(device "layout_length_param") "float" i["l"]))
    inst=dbCreateParamInst(cv dbOpenCellViewByType(alVal(device "layout_lib") alVal(device "layout_cell") "layout" "" "r")
      nil list(0 0) "R0" 1 params)
    unless(inst error("Configured MOS PCell cannot be instantiated"))
    shapes=nil ports=nil
    foreach(s inst~>master~>shapes
     when(member(s~>objType '("rect" "polygon" "path"))
      shapes=cons(list(car(s~>lpp) if(s~>net s~>net~>name nil) s~>bBox) shapes)))
    foreach(term inst~>master~>terminals
     foreach(pin term~>pins ports=cons(list(term~>name car(pin~>fig~>lpp) pin~>fig~>bBox) ports)))
    foreach(name '("S" "D" "G") unless(assoc(name ports) error("PCell is missing physical terminal %s" name)))
    template["bbox"]=inst~>bBox template["ports"]=ports template["shapes"]=shapes
    template["params"]=params i["template"]=template
   ))
  foreach(name append(alCfg("routing_vias") list(alCfg("gate_contact") alCfg("substrate_tie") alCfg("well_tie")))
   definition=techFindViaDefByName(tf name)
   unless(definition error("Installed via definition missing: %s" name))
   inst=dbCreateVia(cv definition list(0 0) "R0")
   unless(inst error("Cannot instantiate installed via %s" name))
   via=makeTable('alVia nil) shapes=nil
   foreach(s inst~>viaHeader~>master~>shapes shapes=cons(list(car(s~>lpp) s~>bBox) shapes))
   via["shapes"]=shapes via["lower"]=dbGetViaLayer(inst "layer1")
   via["upper"]=dbGetViaLayer(inst "layer2") via["cut"]=dbGetViaLayer(inst "cutLayer")
   foreach(ov alCfg("via_landing_overrides")
    when(alVal(ov "via")==name
     value=alVal(ov "enclosure")
     unless(numberp(value) && value>=0 error("Invalid via enclosure override"))
     rule=cadr(assoc(via["cut"] shapes))
     unless(rule error("Cannot find actual cut geometry"))
     override=list(alVal(ov "layer") alBox(alX0(rule)-value alY0(rule)-value alX1(rule)+value alY1(rule)+value))
     via["extra"]=cons(override via["extra"])
     via["shapes"]=cons(override via["shapes"])))
   tch["vias"][name]=via)
  dbClose(cv)
  when(ddGetObj(outLib "__al_probe") ddDeleteObj(ddGetObj(outLib "__al_probe")))
  tch))
