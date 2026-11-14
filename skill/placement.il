; SPDX-License-Identifier: MIT
procedure(alUnion(a b)
 if(a alBox(min(alX0(a) alX0(b)) min(alY0(a) alY0(b)) max(alX1(a) alX1(b)) max(alY1(a) alY1(b))) b))
procedure(alLayerBox(shapes layer)
 let((box) foreach(s shapes when(car(s)==layer box=alUnion(box caddr(s)))) box))
procedure(alOriented(item)
 dbTransformBBox(car(item)["template"]["bbox"] list(list(0 0) cadr(item) 1.0)))
procedure(alEnd(item right)
 let((i ports a b)
  i=car(item) ports=i["template"]["ports"]
  a=assoc("S" ports) b=assoc("D" ports)
  when(alX0(caddr(a))>alX0(caddr(b)) ports=a a=b b=ports)
  when(cadr(item)=="MY" ports=a a=b b=ports)
  alVal(i["nets"] car(if(right b a)))))
procedure(alShare(a b)
 alCfg("diffusion_sharing" t) &&
 car(a)["w"]==car(b)["w"] && car(a)["l"]==car(b)["l"] &&
 car(a)["kind"]==car(b)["kind"] &&
 alVal(car(a)["nets"] "B")==alVal(car(b)["nets"] "B") && alEnd(a t)==alEnd(b nil))
procedure(alOrder(devices seed)
 let((remaining result chosen previous)
  remaining=append(nthcdr(mod(seed length(devices)) devices)
   reverse(nthcdr(length(devices)-mod(seed length(devices)) reverse(devices))))
  while(remaining
   chosen=nil
   when(previous
    foreach(i remaining
     foreach(o '("R0" "MY")
      when(!chosen && alShare(previous list(i o)) chosen=list(i o)))))
   unless(chosen chosen=list(car(remaining) if(mod(seed 2)==0 "R0" "MY")))
   remaining=remove(car(chosen) remaining) result=cons(chosen result) previous=chosen)
  reverse(result)))
procedure(alRow(items tech start)
 let((placed previous x active box pitch grid layer s d)
  grid=tech["grid"] x=start
  foreach(item items
   layer=alVal(car(item)["device"] "active_layer")
   active=alLayerBox(car(item)["template"]["shapes"] layer)
   unless(active error("Cannot measure device active layer %s" layer))
   if(previous then
    if(alShare(car(previous) item) then
     s=caddr(assoc("S" car(item)["template"]["ports"]))
     d=caddr(assoc("D" car(item)["template"]["ports"]))
     pitch=abs(xCoord(alCenter(s))-xCoord(alCenter(d)))
    else
     box=alLayerBox(car(car(previous))["template"]["shapes"]
       alVal(car(car(previous))["device"] "active_layer"))
     pitch=alW(box)/2+alW(active)/2+alCfg("diffusion_break"))
    x=alSnapUp(x+pitch grid)
   else x=alSnapUp(start+alW(active)/2 grid))
   placed=cons(list(item x) placed) previous=list(item x))
  reverse(placed)))
procedure(alPairedRows(nitems pitems tech seed)
 prog((norder porder remaining previous choice nrow prow x oldN oldP itemN itemP a b pitch ppitch oldWidth)
  unless(length(nitems)==length(pitems) return(nil))
  norder=alOrder(nitems seed) remaining=pitems
  foreach(item norder
   choice=nil
   foreach(i remaining
    when(alVal(i["nets"] "G")==alVal(car(item)["nets"] "G")
     foreach(o '("R0" "MY")
      when(!choice || (previous && alShare(previous list(i o))) choice=list(i o)))))
   unless(choice return(nil))
   porder=cons(choice porder) previous=choice remaining=remove(car(choice) remaining))
  porder=reverse(porder) x=alCfg("tie_reserve")
  for(idx 0 length(norder)-1
   itemN=nth(idx norder) itemP=nth(idx porder)
   a=alLayerBox(car(itemN)["template"]["shapes"] alVal(car(itemN)["device"] "active_layer"))
   b=alLayerBox(car(itemP)["template"]["shapes"] alVal(car(itemP)["device"] "active_layer"))
   oldWidth=if(oldN
    max(alW(alLayerBox(car(oldN)["template"]["shapes"] alVal(car(oldN)["device"] "active_layer")))
        alW(alLayerBox(car(oldP)["template"]["shapes"] alVal(car(oldP)["device"] "active_layer")))) 0)
   ppitch=abs(xCoord(alCenter(caddr(assoc("S" car(itemP)["template"]["ports"]))))-
              xCoord(alCenter(caddr(assoc("D" car(itemP)["template"]["ports"])))))
   if(oldN && alShare(oldN itemN) && alShare(oldP itemP) then
    pitch=abs(xCoord(alCenter(caddr(assoc("S" car(itemN)["template"]["ports"]))))-
              xCoord(alCenter(caddr(assoc("D" car(itemN)["template"]["ports"])))))
   else
    pitch=if(oldN max(alW(a) alW(b))+alCfg("diffusion_break") max(alW(a) alW(b))/2))
   when(oldN && (abs(pitch-ppitch)>1e-8 || !alShare(oldN itemN) || !alShare(oldP itemP))
    pitch=(oldWidth+max(alW(a) alW(b)))/2+alCfg("diffusion_break"))
   x=alSnapUp(x+pitch tech["grid"])
   nrow=cons(list(itemN x) nrow) prow=cons(list(itemP x) prow)
   oldN=itemN oldP=itemP)
  return(list(reverse(nrow) reverse(prow)))))
