# VPNSplitTunnelerDeployedbyMDM
Script to be deployed by MDM to macOS devices for configuring routing table to split traffic that you don't want to go through the VPN.

The script creates three files: a LaunchDaemon, a script file, and a script input file.  The LaunchDaemon monitors the network connection and calls the script file whenever a change is detected.   Based on the current network interface in use, the script file determines if it needs to write or delete routing table entries.  In our case the script is writing routing table entries, for IP addresses or blocks, that we do not want going through our IPSec VPN Tunnel.  The script also monitors for the use of our Cisco AnyConnect client based VPN, which uses a UTUN type tunnel, and ignores this case since the Cisco AC client handles its own routing table updates.  If the user disconnects from the IPSec tunnel, the routes are deleted.  



