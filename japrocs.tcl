##############################################################################
#
# Eggdrop Jabber Bot - proc lib
# Copyright (C) 2003-2004 by Tim Niemueller <tim@niemueller.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# Created  : April 2003
#
# $Id: japrocs.tcl,v 1.1 2004/01/23 01:58:27 tim Exp $
#
##############################################################################

set jabot(version) "v0.3"

set roster(users) ""
set pres(stat) "This is my presence"
set pres(pri)  25
set pres(meta) "EggJaBot/$jabot(version)"
set pres(show) "offline"
set pres(loc)  ""
set pres(x)    ""

set checkconn_sent 0
set checkconn_rcvd 0
set checkconn_tries 0


####
#### Connection related procs
####

proc jabot:connect {} {
global jabot checkconn_sent checkconn_rcvd

  set jabot(connected) 0
  set checkconn_sent 0
  set checkconn_rcvd 0

  if {[catch {set jabot(socket) [socket $jabot(host) $jabot(port)]}] != 0} {
    putlog "Could not connect to Jabber host"
    return -1
  }
  if {[jlib::connect $jabot(socket) $jabot(host)] != 0} {
    return -2
  }
  jlib::send_auth $jabot(userid) $jabot(password) $jabot(resource) "jabot:login_cback"
}


proc jabot:login_cback {type data} {
global jabot
  set jabot(connected) 0

  if {$type == "OK"} {
    putlog "EggJaBot: Logged in to Jabber host $jabot(host) successfully\n"

    jlib::roster_get -command "client:roster"
    jlib::send_presence
    set jabot(connected) 1

  } elseif {$type == "ERR"} {
    putlog "Login to Jabber host FAILED"
  } elseif {$type == "DISCONNECT"} {
    putlog "Login to Jabber host FAILED. Got a DISCONNECT message."
  }
}


proc jabot:disconnect {type} {
global jabot
  catch { jlib::disconnect }
  catch { unset jabot(socket) }
  set jabot(connected) 0
}

proc jabot:reconnect {} {
  putlog "JaBot: Reconnecting"
  jabot:disconnect "OK"
  jabot:connect
}

proc jabot:checkconn_cback {type data} {
  global checkconn_rcvd

  if { $type == "ERR" } {
    jabot:reconnect
  } else {
    set checkconn_rcvd 1
  }
}

proc jabot:checkconn {} {
global jabot checkconn_sent checkconn_rcvd roster pres
  # putlog "EggJaBot is checking connection"

  set icqjid "$jabot(ICQ)@icq.$jabot(host)"
  set icqres [lindex $roster(users,$icqjid) 0]
  set icqstat $pres(status,$icqjid/$icqres)

  if {[string compare $icqstat "Online"] != 0} {
    # If ICQ Transport is offline reconnect
    putlog "ICQ Transport is offline (forgot to add myself?)"
    putlog "J: $icqjid - R: $icqres - S: $icqstat"
    if {$checkconn_tries > $jabot(checkmaxtries)} {
      putlog "Reached maximum number of retries ($jabot(checkmaxtries)), will not reconnect."
    } else {
      timer 10 jabot:checkconn
      jabot:reconnect
      set checkconn_tries $checkconn_tries+1
    }
  } else {
    # check Jabber overall status
    if { $checkconn_sent } {
      if { !$checkconn_rcvd } {
        if {$checkconn_tries > $jabot(checkmaxtries)} {
          putlog "Jabber connection lost but maximum number of retries ($jabot(checkmaxtries)) reached. Will not reconnect."
        } else {
          timer 10 jabot:checkconn
          jabot:reconnect
        }
      } else {
        set checkconn_sent 0
        set checkconn_rcvd 0
        timer 5 jabot:checkconn
      }
    } else {
      jlib::request_time $jabot(host) jabot:checkconn_cback
      set checkconn_sent 1
      utimer 10 jabot:checkconn
    }
  }
}



proc jabot:add_cback {type} {
global jabot
  if {$type == "OK"} {
    putlog "Successfully added user"
  } else {
    putlog "Failed adding user"
  }
}

####
#### Invite procs
####

proc jabot:checkinvite {} {
global jabot invite_respondok
  set jabot(inviteok) 1
  set invite_respondok [list]
}

proc jabot:inviteok {hand idx text} {
global jabot
  jabot:checkinvite
}

####
#### DCC commands
####