procedure(alLeafPlan(lib design tech seed height)
 let((p nrow prow ng pg grid rail margin gap nmax pmax nmin pmin yN yP yGN yGP minHeight
       nitems pitems right width tieBox tieN tieP gateModel gateM1 gatePoly gateCut wellBottom
       inst item x y net port box via b nnet pnet layer gbox cx cy pairs paired contactSites)
  alRails(design)
  grid=tech["grid"] rail=alCfg("rail_width") margin=alCfg("layout_margin")
  gap=tech["spacing"][car(tech["layers"])]+alCfg("routing_margin" 0)
  unless(numberp(rail) && rail>=tech["width"][car(tech["layers"])] error("Invalid rail width"))
  nitems=setof(i design["mos"] i["kind"]=="nmos")
  pitems=setof(i design["mos"] i["kind"]=="pmos")
  nrow=alRow(alOrder(nitems seed) tech alCfg("tie_reserve"))
  prow=alRow(alOrder(pitems seed) tech alCfg("tie_reserve"))
  when(alCfg("placement_style" "independent")=="paired"
   pairs=alPairedRows(nitems pitems tech seed)
   when(pairs nrow=car(pairs) prow=cadr(pairs) paired=t))
  nmax=0 pmax=0 nmin=0 pmin=0 right=0
  foreach(i nitems
   b=alLayerBox(i["template"]["shapes"] alVal(i["device"] "active_layer"))
   nmax=max(nmax alY1(b)) nmin=min(nmin alY0(b)))
  foreach(i pitems
   b=alLayerBox(i["template"]["shapes"] alVal(i["device"] "active_layer"))
   pmax=max(pmax alY1(b)) pmin=min(pmin alY0(b)))
  gateModel=tech["vias"][alCfg("gate_contact")]
  gateM1=cadr(assoc(car(tech["layers"]) gateModel["shapes"]))
  gatePoly=cadr(assoc(alCfg("poly_layer") gateModel["shapes"]))
  unless(gateM1 && gatePoly error("Gate contact must connect configured poly and first routing metal"))
  yN=alSnapUp(rail+gap-nmin grid)
  yGN=alSnapUp(yN+nmax+gap-alY0(gateM1) grid)
  yGP=alSnapUp(yGN+max(alH(gateM1)+gap alH(gatePoly)+tech["polySpace"]) grid)
  when(paired yGP=yGN)
  yP=alSnapUp(max(yGP+alY1(gateM1)+gap-pmin yN+nmax+2*tech["wellMargin"]-pmin) grid)
  minHeight=alSnapUp(yP+pmax+gap+rail grid)
  when(height && height<minHeight error("Height %g below supported placement minimum %g" height minHeight))
  height=if(height height minHeight)
  yP=yP+height-minHeight
  unless(paired yGP=yGP+height-minHeight)
  wellBottom=yP+pmin-tech["wellMargin"]
  when(wellBottom<yN+nmax+tech["wellMargin"] error("Insufficient well/substrate separation"))
  foreach(row list(nrow prow)
   foreach(entry row
    b=alOriented(car(entry))
    right=max(right cadr(entry)+alX1(b))))
  width=alSnapUp(right+margin grid)
  p=makeTable('alPlan nil) p["tech"]=tech p["cell"]=design["cell"]
  p["vdd"]=design["vdd"] p["gnd"]=design["gnd"]
  p["width"]=width p["height"]=height p["ports"]=makeTable('alPorts nil)
  when(ddGetObj(lib design["cell"] "layout") error("Refusing to overwrite layout %s/%s" lib design["cell"]))
  p["cv"]=dbOpenCellViewByType(lib design["cell"] "layout" "maskLayout" "w")
  unless(p["cv"] error("Native layout creation failed"))
  nnet=design["gnd"] pnet=design["vdd"] layer=car(tech["layers"])
  alRect(p alCfg("well_layer") alBox(0 wellBottom width height) nil)
  box=alBox(0 0 width rail) alRect(p layer box nnet) alPort(p nnet layer box)
  box=alBox(0 height-rail width height) alRect(p layer box pnet) alPort(p pnet layer box)
  contactSites=makeTable('alContactSites nil)
  foreach(kind '("nmos" "pmos")
   y=if(kind=="nmos" yN yP) cy=if(kind=="nmos" yGN yGP)
   row=if(kind=="nmos" nrow prow)
   net=if(kind=="nmos" nnet pnet)
   via=if(kind=="nmos" alCfg("substrate_tie") alCfg("well_tie"))
   b=cadr(assoc(layer tech["vias"][via]["shapes"]))
   cx=alSnapUp(alCfg("tie_reserve")/2 grid)
   alVia(p via cx y net)
   box=alMove(b cx y) alPort(p net layer box)
   foreach(entry row
    item=car(entry) x=cadr(entry)
    inst=alPlaceMos(p item x y cadr(item))
    net=alVal(car(item)["nets"] "G")
    gbox=dbTransformBBox(caddr(assoc("G" car(item)["template"]["ports"])) inst~>transform)
    alRect(p alCfg("poly_layer")
      alBox(x-tech["polyWidth"]/2 min(alY0(gbox) cy+alY0(gatePoly))
            x+tech["polyWidth"]/2 max(alY1(gbox) cy+alY1(gatePoly))) net)
    unless(contactSites[sprintf(nil "%g|%g|%s" x cy net)]
     alVia(p alCfg("gate_contact") x cy net)
     contactSites[sprintf(nil "%g|%g|%s" x cy net)]=t)
    alPort(p net layer alMove(gateM1 x cy))))
  p))
