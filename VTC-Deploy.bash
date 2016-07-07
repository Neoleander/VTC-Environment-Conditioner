#!/bin/bash
########################################################################################
# VTC Environment Conditioner (VEC) - Deploy System
# VECVer Array: Version, Date, Initials, Description
export VECVER=( "3.2" "5 July 2016" "NAF" "Enhancements" )
[[ $1 == "GETVER" ]] && echo "${VECVER[0]}" && exit 0
########################################################################################

############################################################
# Main Variables
############################################################

# Input.
[[ $1 == "" ]] \
	&& RunMode="NONE" \
	|| RunMode="${1}"

# Common.
Normal="0" Gray="29" Red="31" SuperRed="41" Green="32" Yellow="33" Blue="36"
MyName="VTC-Deploy.bash"
SECONDS=0

############################################################
# Functions
############################################################

######################################################
# Output text with color
# INPUT: TextClass, Text
# OUTPUT: Return code 0/true or 1/false
function ColorText {

	# Gather details.
	FXHeader="$1"
	case ${FXHeader} in
		# Something of interest.
		"INFO") FXColor="${Green}";;
		# Something to review, but not an error.
		"WARNING") FXColor="${Yellow}";;
		# You screwed up.
		"ERROR") FXColor="${Red}";;
		# The script is screwed up.
		"CRITICAL") FXColor="${SuperRed}";;
		# How to proceed.
		"PROMPT") FXColor="${Blue}";;
		# Huh?
		*) FXColor="${Gray}";;
	esac
	shift 1
	CommentText="$*"

	# Output.
	printf "\e[7;${FXColor}m[%-8s]\e[1;${Normal}m %s
" "${FXHeader}" "${CommentText}"
}

######################################################
# Update the variables in this file if needed
# INPUT: NONE
# OUTPUT: ToDisk > UpdateVTCFiles
function UpdateVariables {
	# This function is designed to update the variables in this file.
	if [[ ${USER:-UNKNOWNUSER} == "root" ]]; then
	local ThisRoot ThisVersion ThisVersionFile

		# Main location of the VTC binary.
		if [[ -d  /usr/local/dvn ]]; then
			ColorText "INFO" "VTC root located at \"/usr/local/dvn\"."
			sed -i 's/^export VTCRoot=.*$/export VTCRoot="\/usr\/local\/dvn"/' ~/.VTC-*
			ThisRoot="/usr/local/dvn"
		elif [[ -d  /opt/dvn ]]; then
			ColorText "INFO" "VTC root located at \"/opt/dvn\"."
			sed -i 's/^export VTCRoot=.*$/export VTCRoot="\/opt\/dvn"/' ~/.VTC-*
			ThisRoot="/opt/dvn"
		fi

		# In SystemD systems, this will exist.
		if [[ -f /etc/systemd/system/dvn.service ]]; then
			ColorText "INFO" "VTC SystemD name is \"dvn.service\"."
			sed -i 's/^export VTCServiceName=.*$/export VTCServiceName="dvn"/' ~/.VTC-*
		elif [[ -f /etc/systemd/system/vtc.service ]]; then
			ColorText "INFO" "VTC SystemD name is \"vtc.service\"."
			sed -i 's/^export VTCServiceName=.*$/export VTCServiceName="vtc"/' ~/.VTC-*
		fi

		# Assess the version of the VTC.
		ThisVersionFile="${ThisRoot}/running/bin/vtc_app/version.txt"
		if [[ -f ${ThisVersionFile} ]]; then
			ThisVersion=$(cat ${ThisVersionFile}) ThisVersion=${ThisVersion%.*}
			sed -i 's/^export DVNVersion=.*$/export DVNVersion="'"${ThisVersion}"'"/' ~/.VTC-*
		fi

	fi
}

############################################################
# Pre-Checking for Environment
############################################################

# Check for location.
[[ ! -f ${MyName} ]] \
	&& ColorText "ERROR" "You must run \"${MyName}\" by local directory only." \
	&& exit 1

# Count lines until finding the payload data.
PayloadBegin=$(awk '/^EOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOS$/{print NR+1; exit 0;}' ${MyName})
[[ ${PayloadBegin:-ERROR} == "ERROR" ]] \
	&& ColorText "CRITICAL" "\"${MyName}\" may be corrupt." \
	&& exit 1

# Determine SHA1 executable.
SHA1Exec=$(which shasum 2>/dev/null || which sha1sum 2>/dev/null)
[[ ${SHA1Exec:-ERROR} == "ERROR" ]] \
	&& ColorText "CRITICAL" "SHA1 functionality is missing."

