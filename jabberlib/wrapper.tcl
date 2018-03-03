######################################################################
#
# wrapper.tcl
#
# This file defines wrapper procedures.  These
# procedures are called by functions in jabberlib, and
# they in turn call the TclXML library functions.
#
# $Header: /home/tim/cvs/palm/eggjabot/jabberlib/wrapper.tcl,v 1.1 2004/01/23 01:58:27 tim Exp $
#
#
######################################################################
#
# Here is a list of the procedures defined here:
#
if {0} {
  proc wrapper:new {streamstartcmd streamendcmd parsecmd}
  proc wrapper:parser {id args}
  proc wrapper:getlevel {id level}
  proc wrapper:setlevel {id level xmldata}
  proc wrapper:appendlevel {id level xmldata}
  proc wrapper:reset {id}
  proc wrapper:elementstart {id tagname varlist args}
  proc wrapper:elementend {id tagname args}
  proc wrapper:chdata {id chardata}
  proc wrapper:xmlerror {id args}
  proc wrapper:xmlcrypt {text}
  proc wrapper:createxml {xmldata}
  proc wrapper:createtag {tagname args}
  proc wrapper:getattr {varlist attrname}
  proc wrapper:isattr {varlist attrname}
  proc wrapper:splitxml {xmldata vtag vvars visempty vchdata vchildren}
}

######################################################################
#set wrapper(list) ""
set wrapper(freeid) 0

######################################################################
proc wrapper:new {streamstartcmd streamendcmd parsecmd} {
  variable wrapper

  set id "wrap#$wrapper(freeid)"

  set wrapper($id,streamstartcmd) $streamstartcmd
  set wrapper($id,streamendcmd)   $streamendcmd
  set wrapper($id,parsecmd)       $parsecmd

  incr wrapper(freeid)
  lappend wrapper(list) $id

  catch { set wrapper($id,parser) [[namespace parent]::xml::parser "_parser_$id" \
        -statevariable ::jlib::wrapper:xmlstatevar_$id \
        -final 0 \
        -reportempty 1 \
        -elementstartcommand  "[namespace current]::wrapper:elementstart [list $id]" \
        -elementendcommand    "[namespace current]::wrapper:elementend [list $id]" \
        -characterdatacommand "[namespace current]::wrapper:chdata [list $id]" \
        -errorcommand         "[namespace current]::wrapper:xmlerror [list $id]"]

  }


  set wrapper($id,level) 0;     # Current level
  set wrapper($id,level1tag) "";# Just something, to know that we're
                                # under <stream:stream> tag, not <anythingelse>
  set wrapper($id,xmldata) "";  # Level 2 xmldata, level1 is the main tag,
                                # <stream:stream>, and level2 is the command
                                # tag, such as <message>. We don't handle
                                # level1 xmldata, because we do not need a list
                                # of tags/childtags that we received in a
                                # jabber session.
  set wrapper($id,tempdata) ""; # Temporary xmldata of the current level...

  return $id
}

######################################################################
proc wrapper:finish {id} {
  variable wrapper
  if {[set pos [lsearch $wrapper(list) $id]] == -1} {
    return -code error -errorinfo "No such wrapper: \"$id\""
  } else {
    lreplace $wrapper(list) $pos $pos
  }
}


######################################################################
proc wrapper:parser {id args} {
  variable wrapper
  if {[lsearch $wrapper(list) $id] == -1} {
    return -code error -errorinfo "No such wrapper: \"$id\""
  }

  return [uplevel 1 "[list $wrapper($id,parser)] $args"]
}

######################################################################
#
# Will return $level xmldata from $wrapper($id,xmldata).
#
proc wrapper:getlevel {id level} {
  variable wrapper
  if {[lsearch $wrapper(list) $id] == -1} {
    return -code error -errorinfo "No such wrapper: \"$id\""
  }

  if {$level < 2} {return}
  set a $wrapper($id,xmldata)

  for {set i 2} {$i != $level} {incr i} {
    if {[llength $a] < 5} {
      return
    } else {
      set a [lindex $a end]
    }
  }
  return $a
}

