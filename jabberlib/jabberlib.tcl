######################################################################
#
# $Header: /home/tim/cvs/palm/eggjabot/jabberlib/jabberlib.tcl,v 1.1 2004/01/23 01:58:27 tim Exp $
#
# This is JabberLib (abbreviated jlib), the Tcl library for
# use in making Jabber clients.
#
#
# Variables used in JabberLib :
#  roster(users)                : Users currently in roster
#
#  roster(group,$username)      : Groups $username is in.
#
#  roster(name,$username)       : Name of $username.
#
#  roster(subsc,$username)      : Subscription of $username
#                                  ("to" | "from" | "both" | "")
#
#  roster(ask,$username)        : "Ask" of $username
#                                  ("subscribe" | "unsubscribe" | "")
#
#  lib(wrap)                    : Wrap ID
#
#  lib(sck)                     : SocketName
#
#  lib(sckstats)                : Socket status, "on" or "off"
#
#  iq(num)                      : Next iq id-number. Sent in
#                                  "id" attributes of <iq> packets.
#
#  iq($id)                      : Callback to run when result packet
#                                  of $id is received.
#
#
######################################################################
#
# Procedures defined in this library
#
if {0} {
  proc jlib::connect {sck server}
  proc jlib::disconnect {}
  proc jlib::got_stream {vars}
  proc jlib::end_of_parse {}
  proc jlib::outmsg {msg}
  proc jlib::inmsg {}
  proc jlib::clear_vars {}
  proc jlib::clear_iqs {}
  proc jlib::parse {xmldata}
  proc jlib::parse_send_auth {cmd type data}
  proc jlib::parse_send_create {cmd type data}
  proc jlib::parse_roster_get {ispush cmd type data}
  proc jlib::parse_roster_set {item cmd groups name type data}
  proc jlib::parse_roster_del {item cmd type data}
  proc jlib::send_iq {type xmldata args}
  proc jlib::send_auth {user pass res cmd}
  proc jlib::send_create {user pass name mail cmd}
  proc jlib::send_msg {to args}
  proc jlib::send_presence {args}
  proc jlib::roster_get {args}
  proc jlib::roster_set {item args}
  proc jlib::roster_del {item args}
  proc ::LOG text
  proc jlib::noop args
}

######################################################################
#
# Load XML:Parser
#
# We're using Steve Ball's TclXML, available from
# http://www.zveno.com/zm.cgi/in-tclxml/
#
# The TclXML must be put in a subdirectory called "xml" beneath
# the directory where JabberLib is.
#
######################################################################
#namespace forget ::xml
#namespace delete ::xml

source [file join [file dirname [info script]] "xml" "sgml.tcl"]
source [file join [file dirname [info script]] "xml" "xml.tcl"]

package require xml 1.8

namespace eval jlib {
  # Load XML:Wrapper
  source [file join [file dirname [info script]] "wrapper.tcl"]

  set lib(wrap) [wrapper:new "[namespace current]::got_stream" \
                             "::jlib::end_of_parse" "::jlib::parse"]

  # Export procedures.
  #
  namespace export "wrapper:splitxml" \
                   "wrapper:createtag" \
                   "wrapper:createxml" \
                   "wrapper:xmlcrypt" \
                   "wrapper:isattr" \
                   "wrapper:getattr"
  }

######################################################################

proc jlib::connect {sck server ip} {
  variable lib

  ::LOG "(jlib::connect) Socket:'$sck' IP:'$ip' Server:'$server'"

  if { $lib(sckstats) != "off" } {
    return -1
    # Already connected
  }

  if { [catch {fconfigure $sck}] != 0 } {
    ::LOG "error (jlib::connect) Socket doesn't exist"
    return -2
    # Socket doesn't exist
  }

  set lib(sck)      $sck
  set lib(sckstats) "on"

  fconfigure $sck -blocking 0 -buffering none -translation binary
  outmsg "<stream:stream xmlns:stream='[wrapper:xmlcrypt \
  {http://etherx.jabber.org/streams}]' \
  xmlns='jabber:client' to='[wrapper:xmlcrypt $server]'>"
  fileevent $sck readable "[namespace current]::inmsg"

  ::LOG "leaving connect operation"


  return 0
}

######################################################################
proc jlib::disconnect {} {
  variable lib

  ::LOG "(jlib::disconnect)"

  if { $lib(sckstats) == "off" } {
    # Already disconnected
    ::LOG "error (jlib::disconnect) Already disconnected"
    return -1
  }

  outmsg "</stream:stream>"
  close $lib(sck)

  wrapper:finish $lib(wrap)

  clear_iqs
  clear_vars
}

