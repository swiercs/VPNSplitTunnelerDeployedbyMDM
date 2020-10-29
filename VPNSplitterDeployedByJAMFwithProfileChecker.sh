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
	2.17.107/24
	8.252.17/24
	8.253.38/24
	8.253.140/24
	8.253.141/24
	8.253.154/24
	8.253.176/24
	8.253.217/24
	8.255.31/24
	8.255.36/24
	8.255.45/24
	13.107.6.152/31
	13.107.18.10/31
	13.107.64/18
	13.107.128/22
	13.107.136/22
	13.251.83.224/27
	17.0.0.0/8
	18.206.107/28
	18.236.229.240/28
	18.237.140.32/27
	23.2.13/24
	23.40.62/24
	23.75.23/24
	23.103.160/20
	23.199.63/24
	23.199.71/24
	23.210.6/24
	23.218.94/24
	23.220.203/24
	34.245.240.176/28
	34.246.231.96/27
	40.96/13
	40.104/15
	40.108.128/17
	52.96/14
	52.104/14
	52.112/14
	52.120/14
	62.109.192/18
	64.68.96/19
	65.158.47/24
	66.114.160/20
	66.163.32/19
	67.24.139/24
	69.26.160/20
	69.26.176/20
	72.21.81/24
	93.184.221/24
	104.146.128/17
	107.20.247.251/32
	114.29.192/19
	117.18.232/24
	131.253.33.215/32
	148.168.126.37/32
	148.168.126.39/32
	148.168.126.41/32
	148.168.126.43/32
	148.168.126.124/32
	148.168.195.18/32
	148.168.195.20/32
	148.168.195.22/32
	148.168.195.24/32
	150.171.32/22
	150.171.40/22
	150.253.128/17
	168.224.195.13/32
	168.224.195.15/32
	168.224.195.17/32
	168.224.195.19/32
	170.72.0.0/16
	170.133.128/18
	172.20.10.5/32
	173.39.224/19
	173.243.0.0/20
	191.234.140/22
	204.79.197.215/32
	204.114.221.11/32
	204.114.221.18/32
	204.114.221.20/32
	204.114.221.22/32
	207.182.160/19
	209.197.192/19
	210.4.192/20
	216.104.214.128/27
	216.151.128/19
EOF

	echo "Loading the LaunchDaemon"
	/bin/launchctl load /Library/LaunchDaemons/vpn.splittunneler.plist
	echo "********* End Log ********"
else
	echo "VPN Profile Not Installed - Nothing to do - Mic Drop"
	echo "********* End Log ********"
	exit 
fi