# Get OS.
MyOS=$(uname -s 2>/dev/null || echo ERR)
if [[ ${MyOS:-ERR} == "Darwin" ]]; then
	export MyOS="MacOSX"
elif [[ ${MyOS:-ERR} == "Linux" ]] && egrep -qi 'Release 7' /etc/centos-release 2>/dev/null; then
	export MyOS="CentOS7"
elif [[ ${MyOS:-ERR} == "Linux" ]] && egrep -qi 'Release 6' /etc/centos-release 2>/dev/null; then
	export MyOS="CentOS6"
elif [[ ${MyOS:-ERR} == "Linux" ]] && egrep -qi ^'7.|8.' /etc/debian_version 2>/dev/null; then
	export MyOS="RPiOS7"
else
	ColorText "ERROR" "Non-compatible version."
	exit 1
fi

############################################################
# Main
############################################################

# To build the self extracting TAR.
if [[ ${RunMode} == "BUILD" ]]; then

	# Look for the required files.
	[[ ! -f .VTC-Generic ]] \
		&& ColorText "CRITICAL" "Cannot build, missing \".VTC-Generic\"." \
		&& exit 1 \
		|| ColorText "INFO" "Generic Environment Found."
	[[ ! -f .VTC-CentOS7 ]] \
		&& ColorText "CRITICAL" "Cannot build, missing \".VTC-CentOS7\"." \
		&& exit 1 \
		|| ColorText "INFO" "CentOS (7) Environment Found."
	[[ ! -f .VTC-CentOS6 ]] \
		&& ColorText "CRITICAL" "Cannot build, missing \".VTC-CentOS6\"." \
		&& exit 1 \
		|| ColorText "INFO" "CentOS (6) Environment Found."
	[[ ! -f .VTC-MacOSX ]] \
		&& ColorText "CRITICAL" "Cannot build, missing \".VTC-MacOSX\"." \
		&& exit 1 \
		|| ColorText "INFO" "Mac OSX Environment Found."
	[[ ! -f .VTC-RPiOS7 ]] \
		&& ColorText "CRITICAL" "Cannot build, missing \".VTC-RPiOS7\"." \
		&& exit 1 \
		|| ColorText "INFO" "Raspberry Pi (DEB7/DEB8) Environment Found."

	# Clean up anything old.
	VECScriptBuff="$(head -n $((PayloadBegin-1)) $0)"
	if [[ ${VECScriptBuff} == "" ]]; then
		ColorText "CRITICAL" "Cannot clean, check script file."
		exit 1
	else
		echo -e "${VECScriptBuff}" > ${MyName}
	fi

	# Import the new data.
	COPYFILE_DISABLE=1 tar -czf - .VTC-Generic .VTC-*OS* >> ${MyName}

	# Checking.
	if [[ $? -eq 0 ]]; then
		SHA1Hash="$(${SHA1Exec:-UNAVAILABLE} ${MyName})"
		echo "${SHA1Hash}" > SHA1.txt
		ColorText "INFO" "BUILD OK.  (SHA1=${SHA1Hash%% *})  (RUNTIME=${SECONDS}s)"
		exit 0
	else
		ColorText "CRITICAL" "TAR failure during build.  (RUNTIME=${SECONDS}s)"
		exit 1
	fi

# To extract the TAR.
elif [[ ${RunMode} == "INSTALL" ]] || [[ ${RunMode} == "UPDATE" ]]; then

	# Check for location.
	[[ $(pwd) != "${HOME:-ERROR}" ]] || [[ ! -f ${MyName} ]] \
		&& ColorText "ERROR" "You must run \"${MyName}\" in ${HOME:-ERROR}." \
		&& exit 1

	# Extract only the required files.
	tail -n+${PayloadBegin} ${MyName} | tar -oxzf - ".VTC-Generic" ".VTC-${MyOS}"
	if [[ $? -eq 0 ]]; then
		VECBuildVer="$(./${MyName} GETVER 2>/dev/null)"
		SHA1Hash="$(${SHA1Exec:-UNAVAILABLE} ${MyName})"
		ColorText "INFO" "$1 OK.  (SHA1=${SHA1Hash%% *})  (RUNTIME=${SECONDS}s)"
		# Replace the directories in the files based on what really exists.
		UpdateVariables
		exit 0
	else
		ColorText "CRITICAL" "TAR failure during extraction.  (RUNTIME=${SECONDS}s)"
		exit 1
	fi