######################################################################
proc jlib::got_stream {vars} {
  #
  # Where is this used?  Why is it a no op?
  #
  ::LOG "(jlib::got_stream)"
}

######################################################################
proc jlib::end_of_parse {} {
  variable lib

  ::LOG "(jlib::end_of_parse)"
  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::end_of_parse) No connection"
    return -1
    # Already disconnected
  }

  catch {close $lib(sck)}

  clear_iqs
  clear_vars
  uplevel #0 "client:disconnect"
}

######################################################################
proc jlib::outmsg {msg} {
  variable lib

  ::LOG "(jlib::outmsg) '$msg'"

  catch { set msg [encoding convertto utf-8 $msg] }

  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::outmsg) No connection"
    return -1
  }

  if { [catch {puts $lib(sck) $msg}] != 0 } {
    ::LOG "error (jlib::outmsg) Cannot write to socket: $lib(sck)"
    return -2
  }
  ::LOG "(jlib::outmsg) SENT"
}

######################################################################
proc jlib::inmsg {} {
  variable lib

  ::LOG "inmsg called"
  if { $lib(sckstats) == "off" } {
    return
  }

  set temp ""
  catch { set temp [read $lib(sck)] }
  catch { set temp [encoding convertfrom utf-8 $temp] }

  ::LOG "(jlib::inmsg) '$temp'"
  wrapper:parser $lib(wrap) parse $temp

  if { $lib(sckstats) != "off" && [eof $lib(sck)] } {
    ::LOG "error (jlib::inmsg) Socket is closed by server. Disconnecting..."

    catch { close $lib(sck) }
    clear_iqs
    clear_vars
    uplevel #0 "client:disconnect"
  }
}

######################################################################
proc jlib::clear_vars {} {
  #
  # unset all the variables
  #
  variable roster
  variable pres
  variable lib
  variable iq

  foreach array [array names roster] {
    unset roster($array)
  }

  set roster(users) ""

  set lib(sck) ""
  set lib(sckstats) "off"

  set iq(num) 0

  wrapper:reset $lib(wrap)
}

######################################################################
proc jlib::clear_iqs {} {
  variable iq

  foreach id [array names iq] {
    if {$id != "num"} {
      uplevel #0 "$iq($id) DISCONNECT {}"
      unset iq($id)
    }
  }
}