######################################################################
#
# Will set $level xmldata from $wrapper($id,xmldata) to $cdata.
#
proc wrapper:setlevel {id level xmldata} {
  variable wrapper
  if {[lsearch $wrapper(list) $id] == -1} {
    return -code error -errorinfo "No such wrapper: \"$id\""
  }

  if {$level < 2} {
    return
  }

# $i is our "currentlevel"

  set a(1) {1 2 3 4}
  lappend a(1) $wrapper($id,xmldata)

  for {set i 2} {$i != $level} {incr i} {
    set a($i) [lindex $a([expr $i-1]) end]
    if {[llength $a($i)] < 5} {
      return
    }
  }
  set a($i) $xmldata

  for {set i [expr $i-1]} {$i != 1} {set i [expr $i-1]} {
    set a($i) [lreplace $a($i) end end $a([expr $i+1])]
  }

  set wrapper($id,xmldata) $a(2)
}

######################################################################
#
# Will append $cdata to $level-1 of $wrapper($id,xmldata).
#
proc wrapper:appendlevel {id level xmldata} {
  variable wrapper
  if {[lsearch $wrapper(list) $id] == -1} {
    return -code error -errorinfo "No such wrapper: \"$id\""
  }

  if {$level < 2} {
    return
  }

  # $i is our "currentlevel"

  set a(1) {1 2 3 4}
  lappend a(1) $wrapper($id,xmldata)

  for {set i 2} {$i != $level} {incr i} {
    set a($i) [lindex $a([expr $i-1]) end]
  }

  set a($i) [lindex $a([expr $i-1]) end]
  lappend a($i) $xmldata

  for {set i [expr $i-1]} {$i != 1} {set i [expr $i-1]} {
    set a($i) [lreplace $a($i) end end $a([expr $i+1])]
  }

  set wrapper($id,xmldata) $a(2)
}

######################################################################
proc wrapper:reset {id} {
  variable wrapper
  if {[lsearch $wrapper(list) $id] == -1} {return -code error -errorinfo "No such wrapper: \"$id\""}

  $wrapper($id,parser) reset
  $wrapper($id,parser) configure -final 0 \
      -reportempty 1 \
      -elementstartcommand  "[namespace current]::wrapper:elementstart [list $id]" \
      -elementendcommand    "[namespace current]::wrapper:elementend [list $id]" \
      -characterdatacommand "[namespace current]::wrapper:chdata [list $id]" \
      -errorcommand         "[namespace current]::wrapper:xmlerror [list $id]"

  set wrapper($id,level) 0
  set wrapper($id,level1tag) ""
  set wrapper($id,xmldata) ""
  set wrapper($id,tempdata) ""
}

######################################################################
proc wrapper:elementstart {id tagname varlist args} {
  variable wrapper
  if {[lsearch $wrapper(list) $id] == -1} {
    return -code error -errorinfo "No such wrapper: \"$id\""
  }

  set isempty 0

  # Check args, to see if empty element
  foreach {attr val} $args {
    switch -- $attr {
      -empty {set isempty $val}
    }
  }

  if {$wrapper($id,level) == 0} {
    set wrapper($id,level) 1             ;# We got a main tag, such as <stream:stream>
    set wrapper($id,level1tag) $tagname  ;# but we're not sure if it's <stream:stream>, so, because we only want to run <message>s inside <stream:stream>, not <x>, we set wrapper($id,level1tag) to tag we got, we'll use this in deciding to call JabberLib on level2 tags...

    if {$tagname == "stream:stream"} {
      uplevel #0 "$wrapper($id,streamstartcmd) [list $varlist]"
    }
    return
  }
  if {$wrapper($id,level) == 1} {
    set wrapper($id,level) 2
    set wrapper($id,tempdata) [list $tagname $varlist $isempty ""]
    set wrapper($id,xmldata) $wrapper($id,tempdata)
    return
  }
  if {$wrapper($id,level) > 1} {

    # First, save our tempdata.
    # If we're in the command tag, we should put all tempdata
    # in xmldata, if we're not, we'll only _change_ xmldata.

    if {$wrapper($id,level) == 2} {
      set wrapper($id,xmldata) $wrapper($id,tempdata)
    } else {
      wrapper:setlevel $id $wrapper($id,level) $wrapper($id,tempdata)
    }

    # Then, we override tempdata with our new tag,
    set wrapper($id,tempdata) [list $tagname $varlist $isempty ""]

    # And append this to xmldata.
    wrapper:appendlevel $id $wrapper($id,level) $wrapper($id,tempdata)

    # Now, we can increase our level.
    incr wrapper($id,level)

    return
  }
}

