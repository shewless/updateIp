#!/usr/local/bin/tclsh8.6

# updateIp.tcl
# This is a simple script that will detect the server's external IP address 
# (as seen by the outside world) and update your domain's A Record via FreeDNS
# (freedns.afraid.org).  Of course this implies that you have changed your
# domain to use freedns's nameservers and have your domain configured there
# (it's free!) 

# This script should be run as part of a cron job every ~5 minutes

# Usage:
# Check for updates and apply as necessary:
# ./updateIp.tcl
# Force an update
# ./updateIp.tcl true

#-----BEGIN USER GLOBALS SECTION-----#
# File in which to write logs (should use syslog to rotate)
set g_logFile "/var/log/updateIp.log"

# File that stores the current IP of the server 
# (will be maintained by this script)
set g_currentIp "/usr/local/www/updateIp/currentIp.conf"

# Authentication token that is generated and obtained from FreeDNS for
# your spefic domain
set g_authToken [list U2lSMUlBQUoz_______x2 U2lSMUta2Vz_________x3]
#------END USER GLOBALS SECTION------#

package require http

# Logs "msg" along with a timestamp to g_logFile
proc logger {msg} \
{
    global g_logFile
    set fp [open $g_logFile "WRONLY APPEND CREAT"]
    puts $fp "[clock format [clock scan now]]: $msg"
}

# Retrieves the external IP address of this server (using dyndns)
proc getExternalIp {} \
{
    set token [::http::geturl http://checkip.dyndns.org]
    set data [::http::data $token]

    regexp {Address: (\d+\.\d+\.\d+\.\d+)} $data -> ipAddress

    return $ipAddress
}

# Retrieves the current external IP address that this server is aware of
# (using the g_currentIp file)
proc getCurrentIp {} \
{
    global g_currentIp

    set fp [open $g_currentIp "RDWR CREAT"]
    set ip [lindex [split [read $fp] "\n"] 0]
    close $fp
    return $ip  
}

# Updates FreeDNS to your new external IP.  Also updates g_currentIp so we
# know when we need to update again  
proc updateIp {ip} \
{
    global g_currentIp
    global g_authToken

    foreach part $g_authToken \
    {
        set token [::http::geturl http://freedns.afraid.org/dynamic/update.php?$part]
    	logger [::http::data $token]
    }
    set fp [open $g_currentIp "WRONLY CREAT TRUNC"]
    puts $fp $ip
    close $fp
}

# Main program

# Get the current known IP of the system (stored in g_currentIp)
set currentIP [getCurrentIp]
# Get the current external IP of the system (from dyndns)
set externIP [getExternalIp]

set force [lindex $argv 0]
if {$force eq ""} \
{
    set force false
}

# If our IP has changed (or if we are forcing) then update it!
if {($currentIP ne $externIP) || $force} \
{
    logger "updating IP ($externIP) - force: $force"
    updateIp $externIP
} \
else \
{
    logger "IP Address is up-to-date"
}