######################################################################
proc jlib::parse {xmldata} {
  variable global
  variable roster
  variable pres
  variable lib
  variable iq

  ::LOG "(jlib::parse) xmldata:'$xmldata'"

  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::parse) No connection"
    return -1
  }

  set usefrom 0
  set from ""

  wrapper:splitxml $xmldata tag vars isempty chdata children
  if {[wrapper:isattr $vars from] == 1} {
    set usefrom 1
    set from [wrapper:getattr $vars from]
  }

  switch -- $tag {
    iq {
      set useid   0
      set id ""
      set type [wrapper:getattr $vars type]

      if {[wrapper:isattr $vars id] == 1} {
        set useid 1
        set id [wrapper:getattr $vars id]
      }

      if {$type != "result" && $type != "error" && $type != "get" && $type != "set"} {
        ::LOG "(error) iq: unknown type:'$type' id ($useid):'$id'"
        return
      }

      if {$type == "result"} {
        if {$useid == 0} {
          ::LOG "(error) iq:result: no id reference"
          return
        }
        if {[info exists iq($id)] == 0} {
          ::LOG "(error) iq:result: id doesn't exists in memory. Probably a re-replied iq"
          return
        }

        set cmd $iq($id)
        unset iq($id)

        uplevel #0 "$cmd OK [list [lindex $children 0]]"
      } elseif {$type == "error"} {
        if {$useid == 0} {
          ::LOG "(error) iq:result: no id reference"
          return
        }
        if {[info exists iq($id)] == 0} {
          ::LOG "(error) iq:result: id doesn't exists in memory. Probably a re-replied iq."
          return
        }

        set cmd $iq($id)
        unset iq($id)

        set child ""
        foreach child $children {
          if {[lindex $child 0] == "error"} {break}
          set child ""
        }
        if {$child == ""} {
          set errcode ""
          set errmsg ""
        } else {
          set errcode [wrapper:getattr [lindex $child 1] code]
          set errmsg [lindex $child 3]
        }

        uplevel #0 "$cmd ERR [list [list $errcode $errmsg]]"
      } elseif {$type == "get" || $type == "set"} {
        set child [lindex $children 0]

        if {$child == ""} {
          ::LOG "(error) iq:$type: Cannot find 'query' tag"
          return
        }

        #
        # Before calling the 'client:iqreply' procedure, we should check
        # the 'xmlns' attribute, to understand if this is some 'iq' that
        # should be handled inside jlib, such as a roster-push.
        #
        if {$type == "set" && [wrapper:getattr [lindex $child 1] xmlns] == "jabber:iq:roster"} {
          # Found a roster-push
          ::LOG "(info) iq packet is roster-push. Handling internally"

          # First, we reply to the server, saying that, we
          # got the data, and accepted it.
          #
          if [wrapper:isattr $vars "id"] {
            send_iq "result" [wrapper:createtag query \
                             -vars [list "xmlns" "jabber:iq:roster"]] \
                             -id [wrapper:getattr $vars "id"]
          } else {
            send_iq "result" [wrapper:createtag query \
                             -vars [list "xmlns" "jabber:iq:roster"]]
          }

          # And then, we call the jlib::parse_roster_get, because this
          # data is the same as the one we get from a roster-get.
          parse_roster_get 1 "[namespace current]::noop" "OK" $child
          return
        }

        uplevel #0 "client:iqreply [list $from] [list $useid] [list $id] [list $child]"
      }
    }
      message {
        set type [wrapper:getattr $vars type]

        set body     ""
        set errcode  ""
        set errmsg   ""
        set subject  ""
        set priority ""
        set thread   ""
        set x        ""

        foreach child $children {
          wrapper:splitxml $child ctag cvars cisempty cchdata cchildren

          switch -- $ctag {
            body     {set body $cchdata}
            error    {set errmsg $cchdata; set errcode [wrapper:getattr $cvars code]}
            subject  {set subject $cchdata}
            priority {set priority $cchdata}
            thread   {set thread $cchdata}
            x        {lappend x $child}
          }
        }

        uplevel #0 "client:message [list $from $type $subject $body [list $errcode $errmsg] $thread $priority $x]"
      }
      presence {
        set type [wrapper:getattr $vars type]

        set status   ""
        set priority ""
        set meta     ""
        set icon     ""
        set show     ""
        set loc      ""
        set x        ""

        set param    ""

        foreach child $children {
          wrapper:splitxml $child ctag cvars cisempty cchdata cchildren

          switch -- $ctag {
            status   { lappend param -status   $cchdata }
            priority { lappend param -priority $cchdata }
            meta     { lappend param -meta     $cchdata }
            icon     { lappend param -icon     $cchdata }
            show     { lappend param -show     $cchdata }
            loc      { lappend param -loc      $cchdata }
            x        { lappend x $child }
          }
        }

        uplevel #0 "client:presence [list $from $type $x] $param"
      }
  }
}

######################################################################
proc jlib::parse_send_auth {cmd type data} {
  variable lib

  ::LOG "(jlib::parse_send_auth) type:'$type'"

  if {$type == "ERR"} {           ;# Got an error reply
    ::LOG "error (jlib::parse_send_auth) errtype:'[lindex $data 0]'"
    ::LOG "error (jlib::parse_send_auth) errdesc:'[lindex $data 1]'"
    uplevel #0 "$cmd ERR [list $data]"
    return
  }
  uplevel #0 "$cmd OK {}"
}

######################################################################
proc jlib::parse_request_time {cmd type data} {
  variable lib

  ::LOG "(jlib::parse_request_time) type:'$type'"

  if {$type == "ERR"} {           ;# Got an error reply
    ::LOG "error (jlib::parse_request_time) errtype:'[lindex $data 0]'"
    ::LOG "error (jlib::parse_request_time) errdesc:'[lindex $data 1]'"
    uplevel #0 "$cmd ERR [list $data]"
    return
  }
  uplevel #0 "$cmd OK {}"
}

######################################################################
proc jlib::parse_send_create {cmd type data} {
  variable lib

  ::LOG "(jlib::parse_send_create) type:'$type'"

  if {$type == "ERR"} {           ;# Got an error reply
    ::LOG "error (jlib::parse_send_create) errtype:'[lindex $data 0]'"
    ::LOG "error (jlib::parse_send_create) errdesc:'[lindex $data 1]'"
    uplevel #0 "$cmd ERR [list [lindex $data 1]]"
    return
  }
  uplevel #0 "$cmd OK {}"
}