proc jabot:status {hand idx text} {
global jabot

  putdcc $idx ""
  putdcc $idx "\002EggJaBot $jabot(version) Status\002"
  putdcc $idx "============================================================"

  if {$jabot(connected)} {
    putdcc $idx "Jabber online .. Yes"
  } else {
    putdcc $idx "Jabber online .. No"
  }

  if {$jabot(inviteok)} {
    putdcc $idx "Invite OK ...... Yes"
  } else {
    putdcc $idx "Invite OK ...... No"
  }
  putdcc $idx ""
}


proc jabot:showroster {hand idx text} {
global pres roster jabot

  putdcc $idx ""
  putdcc $idx "\002EggJaBot $jabot(version) Roster\002"
  putdcc $idx "============================================================"
  foreach jid $roster(users) {
    if {[llength $roster(users,$jid)] == 0} {
      putdcc $idx "\002\00315$jid\00315\002"
    } else {
      putdcc $idx "\002$jid\002"
    }
    putdcc $idx "  - Name:   $roster(name,$jid)"
    foreach res $roster(users,$jid) {
      putdcc $idx "  - Status: $pres(status,$jid/$res)"
    }
  }
  putdcc $idx ""
}


proc jabot:check {hand idx text} {
  jabot:checkconn
}


proc jabot:disco {hand idx text} {
  jabot:disconnect "NOW"
}


####
#### Public and msg commands
####

proc jabot:msgowner {nick uhost hand chan text} {
global jabot botnick
  if {[string length $text] > 0} {
    set now [clock format [clock seconds] -format "%a, %Y/%m/%d %H:%M:%S"]
    jlib::send_msg $jabot(admin) -body "On $now $nick wrote:\n$text"
    putserv "PRIVMSG $chan :$nick: Message sent to owner ($now)"
    putloglev p $chan "<$botnick> $nick: Message sent to owner ($now)"
  } else {
    putserv "PRIVMSG $chan :$nick: Usage is !jabot:msgowner <message>"
    putloglev p $chan "<$botnick> $nick: Usage is !jabot:msgowner <message>"
  }
}


proc jabot:invite {nick uhost hand chan text} {
global jabot roster pres botnick invite_respondok

  putloglev p $chan "BotAction: $nick asked for invitations"
  if {[validuser $hand]} {
    if {$jabot(inviteok)} {
      if {[string length $text] > 0} {
        set now [clock format [clock seconds] -format "%a, %Y/%m/%d %H:%M:%S"]
        set sentto ""
        foreach jid $roster(users) {
          if {[llength $roster(users,$jid)] > 0} {
            if {[string first $jabot(ICQ) "$jid@"] != 0} {
              foreach res $roster(users,$jid) {
                #putlog "Invite JID: $jid/$res"
                lappend invite_respondok $jid
                jlib::send_msg $jid -body "On $now $nick invited you to IRC (channel $chan):\n$text\n-- \nYou may respond with 1 message to this invitation which will be forwarded into the IRC channel."
                putlog "Sent invitation message to $jid (initiated by $nick, whose handle is $hand)"
                lappend sentto $jid
              }
            }
          } else {
            putlog "$jid seems to be offline or is a transport"
          }
        }
    
        putserv "PRIVMSG $chan :$nick: Sent invitations around"
        putloglev p $chan "BotAction: $botnick sent invitations around"
        set jabot(inviteok) 0
        timer $jabot(invitedelay) jabot:checkinvite
      } else {
        puthelp "PRIVMSG $chan :$nick: Usage is !jabot:invite <reason>"
        putloglev p $chan "<$botnick> $nick: Usage is !jabot:invite <reason>"
      }
    } else {
      puthelp "PRIVMSG $chan :$nick: Invitation can only be done once every $jabot(invitedelay) minutes."
      putloglev p $chan "<$botnick> $nick: Invitation can only be done once every $jabot(invitedelay) minutes."
    }
  } else {
    puthelp "PRIVMSG $chan :$nick: This service is only available to registered users."
    putloglev p $chan "<$botnick> $nick: This service is only available to registered users."
  }
}


proc jabot:help {nick uhost hand chan text} {
global jabot roster pres botnick
  puthelp "NOTICE $nick :\002What you can do with EggJaBot\002"
  puthelp "NOTICE $nick :======================================================================="
  puthelp "NOTICE $nick :\002\00315Public Commands, just shout them into the channel\002\00300"
  puthelp "NOTICE $nick :\002\00315!jabot:msgowner\00300\002 Send message to owner ($jabot(admin_name))"
  puthelp "NOTICE $nick :\002\00315!jabot:invite\00300\002 Invite users who requested this feature to come into this channel"
  puthelp "NOTICE $nick :======================================================================="
  puthelp "NOTICE $nick :\002\00315Private Commands, Use with \"/msg $jabot(name) <command>\"\002\00300"
  puthelp "NOTICE $nick :\002\00315jabot:msgowner\00300\002 Send message to owner ($jabot(admin_name))"
  puthelp "NOTICE $nick :\002\00315jabot:set\00300\002 Set your IM details. Give this command with no argument to see usage."
}