######################################################################
proc wrapper:elementend {id tagname args} {
  variable wrapper
  if {[lsearch $wrapper(list) $id] == -1} {
    return -code error -errorinfo "No such wrapper: \"$id\""
  }

  set isempty 0

  # Check args, to see if empty element
  foreach {attr val} $args {
    switch -- $attr {
      -empty { set isempty $val}
    }
  }

  # Check if we got a first-level-close-tag (such as </stream:stream>, on level 1)
  if {$wrapper($id,level) == 1} {
    if {$tagname != $wrapper($id,level1tag)} {
      wrapper:xmlerror $id "Open tag \"[lindex $wrapper($id,tempdata) 0]\" doesn't match with close tag \"$tagname\""
      return
    }
    if {$tagname == "stream:stream"} {
      uplevel #0 $wrapper($id,streamendcmd)
      return
    }

    set wrapper($id,level) 0
    set wrapper($id,level1tag) ""
    set wrapper($id,xmldata) ""
    set wrapper($id,tempdata) ""
    return
  }

  # If closed-tag doesn't match with the opened-tag give error and return
  if {[lindex $wrapper($id,tempdata) 0] != $tagname} {
    wrapper:xmlerror $id "Open tag \"[lindex $wrapper($id,tempdata) 0]\" doesn't match with close tag \"$tagname\""
    return
  }

  # Flush our "temporary" xmldata to main xmldata
  wrapper:setlevel $id $wrapper($id,level) $wrapper($id,tempdata)

  # Decrease current level
  set wrapper($id,level) [expr $wrapper($id,level)-1]

  # Check if we finished a command (level 1) tag.
  if {$wrapper($id,level) == 1} {
    if {$wrapper($id,level1tag) == "stream:stream"} {
      uplevel #0 "$wrapper($id,parsecmd) [list $wrapper($id,tempdata)]"
    }
    set wrapper($id,tempdata) ""
    set wrapper($id,xmldata) ""
    return
  }

  # Copy upper-xmldata to "temporary" xmldata
  set wrapper($id,tempdata) [wrapper:getlevel $id $wrapper($id,level)]
}

######################################################################
proc wrapper:chdata {id chardata} {
  variable wrapper
  if {[lsearch $wrapper(list) $id] == -1} {
    return -code error -errorinfo "No such wrapper: \"$id\""
  }
  if {$wrapper($id,level) < 2} {
    return
  }

  set chdata [lindex $wrapper($id,tempdata) 3]
  set chdata "$chdata$chardata"
  set wrapper($id,tempdata) [lreplace $wrapper($id,tempdata) 3 3 $chdata]
}

######################################################################
#
# Called when there's an error with parsing XML.
#
proc wrapper:xmlerror {id args} {
  variable wrapper
  if {[lsearch $wrapper(list) $id] == -1} {
    return -code error -errorinfo "No such wrapper: \"$id\""
  }

  LOG "XML Parsing Error: $args"
  uplevel #0 $wrapper($id,streamendcmd)
}