######################################################################
proc jlib::parse_roster_get {ispush cmd type data} {
  variable lib
  variable roster

  ::LOG "(jlib::parse_roster_get) ispush:'$ispush' type:'$type'"

  if {$type == "ERR"} {           ;# Got an error reply
    ::LOG "error (jlib::parse_roster_get) errtype:'[lindex $data 0]'"
    ::LOG "error (jlib::parse_roster_get) errdesc:'[lindex $data 1]'"
    uplevel #0 "$cmd ERR"
    return
  }
  if !$ispush {
    uplevel #0 "$cmd BEGIN_ROSTER"
  }

  wrapper:splitxml $data tag vars isempty chdata children

  if {[wrapper:getattr $vars xmlns] != "jabber:iq:roster"} {
    ::LOG "warning (jlib::parse_roster_get) 'xmlns' attribute of query tag doesn't match 'jabber:iq:roster': '[wrapper:getattr $vars xmlns]"
  }

  foreach child $children {
    wrapper:splitxml $child ctag cvars cisempty cchdata cchildren

    switch -- $ctag {
      item {
        set groups ""
        set jid   [wrapper:getattr $cvars jid]
        set name  [wrapper:getattr $cvars name]
        set subsc [wrapper:getattr $cvars subscription]
        set ask   [wrapper:getattr $cvars ask]

        foreach subchild $cchildren {
          wrapper:splitxml $subchild subtag tmp tmp subchdata tmp

          switch -- $subtag {
             group {lappend groups $subchdata}
          }
        }

        # Ok, collected information about item.
        # Now we can set our variables...
        #
        if {[lsearch $roster(users) $jid] == -1} {
          lappend roster(users) $jid
        }

        set roster(group,$jid) $groups
        set roster(name,$jid)  $name
        set roster(subsc,$jid) $subsc
        set roster(ask,$jid)   $ask

        # ...and call client procedures
        if $ispush {
          uplevel #0 "client:roster_push [list $jid] [list $name] [list $groups] [list $subsc] [list $ask]"
        } else {
          uplevel #0 "client:roster_item [list $jid] [list $name] [list $groups] [list $subsc] [list $ask]"
        }
      }
    }
  }
  if !$ispush {uplevel #0 "$cmd END_ROSTER"}
}

######################################################################
proc jlib::parse_roster_set {item cmd groups name type data} {
  variable lib
  variable roster

  ::LOG "(jlib::parse_roster_set) item:'$item' type:'$type'"

  if {$type == "ERR"} {           ;# Got an error reply
    ::LOG "error (jlib::parse_roster_set) errtype:'[lindex $data 0]'"
    ::LOG "error (jlib::parse_roster_set) errdesc:'[lindex $data 1]'"
    uplevel #0 "$cmd ERR"
    return
  }

  if { [lsearch $roster(users) $item] == -1}   {
    lappend roster(users) $item
    set roster(subsc,$item) "none"
    set roster(ask,$item)   ""
  }

  set roster(group,$item) $groups
  set roster(name,$item)  $name

  uplevel #0 "$cmd OK"
}

######################################################################
proc jlib::parse_roster_del {item cmd type data} {
  variable lib
  variable roster

  ::LOG "(jlib::parse_roster_del) item:'$item' type:'$type'"

  if {$type == "ERR"} {           ;# Got an error reply
    ::LOG "error (jlib::parse_roster_set) errtype:'[lindex $data 0]'"
    ::LOG "error (jlib::parse_roster_set) errdesc:'[lindex $data 1]'"
    uplevel #0 "$cmd ERR"
    return
  }

  if {[set num [lsearch $roster(users) $item]] != -1} {
    set roster(users) [lreplace $roster(users) $num $num]

    catch {unset roster(group,$item) }
    catch {unset roster(name,$item)  }
    catch {unset roster(subsc,$item) }
    catch {unset roster(ask,$item)   }
  } else {
    ::LOG "warning (jlib::parse_roster_del) Item '$item' doesn't exist in roster for deletion."
  }
  uplevel #0 "$cmd OK"
}

######################################################################
proc jlib::send_iq {type xmldata args} {
  variable lib
  variable iq

  ::LOG "in send_iq"
  ::LOG "xmldata: $xmldata"
  ::LOG "args: $args"
  ::LOG "type: $type"

  ::LOG "(jlib::send_iq) type:'$type'"
  ::LOG "socket stats: $lib(sckstats)"
  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::send_iq) No connection"
    return -1
  }

  set useto 0
  set useid 0
  set to    ""
  set id    ""
  set cmd   "[namespace current]::noop"
  set vars  ""

  foreach {attr val} $args {
    ::LOG "Handling attr $attr with val $val"
    switch -- $attr {
      -command {set cmd $val}
      -to      {set useto 1; set to $val}
      -id      {set useid 1; set id $val}
    }
  }
  if { $type != "set" && $type != "result" && $type != "error"} {
    set type "get"
  }

  ::LOG "(jlib::send_iq) type:'$type' to ($useto):'$to' cmd:'$cmd' xmldata:'$xmldata'"

  if { $type == "error"} {
    set xmldata [lreplace $xmldata 0 0 "error"]
  }

  if { $type == "get" || $type == "set"} {
    ::LOG "type is $type"
    lappend vars "id" $iq(num)
    set iq($iq(num)) $cmd
    incr iq(num)
  } elseif { $useid == 1 } {
    lappend vars "id" $id
  }

  if { $useto == 1 } {
    ::LOG "useto: 1"
    lappend vars "to" $to
  }
  lappend vars "type" $type

  if {$xmldata != ""} {
    set data [wrapper:createtag iq -vars $vars -subtags [list $xmldata]]
  } else {
    set data [wrapper:createtag iq -vars $vars]
  }
  ::LOG "xmldata is $xmldata"
  ::LOG "data is $data"
  outmsg [wrapper:createxml $data]
}