proc jabot:set {nick uhost hand arg} {
global jabot roster pres lastbind botnick supported_ims

  set args [split $arg " "]
  set pass [lindex $args 1]

  if {[validuser $hand]} {

    if {[llength $args] < 2} {
      set ims [join $supported_ims ", "]
      puthelp "NOTICE $nick :\002Usage:\002 /msg $botnick jabot:set <item> <pass> \[new value\]" 
      puthelp "NOTICE $nick :Where the fields are:" 
      puthelp "NOTICE $nick :\002item:\002      one of $ims" 
      puthelp "NOTICE $nick :\002password:\002  The password you registered with on $botnick"
      puthelp "NOTICE $nick :\002new value:\002 The new value for this setting. Use 'none' to unset value"
      puthelp "NOTICE $nick :           If new value is not given current value is shown"
    } else {
      if {[passwdok $hand $pass]} {
        set cmd [string toupper [lindex $args 0]]
        set val [lindex $args 2]

        #putlog "Called from $nick ($hand) for $cmd to $val"

        if {[lsearch $supported_ims $cmd] == -1} {
          puthelp "NOTICE $nick :Unknown setting '$cmd'."
          return
        }

        set oldval [getuser $hand XTRA $cmd];
        if {[string compare $cmd ICQ] == 0} {
          set jid "$val@icq.$jabot(host)"
          set oldjid "$oldval@icq.$jabot(host)"
        } else {
          set jid $val
          set oldjid $oldval
        }

        if {[string compare $val ""] == 0} {
          # It's a get
          if {[string compare $oldval ""] == 0} {
            putserv "NOTICE $nick :Your current $cmd is not set"
          } else {
            putserv "NOTICE $nick :Your current $cmd is: $oldval"
          }
        } elseif {[string tolower $val] == "none"} {
          setuser $hand XTRA $cmd ""

          if {[lsearch $roster(users) $oldjid] != -1} {
            #User IS in roster
            putlog "Removing JID $oldjid"
            jlib::roster_del $oldjid ""
            jlib::send_presence -to $oldjid -type "unsubscribe"
            putserv "NOTICE $nick :I have removed your $cmd $oldval from my roster. You can now remove $cmd $jabot($cmd) from your roster."
          }
          putserv "NOTICE $nick :Your $cmd has been removed."

        } else {

          setuser $hand XTRA $cmd $val

          if {$oldval != $val} {
            # Unsubscribe old JID
            # This can happen on change and on new add so check if user oldjid really exists
            if {[lsearch $roster(users) $oldjid] != -1} {
              #User IS in roster
              putlog "Removing JID $oldjid cause of JID change"
              jlib::roster_del $oldjid ""
              jlib::send_presence -to $oldjid -type "unsubscribe"
              putserv "NOTICE $nick :I have removed your $cmd $oldval from my roster. You can now remove $cmd $jabot($cmd) from your roster."
            } else {
              putlog "JID $oldjid not in roster"
            }
          }

          if {[lsearch $roster(users) $jid] == -1} {
            # Subscribe new JID
            putlog "Adding JID $jid"

            jlib::roster_set $jid -name $hand -groups [list "Invites"] -command "jabot:add_cback"
            jlib::send_presence -to $jid -type "subscribe" -stat $jabot(subscribe_reason)

            putserv "NOTICE $nick :I have added your $cmd $val to my roster. Please add $cmd $jabot($cmd) to you roster now."
          }

          if { $oldval == $val } {
            putserv "NOTICE $nick :Your $cmd remained unchanged"
          } elseif { [string length $oldval] > 0 } {
            putserv "NOTICE $nick :Your old $cmd was: $oldval. Your new $cmd is $val"
          } else {
            putserv "NOTICE $nick :Your new $cmd is $val"
          }
        }

      } else {
        puthelp "NOTICE $nick :Invalid password"
      }
    }
  } else {
    puthelp "NOTICE $nick :Sorry, this is only available to registered users. Try !jabot:help register for info on that"
  }
}




####
####  Jabber Lib callbacks
####

proc client:iqreply {from useid id child} {
  putlog "received iqreply from $from, useid = $useid, id = $id, child = $child"
}

