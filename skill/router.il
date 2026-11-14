; SPDX-License-Identifier: MIT
procedure(alHeap(capacity)
 let((h) h=makeTable('alHeap nil) h["data"]=makeVector(capacity+1 nil) h["size"]=0 h))
procedure(alHeapLess(a b)
 car(a)<car(b) || (car(a)==car(b) &&
  if(cadddr(a) cadddr(a) 0)<if(cadddr(b) cadddr(b) 0)))
procedure(alTie(r)
 if(r["rng"] alRand(r["rng"] 2147483646) 0))
procedure(alPush(h entry)
 let((a k parent)
  a=h["data"] k=h["size"]+1
  unless(k<length(a) error("Routing queue limit reached"))
  h["size"]=k
  while(k>1 && alHeapLess(entry a[fix(k/2)])
   parent=fix(k/2) a[k]=a[parent] k=parent)
  a[k]=entry))
procedure(alPop(h)
 prog((a root tail k child n)
  n=h["size"] unless(n>0 return(nil))
  a=h["data"] root=a[1] tail=a[n] h["size"]=n-1 n=n-1 k=1
  while(2*k<=n
   child=2*k
   when(child<n && alHeapLess(a[child+1] a[child]) child=child+1)
   when(!alHeapLess(a[child] tail) a[k]=tail return(root))
   a[k]=a[child] k=child)
  a[k]=tail return(root)))
procedure(alLayer(r layer)
 let((tail) tail=member(layer r["layers"])
  if(tail length(r["layers"])-length(tail) nil)))
procedure(alNode(r layer x y) layer*r["nx"]*r["ny"]+x*r["ny"]+y)
procedure(alDecode(r node)
 let((layer rem x)
  layer=fix(node/(r["nx"]*r["ny"]))
  rem=node-layer*r["nx"]*r["ny"] x=fix(rem/r["ny"])
  list(layer x rem-x*r["ny"])))
procedure(alPointBox(r node)
 let((v width x y)
  v=alDecode(r node) width=r["tech"]["width"][nth(car(v) r["layers"])]/2.0
  x=cadr(v)*r["grid"] y=caddr(v)*r["grid"]
  alBox(x-width y-width x+width y+width)))
procedure(alLegal(r layer box net)
 prog((space)
  when(alX0(box)<-1e-8 || alY0(box)<-1e-8 ||
   alX1(box)>r["width"]+1e-8 || alY1(box)>r["height"]+1e-8 return(nil))
  space=r["tech"]["spacing"][layer]
  unless(numberp(space) error("Missing spacing for layer %s" layer))
  foreach(s r["plan"]["shapes"]
   when(car(s)==layer && (!net || cadr(s)!=net) && alOverlap(box caddr(s) space) return(nil)))
  return(t)))
procedure(alPointLegal(r node net)
 let((result v)
  result=r["cache"][node]
  unless(result
   v=alDecode(r node)
   result=if(alLegal(r nth(car(v) r["layers"]) alPointBox(r node) net) 'legal 'blocked)
   r["cache"][node]=result)
  result=='legal))
procedure(alAccess(r port net)
 let((layer box half points node)
  layer=alLayer(r car(port)) box=cadr(port)
  unless(numberp(layer) error("Pin layer is not routable: %s" car(port)))
  half=r["tech"]["width"][car(port)]/2.0
  for(x ceiling((alX0(box)+half-1e-8)/r["grid"]) floor((alX1(box)-half+1e-8)/r["grid"])
   for(y ceiling((alY0(box)+half-1e-8)/r["grid"]) floor((alY1(box)-half+1e-8)/r["grid"])
    node=alNode(r layer x y)
    when(alPointLegal(r node net) points=cons(node points))))
  unless(points error("No spacing-legal access for net %s at %L" net port))
  points))
procedure(alNeighbors(r node net)
 let((v layer x y nx ny next result model other existing legal px py)
  v=alDecode(r node) layer=nth(car(v) r["layers"]) x=cadr(v) y=caddr(v)
  foreach(delta '((1 0) (-1 0) (0 1) (0 -1))
   nx=x+car(delta) ny=y+cadr(delta)
   when(nx>=0 && ny>=0 && nx<r["nx"] && ny<r["ny"]
    next=alNode(r car(v) nx ny)
    when(alPointLegal(r next net) result=cons(list(next 1.0 nil nil) result))))
  foreach(name alCfg("routing_vias")
   model=r["tech"]["vias"][name]
   other=cond((layer==model["lower"] model["upper"]) (layer==model["upper"] model["lower"]))
   when(other && numberp(alLayer(r other))
    next=alNode(r alLayer(r other) x y)
    existing=r["existing"][sprintf(nil "%s|%s|%d|%d" net name x y)]
    legal=existing || alPointLegal(r next net)
    px=x*r["grid"] py=y*r["grid"]
    unless(existing
     foreach(s model["shapes"]
      unless(alLegal(r car(s) alMove(cadr(s) px py) if(member(car(s) r["layers"]) net nil)) legal=nil)))
    when(legal result=cons(list(next alCfg("via_cost" 12.0) name existing) result))))
  result))
procedure(alSearch(r starts targets net)
 prog((heap cost prev target entry node g path link next trial visits)
  heap=alHeap(alCfg("max_search_nodes" 200000))
  cost=makeTable('alCost nil) prev=makeTable('alPrevious nil) target=makeTable('alTargets nil)
  foreach(n targets target[n]=t)
  foreach(n starts cost[n]=0.0 alPush(heap list(0.0 n 0.0 alTie(r))))
  visits=0
  while(heap["size"]>0
   entry=alPop(heap) node=cadr(entry) g=caddr(entry)
   when(cost[node]==g
    when(target[node]
     path=list(list(node nil nil))
     while(prev[node]
      link=prev[node]
      rplaca(path list(node cadr(link) caddr(link)))
      node=car(link) path=cons(list(node nil nil) path))
     return(path))
    visits=visits+1
    when(visits>alCfg("max_search_nodes" 200000) error("Routing search budget reached for %s" net))
    foreach(edge alNeighbors(r node net)
     next=car(edge) trial=g+cadr(edge)
     when(!numberp(cost[next]) || trial<cost[next]
      cost[next]=trial prev[next]=list(node caddr(edge) cadddr(edge))
      alPush(heap list(trial next trial alTie(r)))))))
  error("No spacing-legal physical route for %s" net)))
procedure(alCommit(r path net)
 let((p previous a b v x y segment direction nextDirection box)
  p=r["plan"] previous=car(path)
  foreach(step cdr(path)
   if(cadr(step) then
    when(segment alRect(p car(segment) cadr(segment) net) segment=nil)
    unless(caddr(step)
     v=alDecode(r car(step)) x=cadr(v)*r["grid"] y=caddr(v)*r["grid"]
     foreach(s r["tech"]["vias"][cadr(step)]["shapes"]
      unless(alLegal(r car(s) alMove(cadr(s) x y) if(member(car(s) r["layers"]) net nil))
       error("A proposed path contains conflicting via cuts")))
     alVia(p cadr(step) x y net)
     r["existing"][sprintf(nil "%s|%s|%d|%d" net cadr(step) cadr(v) caddr(v))]=t)
   else
    a=alPointBox(r car(previous)) b=alPointBox(r car(step))
    v=alDecode(r car(step))
    nextDirection=alX0(a)==alX0(b)
    box=alBox(min(alX0(a) alX0(b)) min(alY0(a) alY0(b)) max(alX1(a) alX1(b)) max(alY1(a) alY1(b)))
    if(segment && direction==nextDirection then
     a=cadr(segment)
     segment=list(car(segment) alBox(min(alX0(a) alX0(box)) min(alY0(a) alY0(box)) max(alX1(a) alX1(box)) max(alY1(a) alY1(box))))
    else
     when(segment alRect(p car(segment) cadr(segment) net))
     segment=list(nth(car(v) r["layers"]) box))
    direction=nextDirection)
   previous=step)
  when(segment alRect(p car(segment) cadr(segment) net))))
procedure(alRoute(p)
 let((r tree ports path targets order rank idx seed)
  r=makeTable('alRouter nil) r["plan"]=p r["tech"]=p["tech"] r["layers"]=p["tech"]["layers"]
  r["width"]=p["width"] r["height"]=p["height"] r["grid"]=p["tech"]["grid"]*alCfg("routing_grid_multiple" 1)
  r["nx"]=fix(r["width"]/r["grid"])+1 r["ny"]=fix(r["height"]/r["grid"])+1
  seed=alCfg("routing_seed" 0)
  when(seed>0 r["rng"]=alRng(seed))
  r["existing"]=makeTable('alExisting nil)
  foreach(v p["viaSites"]
   when(abs(caddr(v)/r["grid"]-round(caddr(v)/r["grid"]))<1e-7 &&
    abs(cadddr(v)/r["grid"]-round(cadddr(v)/r["grid"]))<1e-7
    r["existing"][sprintf(nil "%s|%s|%d|%d" car(v) cadr(v) round(caddr(v)/r["grid"]) round(cadddr(v)/r["grid"]))]=t))
  foreach(net p["ports"] order=cons(net order))
  if(r["rng"] then
   order=alShuffle(sort(order 'alphalessp) r["rng"])
   rank=makeTable('alNetRank nil) idx=0
   foreach(net order rank[net]=idx idx=idx+1)
   order=sort(order lambda((a b)
    if(length(p["ports"][a])==length(p["ports"][b]) rank[a]<rank[b]
     length(p["ports"][a])>length(p["ports"][b]))))
  else
   order=sort(order lambda((a b) length(p["ports"][a])>length(p["ports"][b])))
   when(mod(alCfg("candidate_seed" 0) 2)==1 order=reverse(order)))
  order=append(remove(p["vdd"] remove(p["gnd"] order)) list(p["gnd"] p["vdd"]))
  p["routing"]=t
  foreach(net order
   r["cache"]=makeTable('alCache nil)
   ports=p["ports"][net]
   when(r["rng"]
    ports=alShuffle(sort(copy(ports) lambda((a b) alphalessp(sprintf(nil "%L" a) sprintf(nil "%L" b)))) r["rng"]))
   tree=alAccess(r car(ports) net)
   foreach(port cdr(ports)
    targets=alAccess(r port net)
    path=alSearch(r targets tree net)
    alCommit(r path net)
    foreach(step path tree=cons(car(step) tree))
    tree=append(targets tree)
    r["cache"]=makeTable('alCache nil))
   printf("AL_ROUTED %s %s\n" p["cell"] net))
  p["routing"]=nil t))

; Same-net conductors can still violate notch/spacing rules.
procedure(alHealSameNet(p)
 let((shapes space width a b box x0 x1 y0 y1 legal covered added obox)
  shapes=p["shapes"] added=0
  foreach(s shapes
   when(cadr(s) && member(car(s) p["tech"]["layers"])
    a=caddr(s) space=p["tech"]["spacing"][car(s)] width=p["tech"]["width"][car(s)]
    foreach(other shapes
     when(car(other)==car(s) && cadr(other)==cadr(s)
      b=caddr(other) box=nil
      x0=max(alX0(a) alX0(b)) x1=min(alX1(a) alX1(b))
      y0=max(alY0(a) alY0(b)) y1=min(alY1(a) alY1(b))
      when(x1-x0>=width-1e-8 && alY0(b)>alY1(a)+1e-8 && alY0(b)-alY1(a)<space-1e-8
       box=alBox(x0 alY1(a) x1 alY0(b)))
      when(y1-y0>=width-1e-8 && alX0(b)>alX1(a)+1e-8 && alX0(b)-alX1(a)<space-1e-8
       box=alBox(alX1(a) y0 alX0(b) y1))
      when(!box && alOverlap(a b space) && !alOverlap(a b) &&
       max(alW(a) alH(a) alW(b) alH(b))<=2*width+space+1e-8
       box=alUnion(a b))
      when(box
       legal=t covered=nil
       foreach(ob p["shapes"]
        obox=caddr(ob)
        when(car(ob)==car(s)
         if(cadr(ob)!=cadr(s) then
          when(alOverlap(box obox space) legal=nil)
         else
          when(alX0(obox)<=alX0(box)+1e-8 && alY0(obox)<=alY0(box)+1e-8 &&
           alX1(obox)>=alX1(box)-1e-8 && alY1(obox)>=alY1(box)-1e-8 covered=t))))
       when(legal && !covered alRect(p car(s) box cadr(s)) added=added+1))))))
  added))