######################################################################
proc wrapper:xmlcrypt {text} {
  set retext ""
  set cry1 {&amp;}
  set cry2 {&lt;}
  set cry3 {&gt;}
  set cry4 {&quot;}
  set cry5 {&apos;}

  for {set x "0"} {$x<[string length $text]} {incr x} {
    set char [string index $text $x]

    switch -- $char {
      &       { set retext $retext$cry1 }
      <       { set retext $retext$cry2 }
      >       { set retext $retext$cry3 }
      {"}     { set retext $retext$cry4 }
      '       { set retext $retext$cry5 }
      default { set retext $retext$char }
    }
  }
  return $retext
}

######################################################################
#
# This procedure converts (and returns) $xmldata to raw-XML
#
proc wrapper:createxml {xmldata} {
  set retext ""

  set tagname [lindex $xmldata 0]
  set vars    [lindex $xmldata 1]
  set isempty [lindex $xmldata 2]
  set chdata   [lindex $xmldata 3]
  if {[llength $xmldata] < 5} {
    set subtags ""
  } else {
    set subtags [lrange $xmldata 4 end]
  }

  set a "<$tagname"
  set retext $retext$a
  foreach {attr value} $vars {
    set a " $attr='[wrapper:xmlcrypt $value]'"
    set retext $retext$a
  }
  if {$isempty == 1 && $chdata == "" && [llength $subtags] == 0} {
    set a "/>"
    set retext $retext$a
    return $retext
  } else {
    set a ">"
    set retext $retext$a
  }

  set a [wrapper:xmlcrypt $chdata]
  set retext $retext$a

  foreach subdata $subtags {
    set a [wrapper:createxml $subdata]
    set retext $retext$a
  }

  set a "</$tagname>"
  set retext $retext$a

  return $retext
}

######################################################################
#
# This proc creates (and returns) xmldata of tag $tagname,
# with the parameters given.
#
# Parameters:
#  -empty   0|1         Is this an empty tag? If $chdata
#                       and $subtags are empty, then whether
#                       to make the tag empty or not is decided
#                       here. (default: 1)
#
#  -vars    {attr1 value1 attr2 value2 ..}   Vars is a list
#                       consisting of attr/value pairs, as shown.
#
#  -chdata  $chdata    ChData of tag (default: ""), if you use
#                       this attr multiple times, new chdata will
#                       be appended to old one.
#
#  -subtags $subchilds $subchilds is a list containing xmldatas
#                       of $tagname's subtags. (default: no sub-tags)
#
proc wrapper:createtag {tagname args} {
  set isempty 1
  set vars    ""
  set chdata  ""
  set subtags ""

  foreach {attr val} $args {
    switch -- $attr {
      -empty   { set isempty $val}
      -vars    { set vars $val}
      -chdata  { set chdata $chdata$val}
      -subtags { set subtags $val}
    }
  }

  set retext [list $tagname $vars $isempty $chdata]
  foreach a $subtags {
    lappend retext $a
  }

  return $retext
}

######################################################################
#
# This proc returns the value of $attr from varlist
#
proc wrapper:getattr {varlist attrname} {
  foreach {attr val} $varlist {
    if {$attr == $attrname} {
      return $val
    }
  }
  return ""
}

######################################################################
#
# This proc returns 1, or 0, depending on the attr exists in varlist or not
#
proc wrapper:isattr {varlist attrname} {
  foreach {attr val} $varlist {
    if {$attr == $attrname} {
      return 1
    }
  }
  return 0
}

######################################################################
#
# This proc splits the xmldata to 5 different variables.
#
proc wrapper:splitxml {xmldata vtag vvars visempty vchdata vchildren} {
  set tag     [lindex $xmldata 0]
  set vars    [lindex $xmldata 1]
  set isempty [lindex $xmldata 2]
  set chdata  [lindex $xmldata 3]
  if { [llength $xmldata] < 5 } {set children ""} else {set children [lrange $xmldata 4 end]}

  uplevel 1 "set [list $vtag]      [list $tag] \n     \
             set [list $vvars]     [list $vars] \n    \
             set [list $visempty]  [list $isempty] \n \
             set [list $vchdata]   [list $chdata] \n  \
             set [list $vchildren] [list $children]"
}