proc client:message {from type subject body extbody thread pri x} {
global perlbin perleliza jabot invite_respondok botnick roster

  set a   [jabot:splitjid $from]
  set jid [lindex $a 0]
  set jidindex -1
  putlog "Received - $jid - $body"

  if { $jabot(inviteok) } {
    set jidindex -1
  } else {
    if { [llength $invite_respondok] > 0 } {
      if {[catch { set jidindex [lsearch $invite_respondok $jid] }] != 0} {
        set jidindex -1
      }
      if { $jidindex == -1 } {
        jlib::send_msg $from -body "You did already send a message. Join the channel if you have to say more."
      }
    }
  }

  if {$jidindex == -1} {
    if {$jabot(useeliza) == 1} {
      set f [open "|$perlbin $perleliza $jabot(name) $body"]
      set output [read $f]
      close $f

      jlib::send_msg $from -body "$output"
      putlog "Received Message via Jabber:\n$from: $body\nMy answer was:$output"
    } else {
      putlog "Received Message via Jabber:\n$from: $body\nI did not answer. Eliza disabled."
    }
  } else {
    set invite_respondok [lreplace $invite_respondok $jidindex $jidindex]
    putserv "PRIVMSG $jabot(channel) :$roster(name,$jid) answered: $body"
    putloglev p $jabot(channel) "<$botnick>: $roster(name,$jid) answered: $body"
  }
}


proc client:roster_del {jid} {
global jabot roster pres

  if {[lsearch $roster(users) $jid] == -1} {return}

  foreach res $roster(users,$jid) {
    catch { unset pres(type,$jid/$res)   }
    catch { unset pres(status,$jid/$res) }
    catch { unset pres(pri,$jid/$res)    }
    catch { unset pres(meta,$jid/$res)   }
    catch { unset pres(icon,$jid/$res)   }
    catch { unset pres(show,$jid/$res)   }
    catch { unset pres(loc,$jid/$res)    }
    catch { unset pres(x,$jid/$res)      }
  }

  catch { unset roster(users,$jid) }
  catch { unset roster(group,$jid) }
  catch { unset roster(name,$jid)  }
  catch { unset roster(subsc,$jid) }
  catch { unset roster(ask,$jid)   }

  #putlog "before: $roster(users)"

  if {[set jidpos [lsearch $roster(users) $jid]] != -1} {
    set roster(users) [lreplace $roster(users) $jidpos $jidpos]
  }

  #putlog "after: $roster(users) (jidpos=$jidpos)"
}

proc client:roster {stat} {
global jabot roster pres

  #putlog "roster called"
  # Do nothing right now
  if {$stat == "BEGIN_ROSTER"} {

    # Clear our roster
    foreach jid $roster(users) {
      client:roster_del $jid
    }

    set jabot(in_roster) 1
  } elseif {$stat == "END_ROSTER"} {
    set jabot(in_roster) 0
  }
}                                                                                          

proc client:roster_item {jid name grps subsc ask} {
global roster jabot

  if !$jabot(in_roster) {return}

  #putlog "(client:roster_item) jid:'$jid' name:'$name' grps:'$grps' subsc:'$subsc' ask:'$ask'"

  set a ""
  foreach grp $grps {
    if {$grp != ""} {lappend a $grp}
  }

  set grps $a

  if {[lsearch $roster(users) $jid] == -1} {lappend roster(users) $jid}
  set roster(users,$jid) ""
  set roster(name,$jid)  $name
  set roster(group,$jid) $grps
  set roster(subsc,$jid) $subsc
  set roster(ask,$jid)   $ask

}

proc client:roster_push {jid name grps subsc ask} {
#
# This gets called when I subscribe to someone or they
# subscribe to me.

global jabot roster pres

  #putlog "Roster push JID $jid name $name grps $grps subsc $subsc ask $ask"
  #putlog "Before Roster push roster is $roster(users)"

  if {$subsc == "remove"} {
    #putlog "Removing $jid from roster"
    client:roster_del $jid
  } else {
    #putlog "Adding $jid to roster"

    set a ""
    foreach grp $grps {
    if {$grp != ""} {lappend a $grp}
    }
    set grps $a
  
    if {[lsearch $roster(users) $jid] == -1} {
      lappend roster(users) $jid
      set roster(users,$jid) ""
    }
    set roster(name,$jid)  $name
    set roster(group,$jid) $grps
    set roster(subsc,$jid) $subsc
    set roster(ask,$jid)   $ask
  }

  #putlog "After Roster push roster is $roster(users)"
}


proc client:disconnect {} {
  ::LOG "We got disconnected"
  jabot:reconnect
}


