; SPDX-License-Identifier: MIT
procedure(alRecord(p layer net box)
 p["shapes"]=cons(list(layer net box) p["shapes"]))
procedure(alRect(p layer box net)
 let((fig)
  unless(alW(box)>0 && alH(box)>0 error("Degenerate rectangle"))
  fig=dbCreateRect(p["cv"] list(layer "drawing") box)
  unless(fig error("Cannot create physical rectangle"))
  when(net fig~>net=dbMakeNet(p["cv"] net))
  when(p["routing"] p["routeFigs"]=cons(fig p["routeFigs"]))
  alRecord(p layer net box) fig))
procedure(alVia(p name x y net)
 let((via model tf layer box)
  model=p["tech"]["vias"][name] unless(model error("Unprobed via %s" name))
  tf=techGetTechFile(p["cv"])
  via=dbCreateVia(p["cv"] techFindViaDefByName(tf name) list(x y) "R0")
  unless(via error("Native via creation failed: %s" name))
  when(net via~>net=dbMakeNet(p["cv"] net))
  when(p["routing"] p["routeFigs"]=cons(via p["routeFigs"]))
  foreach(s model["shapes"]
   layer=car(s) box=alMove(cadr(s) x y)
   alRecord(p layer if(member(layer p["tech"]["layers"]) net nil) box))
  foreach(s model["extra"] alRect(p car(s) alMove(cadr(s) x y) net))
  p["viaSites"]=cons(list(net name x y) p["viaSites"])
  via))
procedure(alPort(p net layer box)
 p["ports"][net]=cons(list(layer box) p["ports"][net]))
procedure(alPlaceMos(p item x y orient)
 let((i template dev inst transform net term)
  i=car(item) template=i["template"] dev=i["device"]
  transform=list(list(x y) orient 1.0)
  inst=dbCreateParamInst(p["cv"]
   dbOpenCellViewByType(alVal(dev "layout_lib") alVal(dev "layout_cell") "layout" "" "r")
   i["name"] list(x y) orient 1 template["params"])
  unless(inst error("Cannot instantiate MOS %s" i["name"]))
  foreach(pair i["nets"]
   term=dbFindTermByName(inst~>master car(pair))
   when(term dbCreateInstTerm(dbMakeNet(p["cv"] cadr(pair)) inst term)))
  foreach(s template["shapes"]
   net=cadr(s)
   unless(net
    foreach(port template["ports"]
     when(cadr(port)==car(s) && caddr(port)==caddr(s) net=car(port))))
   alRecord(p car(s) if(net alVal(i["nets"] net) nil) dbTransformBBox(caddr(s) transform)))
  foreach(port template["ports"]
   when(member(car(port) '("S" "D"))
    alPort(p alVal(i["nets"] car(port)) cadr(port) dbTransformBBox(caddr(port) transform))))
  inst))
procedure(alPhysicalPins(p design)
 let((net port fig terminal label box)
  foreach(pair design["terms"]
   net=car(pair) port=car(p["ports"][net])
   when(net==p["vdd"]
    port=list(car(p["tech"]["layers"]) alBox(0 p["height"]-alCfg("rail_width") p["width"] p["height"])))
   when(net==p["gnd"]
    port=list(car(p["tech"]["layers"]) alBox(0 0 p["width"] alCfg("rail_width"))))
   unless(port error("No physically routed access for external terminal %s" net))
   unless(techGetLP(techGetTechFile(p["cv"]) list(car(port) "pin"))
    error("No installed pin-purpose layer for %s" car(port)))
   box=cadr(port)
   fig=dbCreateRect(p["cv"] list(car(port) "pin") box)
   terminal=dbCreateTerm(dbMakeNet(p["cv"] net) net cadr(pair))
   unless(dbCreatePin(terminal~>net fig net) error("Cannot create native pin"))
   label=dbCreateTextDisplay(terminal fig list(alCfg("text_layer" "text") "drawing")
    t alCenter(box) "centerCenter" "R0" "roman" alCfg("label_height" 0.3)
    nil nil t nil t "name" nil)
   unless(label error("Cannot create terminal-name display"))
  )))

procedure(alWriteGeometry(p)
 let((out)
  when(alCfg("geometry_manifest")
   out=outfile(alCfg("geometry_manifest"))
   unless(out error("Cannot write geometry manifest"))
   foreach(s p["shapes"] fprintf(out "SHAPE %L\n" s))
   foreach(v p["viaSites"] fprintf(out "VIA %L\n" v))
   foreach(i p["cv"]~>instances
    fprintf(out "INSTANCE %L %L %L %L\n" i~>name i~>libName i~>cellName i~>transform))
   foreach(term p["cv"]~>terminals
    foreach(pin term~>pins fprintf(out "PIN %L %L %L %L\n" term~>name term~>direction pin~>fig~>lpp pin~>fig~>bBox)))
   close(out))
  when(alCfg("routing_manifest")
   out=outfile(alCfg("routing_manifest"))
   unless(out error("Cannot write routing manifest"))
   foreach(fig p["routeFigs"]
    if(fig~>objType=="stdVia" then
     fprintf(out "VIA %L %L %L %L\n" fig~>net~>name fig~>viaHeader~>viaDefName fig~>origin fig~>orient)
    else
     fprintf(out "FIG %L %L %L %L\n" fig~>objType fig~>net~>name fig~>lpp fig~>bBox)))
   close(out))
  t))
