
proc XML:decrypt {text} {
set retext ""
set char ""
set cry1 {&amp;}
set cry2 {&lt;}
set cry3 {&gt;}
set cry4 {&quot;}
set cry5 {&apos;}

  for {set x "0"} {$x<[string length $text]} {incr x} {
    set char $char[string index $text $x]

    if { $char==$cry1 } {set retext $retext&; set char ""} \
      elseif { $char==$cry2 } {set retext $retext<; set char ""} \
      elseif { $char==$cry3 } {set retext $retext>; set char ""} \
      elseif { $char==$cry4 } {set retext $retext{"}; set char ""} \
      elseif { $char==$cry5 } {set retext $retext'; set char ""} \
        \
      elseif { "$char[rtrimleft $cry1 $char]"==$cry1 } {} \
      elseif { "$char[rtrimleft $cry2 $char]"==$cry2 } {} \
      elseif { "$char[rtrimleft $cry3 $char]"==$cry3 } {} \
      elseif { "$char[rtrimleft $cry4 $char]"==$cry4 } {} \
      elseif { "$char[rtrimleft $cry5 $char]"==$cry5 } {} \
      else { set retext $retext$char; set char "" }
    }
  return $retext
}

proc XML:extract {vars} {
set listvar ""
set varname ""
set value ""

set quotchar ""
set place1 ""
set place2 ""
set place3 ""
set tmp1 ""
set tmp2 ""

set tmp ""

while {$tmp==""} {
  if {[set place1 [findfirst "=" $vars 0]]==-1} {return $listvar}

  set varname [string range $vars 0 [expr $place1-1]]

  set tmp1 [findfirst {"} $vars $place1]
  set tmp2 [findfirst {'} $vars $place1]


  if {$tmp1<$tmp2 && $tmp1!="-1"} {set place2 $tmp1; set quotchar {"}} \
    elseif {$tmp1>$tmp2 && $tmp2=="-1"} {set place2 $tmp1; set quotchar {"}} \
    elseif {$tmp2<$tmp1 && $tmp2!="-1"} {set place2 $tmp2; set quotchar {'}} \
    elseif {$tmp2>$tmp1 && $tmp1=="-1"} {set place2 $tmp2; set quotchar {'}} \
    else {return $listvar}

  if {$place2==-1} {return $listvar}

  if {[string trim [string range $vars [expr $place1+1] [expr $place2-1]]]!=""} {set vars [string range $vars [expr $place1+1] end]; continue}    ;#If there is something like {name=  abcd='aa'} ,skip name parameter

  incr place2
  set place3 [expr [findfirst $quotchar $vars $place2]-1]
  if {$place3==-2} {return $listvar}

  set varname [string trimleft $varname]
  set value [XML:decrypt [string range $vars $place2 $place3]]

  lappend listvar $varname
  lappend listvar $value

  set vars [string range $vars [expr $place3+2] end]
  }
}

proc rtrimleft {bigstr srcstr} {
set istring1 [string length $srcstr]
if {$srcstr == [string range $bigstr 0 [expr $istring1-1]]} {
  return [string range $bigstr $istring1 end] }
}

proc findfirst {srcstr bigstr start} {
set text [string range $bigstr $start end]
if {[set index [string first $srcstr $text]]!=-1} \
  {return [expr $start+$index]} else {return -1}
}