######################################################################
proc jlib::send_auth {user pass res cmd} {
  variable lib

  ::LOG "(jlib::send_auth) username:'$user' password:'$pass' resource:'$res'"
  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::send_auth) No connection"
    return -1
  }

  set data [wrapper:createtag query \
                                    -vars    [list xmlns "jabber:iq:auth"] \
                                    -subtags [list \
                                                   [wrapper:createtag username -chdata $user] \
                                                   [wrapper:createtag password -chdata $pass] \
                                                   [wrapper:createtag resource -chdata $res]]]

  ::LOG "sending iq from send_auth"
  send_iq set $data -command "[namespace current]::parse_send_auth [list $cmd]"
}

######################################################################
proc jlib::request_time {host cmd} {
  variable lib

  ::LOG "(jlib::request_time) called"
  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::request_time) No connection"
    return -1
  }

  set data [wrapper:createtag query \
                              -vars    [list xmlns "jabber:iq:time"] ]

  send_iq get $data -to "$host" -command "[namespace current]::parse_request_time [list $cmd]"
}

######################################################################
proc jlib::send_create {user pass name mail cmd} {
  variable lib

  ::LOG "(jlib::send_create) username:'$user' password:'$pass' name:'$name' email:'$mail'"
  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::send_create) No connection"
    return -1
  }

  set data [wrapper:createtag query \
            -vars    [list xmlns "jabber:iq:register"] \
            -subtags [list \
                           [wrapper:createtag name     -chdata $name] \
                           [wrapper:createtag email    -chdata $mail] \
                           [wrapper:createtag username -chdata $user] \
                           [wrapper:createtag password -chdata $pass]]]

  send_iq set $data -command "[namespace current]::parse_send_create [list $cmd]"
}

######################################################################
proc jlib::send_msg {to args} {
  variable lib

  ::LOG "(jlib::send_msg) to:'$to'"
  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::send_msg) No connection"
    return -1
  }

  set children ""

  if {[wrapper:isattr $args -subject] == 1}  {
    lappend children [wrapper:createtag subject  -chdata [wrapper:getattr $args -subject]]
  }
  if {[wrapper:isattr $args -thread] == 1}   {
    lappend children [wrapper:createtag thread   -chdata [wrapper:getattr $args -subject]]
  }
  if {[wrapper:isattr $args -priority] == 1} {
    lappend children [wrapper:createtag priority -chdata [wrapper:getattr $args -subject]]
  }
  if {[wrapper:isattr $args -body] == 1}     {
    lappend children [wrapper:createtag body     -chdata [wrapper:getattr $args -body]]
  }
  if {[wrapper:isattr $args -xlist] == 1}    {
    foreach a [wrapper:getattr $args -xlist] {
      lappend children $a
    }
  }

  set vars [list "to" $to]
  if {[wrapper:isattr $args -type] == 1} {lappend vars "type" [wrapper:getattr $args -type]}

  outmsg [wrapper:createxml [wrapper:createtag message -vars $vars -subtags $children]]
}