proc jabot:splitjid {jid} {
  #
  # This proc splits the given jid to username and resource.
  #
  set idx [string first / $jid]
  if {$idx == -1} {return [list $jid ""]}

  set user [string range $jid 0 [expr $idx - 1]]
  set res  [string range $jid [expr $idx + 1] end]

  return [list $user $res]
}


proc client:presence {from type xlist args} {
global roster pres jabot

  set a   [jabot:splitjid $from]
  set jid [lindex $a 0]
  set res [lindex $a 1]

  set users [userlist]
  set founduser 0

  foreach u $users {
    set ujid [getuser $u XTRA JID]
    set uicq [getuser $u XTRA ICQ]
    if {[string length $ujid] > 0} {
      # User has a JID
      if {[string compare $ujid $jid] == 0} {
        #putlog "$u has JID $ujid"
        set founduser 1
        break
      }
    }
    if {! $founduser} {
      if {[string length $uicq] > 0} {
        # User has a ICQ UIN
        if {[string first $uicq "$jid@"] == 0} {
          #putlog "$u has UIN $uicq"
          set founduser 1
          break
        }
      }
    }
  }
  if {[string compare $jid $jabot(JID)] == 0} {
    set founduser 1
  }
  if {[string first $jabot(ICQ) "$jid@"] == 0} {
    set founduser 1
  }

  #putlog "Presence for $from ($args). Type: $type"
  set stat ""
  foreach {attr val} $args {
        switch -- $attr {
                -status   {set stat $val}
                -priority {set pri  $val}
                -meta     {set meta $val}
                -show     {set show $val}
                -loc      {set loc  $val}
        }
  }

  #
  # Another user is requesting to subscribe to my presence (put me on his roster)
  #

  if {$type == "subscribe"} {
    if {$founduser == 1} {
      putlog "Allowed $jid to add me to his roster"
      jlib::send_presence -to [list $jid] -type "subscribed"
    } else {
      putlog "Rejected subscribe request from $jid ($from): $stat"
      jlib::send_msg $from -body "Sorry, but you have not registered with botnick on IRC. You have to do so before being able to add me to your contact list."
      jlib::send_presence -to $from -type "unsubscribed"
    }
    return
  }

  # user authorized us to register him
  if {$type == "subscribed"} {
    #putlog "Received SUBSCRIBED message. Not handled"
    return
  }

  #
  # Another user is unsubscribing from me
  #
  if {$type == "unsubscribe"} {
    #putlog "Received UN-SUBSCRIBE message. Not handled"
    return
  }

  #
  # I have been unsubscribed from my friend's presence
  #
  if {$type == "unsubscribed"} {
    #putlog "Received UN-SUBSCRIBED message. Not handled"
    return
  }

  #
  # Do not accept presences from unknown jids
  #
  if {[lsearch $roster(users) $jid] == -1} {return}

  if {$founduser} {
    #
    # Create presence if it doesn't exist
    #
    if {[lsearch $roster(users,$jid) $res] == -1} {
      #
      # I just got presence from someone who's not yet
      # in my roster.  So, add him.
      #
     # putlog "Presence Roster Resource Append for JID $jid and Resource $res"
                                                                                      
      lappend roster(users,$jid) $res
                                                                                      
      set pres(type,$jid/$res)   "unavailable"
      set pres(status,$jid/$res) ""
      set pres(pri,$jid/$res)    0
      set pres(meta,$jid/$res)   ""
      set pres(show,$jid/$res)   ""
      set pres(loc,$jid/$res)    ""
      set pres(x,$jid/$res)      ""
    }

    #
    # Finally, we deal with the case where type is "unavailable"
    #
    if {$type == "unavailable"} {
      set pres(type,$jid/$res) "unavailable"
    } else {
      set pres(type,$jid/$res) ""
    }

    #
    # Now, we're just about done.  Now, set the presence
    # info according to the arguments that were passed in.
    #
    #putlog "Setting pres values for JID $jid"
    if [info exists stat] {set pres(status,$jid/$res) $stat }
    if [info exists pri ] {set pres(pri,$jid/$res)    $pri  }
    if [info exists meta] {set pres(meta,$jid/$res)   $meta }
    if [info exists show] {set pres(show,$jid/$res)   $show }
    if [info exists loc ] {set pres(loc,$jid/$res)    $loc  }
  } else {
    # We have a user which is not registered but on my roster => delete
    putlog "$jid is not a user => delete it from roster"
    jlib::roster_del $jid ""
    jlib::send_presence -to $jid -type "unsubscribe"
  }

}

