##############################################################################
#
# Eggdrop Jabber Bot
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
# $Id: jabot.tcl,v 1.1 2004/01/23 01:58:27 tim Exp $
#
##############################################################################

###CONFIGSTART###

# Where are you eggdrop scripts? This has to contain the jabber subdir
set scriptsdir "/server/irc/eggdrop/scripts"

# The name of your Eggdrop
set jabot(name) "Fangorn"

# Userid to login with at the Jabber server
set jabot(userid) "fangorn"

# The channel we are sitting on, only one right now!
set jabot(channel) "#math"

# The server to connect to
set jabot(host) "openhotspots.net"

# The port to connect to
set jabot(port) 5222

# The password for the Jabber account
set jabot(password) "jabpwd"

# The resource to use
set jabot(resource) "jabot"

# The JID of the owner, msgowner messages will go there
set jabot(admin) "tim@openhotspots.net/Aachen"

# Name string to display to users as admin
set jabot(admin_name) "Tim"

# The text to send when we request authorization for adding a user
# to our roster
set jabot(subscribe_reason) "You registered your Instant Messanger ID with $jabot(name) on IRC"

# The bot's JID
set jabot(JID) "fangorn@openhotspots.net"

# The bot's UIN
set jabot(ICQ) "202719701"

# The delay in minutes after which a new invite can start
set jabot(invitedelay) 5

# Use Eliza to respond to instant messages?
# This needs Perl and Chatbot::Eliza
set jabot(useeliza) 1

# The full path to Perl, only needed if useeliza is 1
set perlbin "/usr/bin/perl"

# The full path to the eliza Perl script, only needed if useeliza is 1
set perleliza "/server/irc/eggdrop/scripts/jabber/eliza.pl"

###CONFIGEND###
#
# DO NOT CHANGE ANYTHING BELOW THIS LINE!

source [file join $scriptsdir "jabber" "jabberlib" "jabberlib.tcl"]
source [file join $scriptsdir "jabber" "japrocs.tcl"]

package require jabberlib 0.8.2
set supported_ims "JID ICQ"
set jabot(inviteok) 1
set invite_respondok [list]

# Bind commands
bind pub - !jabot:msgowner jabot:msgowner
bind pub - !jabot:invite jabot:invite
bind pub - !jabot:help jabot:help
bind msg - jabot:msgowner jabot:msgowner
bind msg - jabot:set jabot:set

# bind events
bind evnt - sighup jabot:disconnect
bind evnt - sigterm jabot:disconnect
bind evnt - sigill jabot:disconnect
bind evnt - sigquit jabot:disconnect
bind evnt - prerestart jabot:disconnect
bind evnt - prerehash jabot:disconnect

# bind dcc commands
bind dcc m jabot:roster jabot:showroster
bind dcc m jabot:inviteok jabot:inviteok
bind dcc m jabot:status jabot:status
bind dcc m jabot:check jabot:check
bind dcc m jabot:disconnect jabot:disco


# Clear and set timers
set alltimers [timers]

for {set i 0} {$i < [llength $alltimers]} {incr i} {
  set this [lindex $alltimers $i]
  if {[string first "jabot:" [lindex $this 1]] == 0} {
    putlog "Killing timer for proc [lindex $this 1]"
    killtimer [lindex $this 2]
  }
}

# We check the connection in 10 minutes
timer 10 jabot:checkconn

# Connect to Jabber
jabot:connect

putlog "EggJaBot $jabot(version) by Tim Niemueller \[http://www.niemueller.de\] loaded"