######################################################################
proc jlib::send_presence {args} {
  variable lib

  ::LOG "(jlib::send_presence) $args"
  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::send_presence) No connection"
    return -1
  }

  set children ""
  set vars     ""

  if [wrapper:isattr $args -to]   {
    lappend vars to   [wrapper:getattr $args -to]
  }
  if [wrapper:isattr $args -type] {
    lappend vars type [wrapper:getattr $args -type]
  }

  if [wrapper:isattr $args -stat] {
    lappend children [wrapper:createtag status   -chdata [wrapper:getattr $args -stat]]
  }
  if [wrapper:isattr $args -pri]  {
    lappend children [wrapper:createtag priority -chdata [wrapper:getattr $args -pri]]
  }
  if [wrapper:isattr $args -meta] {
    lappend children [wrapper:createtag meta     -chdata [wrapper:getattr $args -meta]]
  }
  if [wrapper:isattr $args -icon] {
    lappend children [wrapper:createtag icon     -chdata [wrapper:getattr $args -icon]]
  }
  if [wrapper:isattr $args -show] {
    lappend children [wrapper:createtag show     -chdata [wrapper:getattr $args -show]]
  }
  if [wrapper:isattr $args -loc] {
    lappend children [wrapper:createtag loc      -chdata [wrapper:getattr $args -loc]]
  }

  if [wrapper:isattr $args -xlist] {
    foreach a [wrapper:getattr $args -xlist] {
      lappend children $a
    }
  }

  outmsg [wrapper:createxml [wrapper:createtag presence -vars $vars -subtags $children]]
}

######################################################################
proc jlib::roster_get {args} {
  variable lib
  variable roster

  ::LOG "(jlib::roster_get)"
  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::roster_get) No connection"
    return -1
  }

  if [wrapper:isattr $args -command] {
    set cmd [wrapper:getattr $args -command]
  } else {
    set cmd "[namespace current]::noop"
  }

  foreach array [array names roster] {unset roster($array)}
  set roster(users) ""

  set vars [list xmlns "jabber:iq:roster"]
  set data [wrapper:createtag query -empty 1 -vars $vars]
  send_iq get $data -command "[namespace current]::parse_roster_get 0 [list $cmd]"
}

######################################################################
proc jlib::roster_set {item args} {
  variable lib
  variable roster

  ::LOG "(jlib::roster_set) item:'$item'"
  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::roster_set) No connection"
    return -1
  }

  set usename 0; set name ""
  if { [lsearch $roster(users) $item] == -1 } {
    set groups ""
  } else {
    set groups $roster(group,$item)
  }

  if [wrapper:isattr $args "-name"] {
    set usename 1; set name [wrapper:getattr $args "-name"]
  }
  if [wrapper:isattr $args "-groups"] {
    set groups [wrapper:getattr $args "-groups"]
  }
  if [wrapper:isattr $args "-command"] {
    set cmd    [wrapper:getattr $args "-command"]
  } else {
    set cmd "[namespace current]::noop"
  }

  set vars [list jid $item]
  if $usename  {lappend vars name $name }

  set subdata ""
  foreach group $groups {
    lappend subdata [wrapper:createtag group -chdata $group]
  }

  set xmldata [wrapper:createtag query \
     -vars    [list xmlns "jabber:iq:roster"] \
     -subtags [list [wrapper:createtag item -vars $vars -subtags $subdata]]]

  send_iq set $xmldata -command "[namespace current]::parse_roster_set [list $item $cmd $groups $name]"
}

######################################################################
proc jlib::roster_del {item args} {
  variable lib
  variable roster

  ::LOG "(jlib::roster_del) item:'$item'"
  if { $lib(sckstats) == "off" } {
    ::LOG "error (jlib::roster_del) No connection"
    return -1
  }

  if [wrapper:isattr $args -command] {
    set cmd [wrapper:getattr $args -command]
  } else {
    set cmd "[namespace current]::noop"
  }

  set xmldata [wrapper:createtag query \
     -vars    [list xmlns "jabber:iq:roster"] \
     -subtags [list [wrapper:createtag item -vars [list jid $item subscription "remove"]]]]

  send_iq set $xmldata -command "[namespace current]::parse_roster_del [list $item $cmd]"
}

######################################################################
#
proc ::LOG text {
  #
  # For debugging purposes.
  #

  putlog "LOG: $text\n"
}

######################################################################
proc jlib::noop args {}

######################################################################
#
# Now that we're done...
#
jlib::clear_vars
package provide jabberlib 0.8.2

