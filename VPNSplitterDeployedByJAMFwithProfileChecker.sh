#!/bin/zsh

VPNCreatorLog="/Library/Logs/VPNSplitterDeployedByJAMF.log"

#delete existing log file
[ -f $VPNCreatorLog ] && rm -f "$VPNCreatorLog" 

# Redirect STDOUT to file
exec >> "${VPNCreatorLog}" 2>&1

echo "*************** Start Log ***************"
	
#Add Date to LogFile
/bin/date

#unload the LaunchDaemon even if it does not exist
echo "Unloading Existing LaunchDaemon"
/bin/launchctl unload /Library/LaunchDaemons/vpn.splittunneler.plist

#Check for VPN Profile Existence
currentuser=$(/bin/ls -la /dev/console | /usr/bin/cut -d ' ' -f 4)
echo "Current Logged in User is" $currentuser
VPNProfileInstalled="$(sudo -u $currentuser /usr/bin/profiles -Lv | /usr/bin/grep -c 'Native VPN Client Pilot')"
echo "VPN Profile Installed =" $VPNProfileInstalled

if [[ $VPNProfileInstalled = "1" ]]; then
	echo "Creating LaunchDaemon"

	/bin/cat << EOF > /Library/LaunchDaemons/vpn.splittunneler.plist
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
		<key>Label</key>
		<string>vpn.splittunneler</string>
		<key>ProgramArguments</key>
		<array>
			<string>/bin/bash</string>
			<string>/usr/local/bin/vpn_splittunneler.sh</string>
		</array>
		<key>WatchPaths</key>
		<array>
			<string>/Library/Preferences/SystemConfiguration</string>
		</array>
	</dict>
	</plist>
EOF
	echo "Setting LaunchDaemon File and Ownership Permissions"
	/bin/chmod 644 /Library/LaunchDaemons/vpn.splittunneler.plist
	/usr/sbin/chown root:wheel /Library/LaunchDaemons/vpn.splittunneler.plist

	echo "Creating Split Tunneler Script"
	/bin/cat << EOF > /usr/local/bin/vpn_splittunneler.sh
	#!/bin/zsh

	InputFile="/usr/local/bin/VPNSplitterInput"
	LogFile="/Library/Logs/VPNSplitter.log"

	#delete existing log file
	[ -f \$LogFile ] && rm -f "\$LogFile" 

	# Redirect STDOUT to file
	exec >> "\${LogFile}" 2>&1

	echo "*************** Start Log ***************"

	#Check if input file exists
	if [ ! -f \$InputFile ]; then
		 echo "InputFile Missing" 
		 exit
	fi	 

	#Get Default Network Interface
	Interface=\`/sbin/route -n get default | /usr/bin/grep 'interface:' | /usr/bin/grep -o '[^ ]*\$'\`

	#Add Date to LogFile
	/bin/date

	#Log Current Interface
	echo "Interface Changed to = " \$Interface

	#If not IPSEC tunnel exit
	if [ \`/sbin/ifconfig | /usr/bin/grep "utun" | /usr/bin/grep -c "NOARP"\` = "1" ]; then
		echo "Connected via Cisco AnyConnect"
		#Log current routing table config
		/usr/sbin/netstat -nr -f inet
		echo "********* End Log ********"
		exit
	fi

	#if ipsec set routing table for split
	if [ \`/sbin/ifconfig | /usr/bin/grep -c ipsec\` = "1" ]; then
		#Get Local Deafult Network Adapter Info
		#defaultadapter=\`/usr/sbin/netstat -rnf inet | /usr/bin/grep "default" | /usr/bin/egrep  -v "ipsec|utun" | /usr/bin/awk -F' ' '{ print \$4 }'\`
		#echo "Default Network Adapter is" \$defaultadapter
		
		#Get Local Gateway Info
		defaultgateway=\`/usr/sbin/netstat -rnf inet | /usr/bin/grep "default" | /usr/bin/egrep  -v "ipsec|utun" | /usr/bin/awk -F' ' '{ print \$2 }'\`
		echo -en "Current Gateways are" \$defaultgateway
		echo " "
		
		#adding split tunnel routes
		#echo "Adding Bypass Routes to Default Network Gateway - Should be Local Gateway not VPN"
		for eachgateway in \`echo \$defaultgateway\` ; do 
			echo -en "\n*********************************\n"
			echo "Adding Bypass Routes to Default Network Gateway:" \$eachgateway
			echo -en "*********************************\n"
			while read line || [ -n "\$line" ]; do
			/sbin/route add \$line -gateway \$eachgateway
			done < \$InputFile
			echo -en "\n "
		done
	else
		echo "Deleting Split Routes - Janitorial Duties"
		while read line || [ -n "\$line" ]; do
		/sbin/route delete \$line
		done < \$InputFile

	fi
	
	#Log current routing table config
	echo -en "\n**** Current Routing Table Information ****\n"
	/usr/sbin/netstat -nr -f inet
	
	echo "********* End Log ********"
EOF

	echo "Creating Input File for Split Tunneler Script"
	/bin/cat << EOF > /usr/local/bin/VPNSplitterInput
	17.0.0.0/8
	52.112/14
	52.120/14
EOF

	echo "Loading the LaunchDaemon"
	/bin/launchctl load /Library/LaunchDaemons/vpn.splittunneler.plist
	echo "********* End Log ********"
else
	echo "VPN Profile Not Installed - Nothing to do - Mic Drop"
	echo "********* End Log ********"
	exit 
fi
