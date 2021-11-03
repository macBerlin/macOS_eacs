#!/bin/bash
# Michael Rieder 02.11.2021 
# Installer Script to create a launchdaemon to monitor the Erase All Content and Settings process from macOS 12
# - create a launchd
# - create a script to update JAMF EA

LABEL="de.COMPANY.eacsmon"
SCRIPTPATH="/Library/Application Support/COMPANY/Scripts"
SCRIPTNAME=".eacs_done.sh"

JAMFSERVER="https://JAMF.COMPANY.NET:8443"
EA_USER="###APIUSER###"
EA_PASS="###APIPASS###"
EA_NAME="eacs_done"

# get UUID from Preboot Volume
PreBootUUID=$(ls -ld /System/Volumes/Preboot/* | grep -im1 preboot | awk -F"/" {'print $NF'})

pattern='^\{?[A-Z0-9a-z]{8}-[A-Z0-9a-z]{4}-[A-Z0-9a-z]{4}-[A-Z0-9a-z]{4}-[A-Z0-9a-z]{12}\}?$'

# If the result is a UUID we continue otherwise the script exit with error code 1
if [[ "$PreBootUUID" =~ $pattern ]]; then
    echo "Installing files.." 

launchdtemplate='
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>'${LABEL}'</string>
	<key>ProgramArguments</key>
	<array>
	<string>'${SCRIPTPATH}'/'${SCRIPTNAME}'</string>
	</array>
	<key>WatchPaths</key>
	<array>
		<string>/System/Volumes/Preboot/'${PreBootUUID}'/var/db/.com.apple.eacs</string>
	</array>
</dict>
</plist>'


echo -e "#!/bin/zsh\n" > "${SCRIPTPATH}/${SCRIPTNAME}"
echo -e "SERIAL=\$(ioreg -c IOPlatformExpertDevice -d 2 | awk -F \\\" '/IOPlatformSerialNumber/{print \$(NF-1)}')" >> "${SCRIPTPATH}/${SCRIPTNAME}"
echo -e "WIPEDATE=\$(date '+%Y-%m-%d %H:%M:%S')" >>"${SCRIPTPATH}/${SCRIPTNAME}"
echo -e "apiData=\"<computer><extension_attributes><extension_attribute><name>${EA_NAME}</name><value>\${WIPEDATE}</value></extension_attribute></extension_attributes></computer>\" ">>"${SCRIPTPATH}/${SCRIPTNAME}"
echo -e "/usr/bin/curl -sk -u \"${EA_USER}:$EA_PASS\" -X PUT --header \"Content-Type: application/xml\" \"${JAMFSERVER}/JSSResource/computers/serialnumber/\$SERIAL\" -d \"<?xml version=\\\"1.0\\\" encoding=\\\"ISO-8859-1\\\"?>\$apiData\"" >>"${SCRIPTPATH}/${SCRIPTNAME}"
chmod +x "${SCRIPTPATH}/${SCRIPTNAME}"



echo ${launchdtemplate} > /Library/LaunchDaemons/${LABEL}.plist

plutil -convert binary1 /Library/LaunchDaemons/${LABEL}.plist  
plutil -convert xml1 /Library/LaunchDaemons/${LABEL}.plist  

launchctl bootstrap system /Library/LaunchDaemons/${LABEL}.plist

else
    echo "Invalid uuid or Preboot Volume does not exist" 
    exit 1
fi
exit 0