# To delete the VEC.
elif [[ ${RunMode} == "UNINSTALL" ]]; then

	# Check for location.
	[[ $(pwd) != "${HOME:-ERROR}" ]] || [[ ! -f ${MyName} ]] \
		&& ColorText "ERROR" "You must run \"${MyName}\" in ${HOME:-ERROR}." \
		&& exit 1

	# Cleanup.
	rm -vf .VTC-*

	# Reset the .bashrc.
	IFS=$'
' RCBuff=`while read EachLine; do case "${EachLine}" in *"VECSCRIPT");; *)echo -e "${EachLine}";; esac; done <.bashrc`

	# Close out.
	if [[ ${RCBuff} != "ERROR" ]]; then
		echo -e "${RCBuff}" > .bashrc
		ColorText "INFO" "Removed the files and init RC in \".bashrc\".  (RUNTIME=${SECONDS}s)"
		exit 0
	else
		ColorText "CRITICAL" "Error, init RC in \".bashrc\" could not be removed.  (RUNTIME=${SECONDS}s)"
		exit 1
	fi

# In pure deploy/run mode.
else

	# Check for location.
	[[ $(pwd) != "${HOME:-ERROR}" ]] \
		&& ColorText "ERROR" "You must run \"${MyName}\" by relative directory only." \
		&& exit 1

	# Check for inclusion in RC.
	grep -q "VECSCRIPT" .bashrc 2>/dev/null
	if [[ $? -ne 0 ]]; then
		echo "./${MyName} && . .VTC-${MyOS} # VECSCRIPT" >> .bashrc
		ColorText "INFO" "BASHRC was updated."
	fi

    # Mac OSX does not call bashrc natively, so we must check for it.
	fgrep -q 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' .bash_profile 2>/dev/null
	if [[ $? -ne 0 ]] && [[ ${MyOS} == "MacOSX" ]]; then
        echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> .bash_profile
		ColorText "INFO" "BASHPROFILE (MacOS) was updated."
	fi

	# First/UPDATE run, extract files.
	if [[ ! -f .VTC-${MyOS} ]] || [[ ! -f .VTC-Generic ]]; then
		./${MyName} "INSTALL" 2>/dev/null \
			&& chmod 755 .VTC-* 2>/dev/null
		[[ $? -ne 0 ]] \
			&& ColorText "CRITICAL" "INSTALL aborted." \
			&& exit 1
	fi

	# Special update condition.  Should only happen on development code.
	ForceUpdate="FALSE"
	if [[ -f SHA1.txt ]]; then
		SHA1HashLocal="$(${SHA1Exec:-UNAVAILABLE} ${MyName})"
		SHA1HashRemote="$(cat SHA1.txt)"
		if [[ ${SHA1HashLocal} != ${SHA1HashRemote} ]]; then
			ForceUpdate="TRUE"
			echo "${SHA1HashLocal}" > SHA1.txt
		fi
	fi

	# Get versions of existing files - make sure to update if needed.
	DeployGetVer="$(./${MyName} GETVER 2>/dev/null)"
	OSGetVer="$(./.VTC-${MyOS} GETVER 2>/dev/null)"
	GenericGetVer="$(./.VTC-Generic GETVER 2>/dev/null)"
	if [[ ${ForceUpdate} == "TRUE" ]] || [[ ${DeployGetVer:-ERR} != ${OSGetVer} ]] || [[ ${DeployGetVer:-ERR} != ${GenericGetVer} ]]; then
		if [[ ${ForceUpdate} == "TRUE" ]]; then
			ColorText "INFO" "Special UPDATE triggered."
			ColorText "INFO" "(LocalSHA1:\"${SHA1HashLocal}\" != RemoteSHA1:\"${SHA1HashRemote}\")"
		else
			ColorText "INFO" "Auto UPDATE triggered. (Deploy:${DeployGetVer} > [OS:${OSGetVer} || Generic:${GenericGetVer}]"
		fi
		./${MyName} "UPDATE" 2>/dev/null \
			&& chmod 755 .VTC-* 2>/dev/null
		[[ $? -ne 0 ]] \
			&& ColorText "CRITICAL" "UPDATE aborted." \
			&& exit 1
	fi

	# Signal RC to launch.
	if [[ -f .VTC-${MyOS} ]] && [[ -f .VTC-Generic ]]; then
		exit 0
	else
		ColorText "CRITICAL" "Both \".VTC-${MyOS:-ERROR}\" and \".VTC-Generic\" must exist in \"${HOME:-HOMEDIR}\"."
		exit 1
	fi

fi

# Should not be here.
ColorText "CRITICAL" "Abnormal execution - aborting."
exit 1
########################################################################################
# Begin Data Payload
########################################################################################
EOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOSEOS

