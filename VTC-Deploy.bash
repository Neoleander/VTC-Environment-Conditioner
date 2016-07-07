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
‹ è|W í}k{Û¸±ð~µÂ8µ•ZWç²ëTIµ¶œ¨kKª¥$›Ú>~i‰²ÙH¤JRv\Gç9ŸÎ9¿ô@‚)Ë—ì¦­Õ­#‘À ƒÁ\
º[ù·–cyvï‡oô)Áçåóç?ü|¯üïÿáïRå=/•Ÿ•^VÊ?”+/7^B±—¥Jåréå¢ô­:¤&~`zBüà<óÔZYå Ø`ð[tè·ý<~T<±â‰éŸ-?þFŸåÇ¨LÔsÛs‘åbËuúv`»@wbíC}+—’E«#ÞÝsèc½úÖÛzó”ªyžy¹)à«ÕÖÅ¶Xë¢á (
¿-¿çÙc„¹l}»^€•?Ô÷«kÂØ(Ta<™/E¥T~¿šµø[wÎL§ga§|Cä–ÄJYT«Âx[ïBmC‰?üAX½3W+Wó t45èñ;¥o‡¹;Aüí™¶#>˜žmž-_„X¾\‰ß¦ëÌaÕ(â-LNÕ¨üdˆ}«_56Ê†èLÆ–G¿ž•±€e9ðæá“5ºð}Ã?'|{a(˜íN¹j®¬ÙSq¸òç¢“ðJg–ÃóphZåW+Ww::<:œüùðL^¼>4^	kè[ªè É‰°ôh¦øÀÎÑû¼çAavj§óÎA?W®:lÂÂŸÓâŽ=´ð2ÊØ§ø
Ë‡¸ÆyÐ;îÑïÂß}«§×Û·æUò¬dsh÷íª±Vy~PÊ??úZžÁŸŸŽ¾”ÊGoè+ýy“;,ü>åâým{ÖÀþ}ÞÀ‚_ÊU¯¡ð]Éý5¢;§‡Œ 	þgÓ·{þÝ ß²6t¨5	Æ“@Ö—@\ØÁ™è¹C×ƒfû}wStáÅÖÐôáW¬ñ¾Koö­`â9P¾o‰R1ð&–p=Q.€ÛYË9B`¤ «Š«å¥Çâ­	«Ä}+0í¡_X^Úùõeö-èªl,/õLX+WêéTØÎòÔë ¥g¶s*Ü<,Ïò¨¾d4š;-#'v~¥–<yÉ¯^%j®ð¬sÛºX'0fÇ„	Öó\ }¬í7Í·q`ÌBhŸÜ‰ >n]X}1Sµúþ~k?^	×°ªÑ=³s~aûÉº[ûnc«¶¯®8Sã{½{nÏ²úT³½ßÚkwãõYEu&goàËÓjÌK.aùfoyÉ?³(//m¹#Übp¢ ÜS ô%EÐÜØ”„,èå+œ8<ÉÿèIÆ¥“xâ:îEá,Ò/­‰©±<½;Ñ^˜°·ùcÛ#¢Ø<[ÿbõ&î,7§[ó ²w¨å¥¡Û3‡°¯÷ªeõ£{fû»¶¼ÑPö.»—cKuT*+ªÆn«ÕŽÞÙ#Fµ¼ÔÝk3—-£qq»¾[ïÖðq%ö¼bh¨šÅ1G3Xó}Ë÷qg‚Eƒ8³Nv¡®6î¬\kF§Ýhþõ}£Þ5žæà÷’ì[U•{üøiXdŠÔX£Šø”ÈžÍ‡3"ªÍõ""—š0°°\¸TÚã9-«šLÜ(*]ÉV§$2‘°t¥@2RÝÙ(¦ö'¡	ÖØ©gŽ
Ë´taÅ ïbR8ÊRÄshß~°yV¦¢òºØ·Î‹Îd8œ}]I¼gÉ!?Ð(ñºÖ©oµšÛj	¾¯I©nÅˆ·‡‚Ý9L·¸Ä‡¦µ‘h]I‡yV°Œc«Þélû@"úØè¾ë¼ßÂGÐH¼â×¯)wj]¬ëi»Ö­ÉÆ@F]Bñf9uæ°” HˆÈ†E5*ˆµhp9œÑhBv8=®Âñ
Y¼x€{÷E Óè‰3Ó6»¹í‹¼8Ã¦˜ô•Ç”À í}w™ù4 ra…ôTAÑ;³zŸaã@~Ë“¶²¶&É&/§)—yh¦¤ÏàÒø³“°²Ö3mÖr€©hŠb$‹#Îº½: ˜ˆû°õ¾& £=;°ˆV/\û'†À{
ônßò­€Þá3½ö¬L$F–xÀºžüˆý¶þAý¦A+BgcKÑ/F ~Ÿ>Æ7Ch€ü ¾5°¸Læ¾@û€vðÏ(K87‰59›©H÷sB`Wü¡eiÝÃQÂ=·p—ZÀ}Ø;œ—mdsª“«‡'O
%U\•…r©4e„J&Ù7Sô'žœñoÜÌK)ÙÚWã§B*9õ CùcÞ:û“¾d"ºYZâÚçókëËMgBQêEOä/ô–€ ó§A‚TgIo»Õ¬7[¼^¹„\Í™e‰p Q®‘‚‰Æ‘‰…”V°¢Ö'Ùír›Hã65ÅÎy³n¯7ñp1ˆ5¹ã$'8ÇðÕš“MÐ~²¼ÔwaMÁBIˆCòˆ7WR‰›ï2=¤¹ž;ÃrÂ‰µí‰GÄ$%)}êçx#ßZ «’Ô¨h>±¿»,-¸ÁÏ¯¤›4f©“DœzT%Õ –Žà&(M2õÒrœ¨â\2¥(O6ÑTV¿Œ·¨Q„’íEÿ‡áºYÚ,?Ÿ
…CK@©ålÇ„©ž@|%`†ÄGLä˜Û5m\ß;£é2Â.pÐçŽ”p‚Ý¾M¢”ÙµjRû ‘ 7€ãÛÄ³R{"'6ò{ç³ã^8¬•
7Ú <åš˜*áÝå±…›{È”ØoíàÏ$õ™ç0JóÄÆ‡Ñã øÙÛâNc·~´.Ú iŽ,R·à—u±ëžÚ ŽÓSZ
·87cÿZ'·zxYð	ß½u»ny¼ò­Ä]lv*ÁÄ‡ËE9z½"lë¸!ì›ùÚn§.WÐþûºFBû,VÄ‘ø «L%ò-w2ìÓù{`ƒ‡nàéd*×#àÐ()0a w‚)Bå‹|±+ßˆ‘y)N,1qä´­âÐÙÈœ°@˜øJêÄEÍÄNzÜ<ªhvå³Cé½'€´ðÏdê«Ýø;9mË:KÖ #ÉÆ‹¡|Ü;ÓZ)¿ÎN%È7¡È¨ñSÓÒONXH¬i‹|Yç\±ãúJô˜&¶xÿ=Æ‡·ìå‡Ú~#ÑË‰ƒ"xŽgL¯þe¬¾n_ðuô¢Ò%œ„«SC{eáíŸñXM¼¢
?yR}?î±Ì¢úØÌ7ßïîRGÃÇÐ.<†ý`z/H‚‰#z¨ÑÂ%Ù—§tÁ‡1øëå?QÔç¥'©-ÏuâÊ, ;º^8Ý«Cj÷›6«µ
Þz«	7œÕï_'°ßlËûÝÔ¿õ¡Ýƒ­ØçRÁðÇÐ;+:&¾®^ûëÄò¾à²ædÔÿ‚
¨î½ÊK†ígo­@=D•šÒ¢ÁL(ˆ1.9)¯¬ýz{÷S¼”„·]Vè¢¶VœMç3n«cä>È½i˜¤øáÆµ:HµFpã·¸ª 1 ÄüCvœ%Óÿ\æ&*+z X£ñ™éÛÿ„£x ©®b—+t×ôƒÄó˜R!~è k¢ðÈ1{àèîª½­ Gî8Xc9Zã	¨¤Ažö¯ïën£•Vé(:æ9«(†0¨Q¾Kú›" ñE'tÀ
š¤¢˜AB5¥jâ­Tt„S	+Öì‹üXjßÀ™ŠéHTiíÇ¨
Ö=ªdmZˆ¶Òæ^n½	ªä£•¨	Óé©:Ó¸>	É’ÔŸxì¼“¬®òOõ®Šfë†«{´c^ÇB™Ý­1ËG7—kaÚ>¹^ó¶< 'aƒžÔåzðª7gÉƒžƒ¤ÈC½qb»®;†B=äœÙtC32ûVÈpÿ2ë^¬}²|š_7÷xÀLòƒŒÅÊêyœ›)-Ü­3×î-ºlµ)äã\8xÁ7^®‹ÀüÌü§ÏU•ösÎ
WZP*‘¶^ï›±%ñÅì ‹zh–Ïi<4¸SûÜr4Å$3	©üôõSþëÀÿý¯0E_/éÿ_/sBIv¬+k~m¶¾6Ý¯ü¾+ëJ®Ä"¹?æã[C‹yÀâ2F‡ê0»ño!rtÂ6à7ô¦†…h‡·$#Ú˜/Œ$X‡Æ9p˜0™ˆ"ŸQ— RÅ(n°Ït÷ÚÇñ&iK)¾;³LAý;";÷ëikî¬p ,f­´Pb»)ðâÝ˜FE“W-\³¶oiÊùûA¶Z»ï÷šªñ¼D7Dr¢`IÊ*rš•ÚWN”Z[zµÄ–žû[´T=ÏÙÁ•2YTø/C¾ Œ¯µ%^krÉÅ^Ýýô;~¯“Æ_'vï³èÛÌ†ë]Šl–§tòQ«)[[Ód¼téÖ¸ý•ÞVµ£5Þ?sGp =ÜLÐJÉuƒØ}kBa¤ŸMOÜ­gK@C=Ô+1šôe“£ÏP·­•+¶¿¢›Vêˆú}ý°fºá%G>q8ãÞßà%¼ÙñG¼”ç‡[+|W½rUÞÌwê»õ­îT|æÅg±zE+@OÆp^[)å¦«1ýÅò’ŽµâÊUwÞp”VyîX²!ÓÀî´µ½÷MyÛé¼æ$8s=úúÇŸ­K9©	{ÝÈ…2ˆ/2ýÉYFÍéïF/"I«ÄèŸ[‚F´i€½{ìûgl ²åÙªœõKk]…,5€T0”^xYS“9‰;ìªQ­(½ù!<4@êWÚW8_Ü‰ÓëPH¡ëë÷€ÔÞµöê›ù÷Í_š­Mü1- hÑî{¾YONî£Ã¤Ï?4þ;	{Á¾‡-#yÝ±ì_ŒŒ>(ÚÜ#Ã´WãÍM-@ðÙŸÏ\?p€"‘ ãPÈ¶æÎsÇÀú¶ñÖ*œüÅ !‹š³	Ñ’Ñ&V_õgÈ—P6 Y^¸º§¶“ÑÄ'wâ	º]…¥NCE>ò¾Sß' ¢5pÍ\ÜaQ/·¶ß©å@º,2À+cŠë©%a?"9Ì¯xe©%W]Q“;ÛÞ–;¾Äž@_ô»§ØcÎ”ñŽœ¡/àˆ¹™*Â·®C{@xýZ((É	Ág#·/^”JYe”ÉŽº+ÏV„ÏŽ¹ƒS—°?éá}ß ¸ïeöÌãžÈ‹è‚l¨HDK¤6+ˆaëýþ~½ÙUÄ0£ÙfDÑmoÁŠJt:˜ä-Á…³½3±fô]Ø~×ƒcì 3’pßòŠ´Thœè«k/öá˜ãÇXþ—FÎ¾NüÿÏöº8P£Öµ)]wÇõ,ûÔÙ¶ýÏ¯›ÖVŠ˜ÿlþFŒ:v¿Œ ÞŠñÿþ¡®É&²ÝÑm›	\­7]¼²S{3›YêW~·º&VžŠœ¶5<æh×4k–BÄmórèš}y+m«ãHr ¤8Ïê/¼E‰ a™Hy«°ÇEd÷›¡
OòD¡8øãÑb	šŸùÐ=_šŽÁçáÝ¹ToõI&"¦”ú:jgPµúb42©ÿº­1Ùy ]A/HU}ÇžøÀ;Õ(÷.åÊ’oþÿ”+…¾íÑçÜ*ÀzÌTf{#Ó¹L
pþM›ýsß<{þ"ñfS
zdÁÞ!£¡¾éuá¢í[
Z°ø¼Î¥uaf­ '–Ù;h¾ÍS‹4ë¥ƒµ5»Zzeÿ)Fÿ¯ì?þ1—SšS\NU¾yƒ×+WöôèÉ“Í§SzíÆ±ŸnNIW@Ž,/ÁÔC<ÛòC}‚–zÔÔT×çi-¬®JSO‰N]áÂp©–QãÏVºêUÞù¾ö[ÓÁ¤¬”Ú>0ãu8¯È àÎà[ %Y°¾YÀû–}ž<¤)¯4 B),\=…Ø}¯>ìGqk Ô7<Íz}»#>¶ö™¹›—&Îr÷¶û–	Û<13“)a<÷hý$ÖFöéq$SœØ§LŽ ‹æ@n£Öpûûgo ÃˆÐ¤$ žªPî9Oô]Ïâ—s ©TOKq³%¼° RK¥ŸwLèrG¦Lï›á÷#øºD6P÷sÔFJ3ÅÐöI¿×hûDRC88½K»$°„ ¨Êi
™ÉèÄòZ¬íê™®Ûé¡Ýc$“œZ ¼™T2†W‰‹Ë2[˜ån¡kG(àxAÀt‚êj¾'Ê«‚l ö-³Y5ÈòÉ ÿRXÁì“¥ôêñÜÏª*XÑJ®†@°|KkrßòQ}Å‹_û½ëúúOdœËK!Œªñ8ôñA£}”Ù½Fóxäã·Ú‡·òÛ^íWþÖénÏŽw[Ž;%½«×¶Ñ÷8WØæ4šÀò,'Šj RIë.' ¸ñ9ëQpcá£gxG7EuàAØˆÚRHQ­«çSC™f?ÛN»¾ßi|¨oí¶Þoÿ\ÛhJm}&Épm9ÒÉÎÖ¬7·Sê1h¥˜¸qT0n§Ý¯Àr´<4ÒeÃ°Ë¾'M%)ŽÆq¿ƒL¸šMXˆ
Qýo±úx5ómU¬®¦Ù,%©iIs\BOÎÈ“'›dd±ytô”õÜQY$=½ôãÇOµâÓãƒL@G	HÜ”´×!ˆEFSiêÚh'T„RçÁ¤‚Iµ¹CâÈ•=X[±ÿÛ€ûö©@‹OŒÜÕ©?9Y3žë†‘{ÅšÊ{Jº³‹Ú/¨V˜NWs"—Ö}\©Uî,?8(=9,ø3S˜–9X/_>*‹E1¥ãFÜT[«:)<ª†»KlšÑyÄôòµà)Ç
PŠÇƒíÀiˆ¶„ t¢ƒî;¹T"÷‘Ð$" f¶Â­V³ÓètáÈo\ß‰3/Ô¶4§­åkzQ†^ìÖls•Þ0ÎbÔèó¹MV Éw·ï$ã”­6x‘çº ;krhBŸ"n¼ä…3ZŸNJŽÅ"ˆflÞO~³çæpÂÒo& ë?Ä³XKý-ÍVeßŸ”WˆÆYå£iFùJ6¨´W´JŒ$Æ§O¸`ä-ÖåTÜã8RQ9gpi«f¶üüóU)ÒÍÏ$åÓUˆö#Úè3ÊûÓ'þÿ8ëOä”«84;åJ‰dNoá‹Ø›Šz•@ï4–Äûu•ËY•ËT®dU®,Py#«òÆÜÊ4-ÉŠô0ñL~œš;¶Ò7{=8¶Áê¼åñlÅ„O^Æ¹"&s¥Ÿ-"»ø¸€uæPÐË|96åsSòj¶Ä~½Ó†­¡nÌxoÍë¼\š¢~H"—²½KlÆŸjš9(:«ŸÕ+“±y`žâ©Ø	ÈJ—}*3$ÌC”@uù5UêÑÈf	ÿÜ?¼¡Ê¶#»O
²;*«ÑòªÑf¿ZÝ=,~óÎ~*hÚÕhkÇ¼:EÇ€Gú1FbovÐëM¼áýê{â]ÐŽ?tÝÏ“ñM{Qg;ì‹‚µH$MìO4R‘‡¬N^œ¹¶=$@™Ý‹úô±¡÷IwŒo´5E9DtÖ«&Ïz©êé”qPë€ÀN)€À<’f^ü/KM1rQÑX†¹¢P‘ka¥$i
5tgA0Þ,í1Þ|@š+Ž‡¦í×)jp\ð-ŸäÏÆ—œ)²êÜL˜RÎ ªI7ï„eƒD-5ôc¯Š„‚žvc¸Šuš“I;¼æäŸü‘…hm\]î:ˆ³²ÎZ¥½6…*.é®ëÖ)ŠGï™‹5%ý*ÚÈÄ ÙFóCm·±Nø©ÌPöWƒS—¨|~k!Ïì^Â½5XäNþ¶ÞÒ‹«C6´´ ¥•u"x–uj¹ö˜ìËhX”]M'³hv½KÖ¾õíÁÀ¢ëq&ºÔn\ÛIì… &òŸ¤Æ/RÏRz4SúF^’^Ø"£˜–$Õr6ÐÒ@Ž 1¡=ò¶yÞ…Kóg®YÛ«wêûêû7˜ÀL^AèSZÜ	GÚÐc8
'¤{xTü¯µ•¯›þØìY¨Øxœ+²¦`ºšpufÄêè%N=³wÀìÇw­FçÞÊ]½FÄý!Sþ‰ÜÙî(>Õüžå¦bIÇ]h¾ì“V¦)#ýŒ™%Sùš`TþÍd){À!Úô¯÷"R)h™r‚Úº¤5¿ N¯,& ’¯±SÛªÓ·:mwò@°¼”­3_å{Å¨6Zí®©¾‰¼©t|Åÿ:0óÿ¬åÿ†!ÚŠR‘·Sä•ã–†x“âlNšû†ÝªjðY9I-GÛ¢[•Åêá¥ü»*¯W¦›¹«çÓ™§IëF>ï…­±
¶´þO©j•¹ÊrdMg1<ÀËãUÔ·äù*z3KRsÒzÜ¸[~FÙçå5ÕíN!"|Œñe:}´¯L¹+¯¡t´Æ>~ê½/ÿHŸ1ˆ‡°?íþz›às¯¤:€]ÙÕÒ´¸ŠBÖjñxT„W’S¼öÿøjZon_Á2Y³«ÕRŽ£xãàÑ‘hºèÈ—u@Ê;Líbºzï¸Úí´vn‚-,¯ãk˜…¯¡ïÂ$Îð0ƒö½c
VP±ãö>[Á½!¦“G™=Ü±84]Øýà6'Çô…÷’ˆ=0wÆ",ÒÏ¾ä¸d„Ü†žfò[x§þíëA	"a¾Mï c<îñ!³Â÷¾r{´l‡¯¸×côÓÖ8ð««yØG•½U8p–Ó·úò±+úèÛàð†“o®j@·?4z<WW)ŒåóçÏ^ã«üñRûQÑßTbo~Ôü¤ýØx®ÿÐlD žýT*Ub¿Êz?›n¢§DÔW\Ê´îÆ~Wï+É÷?&~ÿÿ½ÿNÀÛˆÁãa$ÀHää’³ é!ÁKŸÁÀ•{dàòd'#;‹šÿ9<üFŽPØ–…‰´Ž&\rU5{CËôÂ_i6›äÞ§ëÜîY-ãQV®-|Å,€Æ@x6ÒD¯³MICÃ³ÁÀî­“)Ší÷&îÄ°}´v¤Ó3Ž]´šZIÙ†nïRd¼-cDèžZÆGò|…5´¾+.Ý	4ìŸa£ßzC]0)RAHíF}šñïfÙ™
Í†.Þ©äGÉ;¿Æp5ëÉØ¢ŸN3³!ôâÌtaèB˜k‰Y :ßjî~BV~¯5?i¯ŒÐœ)d‰^L—gBÁ„Ee Vj”—tÃ^šfºŒê¼ßn÷[­.ûØãÞ&)Ú¦8V¸“…qØâýmÂ5«%½9óÉ”
ÉñRWg€S‘·qŠuìƒtÇ`ôPÓ™Ê4‚…êH @Cïwƒü8{Ð	^ùñþ‹C¤Cßï,“²k1VäX}w„§5ä¬Ð[·gS¯¿tê[¤•×üÍ"W M|¨ÇC[ºg¼F€Û¯ü±w¦Ù_÷ÏÑ¥N*êÉ¶û+”ær(\¤Ù×ÓKÍè/æŒD½çƒd†%h0L7Åt,]-0p=v¯Õlt[ûTõ<èù(ó¤¡@rd2f¬ð±G†žób­	t±Û‚C"{RŒDþ| f‚~?Åhß©-4? ºÂ6ë"µÜKÀ©ÎY¦Ù¼˜^€ÍAÙhüð×†‹¯æˆ¥ªU‰ÇBð%˜3i1Ó¼)›-…ç~Ra	8<Ä<šj7dÅ‘²³„µQÙ).	ùÄ‘Q@á¾½ê°—uÇŸx¼:Âhðš‹¹*D@ì9ª~CUô#6yel…&© Ã2ÈZ¢ÆaŒÜ5ƒwÛ—þJ’øZ¤xØSéz’Ð`cÝÔ¾…VOùAúDëýg	•ë‘†¦Ü=³ø*J”Ñq$höO×18€Ðc
|kéª*#ÁP­iIVŠé:•½ËuðÕCÚg(¡ƒ–$ñ
ižO]­#KÒ;iêÞ”1Ï
`ùè^ |@ª²Ô|)ÇÚ¢Ç¦”ßs˜ã±œ=¥ÿÙ…Ê¸HVy	VO\G>Qib?á­Tø0Uì^Ó‰bhŸö9fIžIrŒÔíCC«Ô ð@‚÷eè¡ÏýgÓ¼¨€¸1q­ý¥Éw½kQ„G{ á‹B¡Èÿõ§±>ëßd^dÅJ“>ç	JŒöK±fÙ¨EÊé,!›m'&*s5ÎÖRS§G+Ôý€)´(±À¸U[t¶ŠÎUyI…a$?‹ÇùR'Q+»Lð}Þ øh7A;~|›é£»52–âTOüÒ#“dèB…¤§"OÇ˜?ë`æv	Úk®¦âðUl‰“éaèˆ-’Q^À¢š:âoõýVÔý‹¶“tI_Žôõi‡8´÷á	nh&ß‰ÙÀ}#M=’6d¸‹ÈPRc~FâüC¥t)l9-.öîì*<¬[Òp—ƒlË%Ãî(™­ý¥Ójq5åæh¬ÐÇv,VÄ
¸Yúë‹FT‚Åsj±4ÊR	r–!¹øÂ93&y…ÛHWaÑªºzeD×Øä_vßØ4`mcÿAÝrgÝèmxta¬ç}çíáY	~ÝÓc/à—üÁ
øý\>™0…žªÃpúðÎ÷ÇÇ,cô47ðld~9öÙ‹Ò‡GeÌÇ%C_¦5|S‘o‚3Ï‚¡uŒSƒ¦=?ÙŽ|7ûÊü¢ªÅ^šý¿Oü 6p×£š*Â»Wy‰Ïu}ëdrJ/áq¾L#´;V€ãÿ||bÔígðŠO,ðóàÊÀÕÏùv ?öÑÞnw~E.s4=šNW“¹o¥Ì"VæëÊc{`B[åRªðfè®ñÖ˜™àoÒ¾ígãôEJŸ½,•žË°ØzÖ1šQ›"ÕM¾ãèåãp@éSAÁ.a]ÀÙÅØ,­xÓoöGø ú<QÚ?9=Zç”® MÂXpCj ÷2Î‘~W¦]öEü4Ï¾|³‡Áá‹M˜ý>ðŠ­Ý÷Ûõmd”¶c¹øé@GVðNo8é
ªØÚ©“¿€¼H£ûÃ¹¿îWÑt´´Î«è_ßéâõ;œ´n¢È“ž€^µôÊCOÀ4Ü+/ô	\ŠŸL"Õ8†0Å^Ï´(;Á?v¾kîÊ•7=züøéññqF<¯ô*UC¹äµ[¨ìËª’ÕþZWó¥®ÙRÑ—®«dùœäôÂ	DÌ¡¨µÑðŠõÀ!4 ê-`¿ä`Óó¼þ%UTýzmûSªb$áf$7&Ä’º–™[ÙBz†óîGT2ÉPôTù<KaËÍVW5.OA(Á±vt&H™ IñJÏŠ§rWF‰b¿þ¶Ñéî×0V”`îö^þú¹Õ}—(QËbV³º”PàG‡zîXÙ”ûeûÉboÄúñîÖ~-•ó¥r.’l°Ñ´\[=çÌŸSáOã¤0tšE™¯’:bÂãåQqqû­¤[AÊcy)!É‰‚Â(5¶ùXÄò± è²zI±¤ä\,%­243>e¡vd6†#¦		CÚ>l—tÅâpÏõU lÁÖƒîééÐJ6¨ßHØÌ„ÙŠ%†LÅ!“Ì˜‘¥2
Öo„ý½!ce[pÝ9®±£4#ä!Ç–²Y™4ÇÖüKá¹Ýý%³‹,Í0Âë¸iQWT_”ûD,É-`‡€µF"Ø2­¢ù-bÜÈëO¡‘&+ÂXµBºá~xS”ÏÁ÷’.°3ý"i¿ÿy·±á‚ìmÎò“Doq)¨
 ±Nè®‰Þ¦e÷"ãx<4;nÌÆHYâKWÞjàyÚ˜ÍpÆ”fko)cçƒ­&JÀÑü"%«H¹œ…ÛŒ0Á—µvÔ¿IæÅºXiì0—›)è)\m1¶kŠœú£;V­)c!Fy={›¡€kX[²üíØZ‚øÓYÚl!}mñJHYY³Õª©-ÊµTlï7>ÔºõÞµ843³BïÈ­Øé7<0dp®9³¢òXl‘žc(~­$gòY¥*'F)WA¶_•jC!(åzÀ&PQ<f/XU>Lz ë‘ãÜ9\
¬p~h8vïÐØÔ4·:²ë‡ÆÈœyU¦WŸŒî›g{ÁÃ[°ò`z§Î¤³ècü~Øa(ÿë,q»ó+r€La1HÕCV6’jI“AÙŒI¥oµÝÝ¶˜Á{Ðšœ:;ŒäË:ü÷¯8b`bÙÏå(DnÃ—A¥1h1†<7½K¬‚rjÓì4 ÕŠ
9®?,/‡Y$mÖ
²‚ TÆ¥ç±cÉÂ²9.h4JâðÁ
›ùÒ4LûE±¿†ýáKÉ$Ki2¼<ÔàäH£VQòì§R¹ÂêW7U;Ë)§|Ûâ[Ÿ[(€Ïæ	›o)w³#J·ú
þþ©J½W(žâ3}› Z^˜—‰÷MF‹º&Ê9`—»#¾ó}‰\_ÂÄcé[Ä¸†ºîŽ;XÃœ{žñt[‰tK¤ÌSŸ²>Öú••‚i0N6Ö	3-t7G|&uÂ÷~HÔI1\¤:ÒgI2£X
i.6#x¾œ¥ÓR™ÙÔLké×	!WLŒYÍõÃ™-u·ÑƒÓS‰£·uÍXX>×‹ç§|?í–¼2„ºzey5¹Š¦ðhÝˆ+”W”)•Íápœ,§÷‹M×WeO˜§þŽ=Y¹óŠ\òÑÂEÝ· È“¸–&5¦~«-q÷‚2_ìI‘E©™âì-T…ïgd=-ž-V]"¸ÈèDT'jâõ‚V~C^_Ôö“*5ÚE5k	€úN¥U Ýgigp3­þ©Uˆvê9çY7Ð/b9ªì½2¹´Ë_Z¤1ÖJ×£rã‰£|ª”Ÿ÷+¤wj_—:Òú¦‘6ö#É>xApZÛ“Ô¿’d%¯;éƒ¥µÐ²Y¦*×ìsð'^üÇ5žì¬r]œrMœKÕÐ†Ùêïy¢µ8ï±NLçL.ÙÅK¬¾ïwúoÒUšó¬~*v5ã®Ý`®“ŠÓ¥¡Tüj¨ãO(cëƒ.î]þ€=Ã›8½uí\S€ìç§±UËu3½”j‰¡mÃ¢HË"¯K/¡)†³û´ÞèoTcÌM¿šh‘Ìí2[m5U«t=Í­âúT-iŽÁ÷KÅ”Ç<âX!•ÌVE±óÞÞiB£%q«ÙdüÖSÉMÞ`#MF|%‡v©‰FïkÑfl¨³ôx=êhH÷L”[ký}»{rW(Sƒð2vaynˆl~±.µtmëÛ2=}[Üð}_BÀ1C#h•=çÚž•ÏrSï¥µ,"Êz‘•')Cðð˜5²Ä‰í Æ%Í™ªG†Àäà…²‘”šT]YÌÇ¬2¥•¥0‡kò’4à¬/ú¥þI´MñK›m)@&ADt-¤!
€tÓnl‹†¿WÛZ^’%c·ÜQéêê‹…òóç…ç?Ê/Ÿ¯ò;ô¨¬®’eu9î—¸göD«#ü±Õ³è®M!¤¤õó LˆÀªðbÆ–‡*-8:j´]3{ÕÕü?WñÏñèã‡×Úòþ€§ÆËé…qhæˆ›]òV<Uj2Ñ:§œÚ“à„]çÈ„’üëIáñ«å‘ì…Ä—¯Âé‰¼#ò<8ÂêThpDþBT0æ£±ü¡l¤™ðÆƒôR‚5
DÝ:‹^·©=mEæ$£FG
üµÀ{Ç¶?ái4«qé8Ì©Lït‚Æ“uŒúÅ”­î±Ø¶ûÑ‰={Tà)4ÿ)áÿ ÷/Åº
6©Ix'Ì·PÑ *1PÐNu¥+°+ ¨Â#U \^;ïwwåúZ–ÖSÐ^Gë‡¬¥ƒ¥.gJ(™»[*»_Ì¶÷›÷ÞÐº÷ÞÌ{ã‰Ÿ£ÜÐ7µö6¬…ì}#k·lkß¥»òt£òÔzÚshðMÃ²úÊEKùg©“ÚÚ¤]?œ~­‰D²ìyz>XŒø¢™¿,ÑÒHœsçÁÁåÊˆm4u8´‚fá„+©]Ûï6jj1EÁh¶b¦h3Ã.±çrø˜>9ÒD+nÁ)ÒO ;h°‹¢‡A{0ƒòI‰7Fˆ‚TkæSüÔRBçè|¡*(,Ï<L$œŸÓú,Îo:,¶>I4úX4Ý1ÂYˆ;Ø¥Ý5ÉX>èv·Èl$»6?ºQ‚;HP	ÅTKa"´ 'ùV‹qy)°m™¸:(Žh²kú®[1Ú¯	Y$feqýž0k×Š´ÛQ¬¢Äi:Ö­fâ¨<qfhÒ–Mî`JªW>¤(	§F}ZãûÛdfÁ8õ-B—¤¼ã²Q4æ{©'›bPã*1£)HBÛûçõšh:f™‰šø”¢tuå‘j?Ÿl3K<ŒÅÈó€-Vc’T$ë­ŠÙŽ¨<¥¯_b—_‘s2“ïg´kÍÿ$Ï‰ÐÉir1JÝÁ\|—ã©bŽŠ˜gÙ‚ú0™HƒÝC)õÆ	†0Qî‚©ZyÕ´ÏÓVïÎsÅ•Ö”¦Š¤ð‰XD¥yjcÈg×rv¢BºÕFƒO	”…<€ÍÏ˜‘w]œLíØHœQse‹gÔÔ‡´ˆÊe?…·	mNô‹céz o-¦€ÖT,¤Ö“Þ¯¼­s2sÅî9›¨œ³Ô}èÚÉOiT&¿Ÿ·ñ¤°n9ãMW˜,"ƒ&"ÆTÜN¨•¹»âÃf÷rÌ@cÂù’Ck`ª)å(t½£ÕÏT1žQ½ÖáyÜ©ŸíšöZÝmré§ÓÎªv›O¡Å±Èþ¯’Š}ïLS`ˆ8\;Î…¡”…ú#?ðN6…ÀæB+†ÿƒÂþÒþ}Œï¾r	qx8(Eå×°?9ùC0ŒðáWñU=ž®H#  ô(àßC~"_â·¯áãLh
M!Š	Bé±ÉÄZ‘Ð\±]”OŽÃ¿Eê˜üuL“tÝLrãs ýÕ~ý¿XÙÌ~ŠñŒ}íÇ±Ã²<? 	c‡úÕßC9ü/ü]WOyŽ®#Ák>@Rœ;T Òmú›„#¡xÚ` ]ëÂ¼[C›|Ö­â°—ø"ºðìÈMÚs’§ÉÔAaÔb•Ìnð˜65—^4oÅJSØñ¬£ÇÚìªS‰òË¤»~˜ÃS%˜m2Ûãd;84“ée]l/˜˜Ã*¹y-"2›2û#Ø¸ðN!­=2FÕÖŸ£ls§ž;c¬Ú¨°Û°[\ß‰”}ÆºÄ–ÃmFn|Þ˜êLœs'‡L<6"ÊZKZŒ›'@Šÿ&òÑÞ»ÌÔ>dbÆÁtäB‚ˆÒ˜ý~0K¬%£D¥˜þ£ñ¤ÿdôä’¬wãdž2kšÇo$Ï	zŠ8§Îì™åÂ³A+8•<4pê>Y~¤/å‰Â·þ¦Æ'(M‰œ•ÛçX÷#³oÍÌo²°ƒó¶L“$¹Ê£Ô*V[u‘þVm¸mÓÙ²É41¶á9beÈ	œ
!oJ òIä2³­ÉA|­ÄÙ›I€hõçÓ?Šœ'Ö(üS åìê·ÄÌ´ô¥…â””®fé§)¾–cU”¿åñQIº$|[_l¾Ð¤Â9é)g:ÚøôÑÇ“t=$íúØœÝŠÜÏb•zÅQ>FÇj¦NI6ÚÀBúLTI?M$»uÂ99§3Òål0™jÜ“!ª91ˆ.OQ¹¼‚CpR—ÔžÜßÙwÈŠ°¯ÂŒõ8ÿ S‹B“™WqbŒ
u"ÄÝ3Pör¼ s)È!ž¬Q'ù}tÁ°ÆÍÆ•Ö¨µÀŠI•ÞÑ§Éxi±Mãe±:+c!/þ>£·àÁT¢ôŠ#7èóCš|íH<ß\Dø1«é±(Ìn¾Ö—ªØøŒ¤–Û–'Pv‡ ä Y÷]‹g‚Ö4õ²TrSL‡˜ŒF„`€ H¥Ð·ûQÛ‰ˆúFÖÕR×¸“ÞYl»e-ÔBþ¶}Òåk;ltbÒ”ùJ¡51ªWkEÏ—u‹Y z{q½X418ƒj9î2ð¯¸…>s­E;W–!š °š=w|6uÍB„…púf—Ó6H¦ÄŸU@”^ˆ&ª¯¢¦D.ëÜ¡Ê~ÉiQ­¹”Sš¢	æTø9º	Í¡OMÞýØÏ±Uö8rÓÿ¼À±¿ÉyÞ(ºJtðßsûð"aÕ Ý½ÿÝ·_àÛªâ®}â™Þe*PN‡žÕ6Ë/Ê&
cxŽOtzqÇ°‹ÞÀr"–=Ej²ÉN‡[R¦ù…„Eêœ;ì2gß>LÀÅPñ0Ý×æ[ß¶Nl‹ú‰[À}}Ös‘»£¡²[‚Ì>Ç~îNó¿~ú[ÜäAo¿¨¹Kj#9·³Ë¥¡tn”ŽXŒÚ´¼IJ'éW›S-nõŠÄ+¡×›xêæ5ŽYÄäM‚pè	ca…iTu‡Ñ8oOÆÖ}ÚGnß Bvn ]Åê—µÀ6ˆ0v:Œ<PãWƒþÌLÑ¬§ÆØ½æ†oÃÐú··C#‚Rô²ŠŸœ$Sh%»×lG*¢°fŠÝîÌ½ñ
ÏÊ«.ÂœÌO‰£J]ƒYýF«%¸Ÿ„Ò»˜Iš´ÖæØ<Áh 6‡›"Ú#V½`6ÊI}%ClcLtŠ¸£ÇNÇ¶Zç–çÙ2bM,ñFë™æ›ºûÊg”ÀyÇ‚WëmU1µ
½‰Ø¡D,ô
ðšh8²Ì×sÛsTóÀú6¶Èµõ­\íç|¨ï”Ž¢ìO<‰)û¹Ô1iÕï dÊjek‘P‹Å¡Ìj3Ëv¹&ew‘xìLN˜	Å»J²€q®Tè z‚Ôñððàég7™º_ŠøÍ–ƒ+^òÜŒ¯Ìë£`ã`Þ¤8øžó*ÏscHUóÔR`åÏTÐ¾-Ë\ÛaQÈèŸ¥ “‰¯D‘,³ðéi€”…Ç¢=Ã ÌIx˜ùàÓR.†Î \ØÛ°ØÍÈhÊÉ–ÂÇ—YÝ§/Ðô‚TˆôœCßfH	1˜„,zÔ(šTú”q¼AC½d¼ÐV3Ý´Îëñ'%PË:«	Ï:Õ,Bs…ÈÆY`Î±&ïpsbí—ú'øÛn4s3ó*5.çØóÞ¨ŸÕîØÆ8rxuˆqÿÌ‡¨´
÷M|ÛÀ¥hÛÍÉ¤—üO¼%•ES¶Êž°×´!‡CNP8Íª¿‰’Æ˜ßvðk®=?ÄôŠ¬²DI]PGéF3‘ùwüùÃ¢O«k·!0?M±Ý9R‰ãd`° É<*qÐôô ¯`Ë„æ0LÏ­¢Ž¨41Y³¬¢øåçÌôàÂV;†*Þ×g<kã€r»dµíçHn´»µŸwë™³NÍZW0 )ö¤hæNü¬á@›ž9ÈlQ½‹´¬õ€H ¬³I°ò¡ñA9bZ ´™Fnçõ,ßžÏp{ù4,¿š—I;	_àR´g:þ 1MpŠwØG#ä¨ß÷ØB ‹æaÏj –ëÐe™ Ó…éõQ\G§”îøö/–øæâ†²j%kþý¶Ýê¼”ö>ºxÜ a¼}ý˜SÄe%VwÉžìbqÇçA¸^=ÓõÐ!¥ë?›ŽÖõíP)+•GÙ;È¬¿ÃtPõcÖùcpAÛÑžµ#×ü6ˆN`~á v¶ƒa½É¼,Ëß"††G©'Ðæ¼^^¸ŒBÌÏûõ¤‹Â–£Ãä­Ïnîê­oþ‡›}´)~qÃª02íËçÏøø^;øßÿ£Pµ•gô¼T*¿Øxþâ‡rååÆ‹—/*Ïð9üxYþA”¾U‡ôÏeB!~p ¶›C+«~‹ý¶ŸÇ(øý‰éŸ}K’GÙR;¥‹ÙSz^H*éŒ…Õê[­Î(SCÝà¦²÷Xx!¿"[Ào‹¥Ì»nQNuÁGýêš06
XóÏÅ_&ÃKQ‚C]VmþÊ$‚äÞcˆÜr¤÷x[ïBmå%£œ»CõÁ”øõv×Ò·ÃÛ #úT®¼»â…©¹`‰`8ùÉù¨ŠŸžê¶õÊkA8!ò–W”›`žçËëhGm¨ƒw Eù(,Ç&<ÖTùåø}³ö¡ÖØE)0,$OÄ câ{ERqñ «¿gåMU;?§e‚Ð«à‰íºòiõ"µD¬vopª—ÒÎl±b2Áœú·€«T¯‡îyvÏbšøïTÜÈ£g5¡Ù(b&k<t/ó”öKÎê´åkí6t×ŠlïòÊ_rnY–Þí“¨)_²ÜYÀÉ7îLÏ;R«yÏô|‡äXîh¤nÑ3PœÛ™zYJÑÃŠ’×âƒ©hY–½¤(—¨¾Ó¨„ÞÃ"Œa*sû¾s@ì(W_›xÙ}±°ög[ÕŽúJ*6èªònˆù¸hcrôrº¬~·Q¡»†õÖ‚UÃq…U'(ƒš¤KY,YÄÂ)"dà„«Ø5šÒóè×ÚÓ•§¡ØL6D=S2zølÂo²¨8Ô4KòZ"vIx§\”ßœï’j®LLÆÞY=óuGPsó“Fšê"†”ôPÀ¨v[*ØøØ‡ùE|ùª¬JÞüUg¥«¡gû¹XÅ/wK²«ë)F‹ž:Wª<³â3w1ƒÊžkðÒõìÓÓ¸CÇsÌ&	’žØ%¡(×H,LKGŽê'˜S`H9·^ÝyšFvq¢ò‚$My™D•Ä©‚o‰@¨›Ä ¶Ì(\oR‚  wÁ[M€R
£^©B™ÒÂ-xmhÛˆE²=CÑ- õGÁŸ?£­¼ 
pnFýâ&ïäÈ€'Œp—ê¯´U°}!SÓHg¤TûÖxô÷+]«?´ík'w¶0Ø¸»tƒõ³5t/Ð|C‚€1ïŠ| F\J±Š|áTò/Æ1þ›wêËÔôoRW9¯Í{j	U¡×Íj¹Mkw"X4u -8šáÛ½äöTêd-ö%8	Rø¾éÚàM†d-Í—pÔø¨‡W‘€C_‰ü}}(V“jlzè©¦oÅ^­ùv·.hÅc2J¼Ïu”ÚæNc·[ßÏnóþZ¢¥4gh·]GšÌMF4×=mìž®mVq•Šå¶¶|R)>³æ¾K“8:xx#qêæÍ3Ëì´Ôµ¡¦¿	¯sXG!#½DÆd8ä¯‡™Œ¤ú‚›uÖˆ\•ÇÆMæò×ÍEñï×\.‚{“lUQ­Ù¼h¯®L²8¦t”*[Ñ]˜žJDQÝ•Ù*ì†®RÖ…ÖXmž~®uê‰h©^Yð¯µÿC£¦Äˆ842K«ñ“K¼IfQ0²by9Æªfƒq¶ë[sK¼ûXÛÞÞO)!³2:ÝOízµŽ§<X	‡Nsïx«Õìî·vwëÛUÇ=tíÏŽwjÝ÷ûuø·[ÛU_4š.ýh5nµºÕKË?tðìÄÝVµÖ:£˜?4ÚÔ©ZáçÂVa4ëÝ½ZçíI»^ßßnvâcøV®þX ÿñÏ
ý|VxÆq6o2¥éŽÛÖÀD£“[Mçl`=ÜÒá>ðÙ¹„è[²îBˆ¯_‹}„ñ­ˆñq_¢èÜ6…œ)äÙ‹3en®åäûažô¤ŸÒíÛ–íýô6ŸM–Þífvº|¿;Ÿ,'Ã;Qå>ÔÿfIj=m¦æãîH®Aÿ­F1ûw“ùBÉ¯ãN¼çŸ÷ï‹'Ÿ®„)ÿ®­Lbÿc.Çÿ>º‰Ç·jcþýÿÆ³ç/+tÿÿž¾ÜxA÷ÿ/ž=ÜÿÿŸïîþÿåÃýˆ·opÿÿòáþÿßôþZÿw¾è¿Â}¸è¸è¸èÏÆéoÑÏžC½`˜¸ï—W'×ÝùsØK¼†UpTÇ‰$5þ8ÍsÍÅ¬®÷}[
Ì`Õ/„Ókí4¼¸ãY¬ÄŒ®+,gäßØà`–¸Ñäàó™èêsÈýÚ’ÿ’Ö
]·Óó,`µÿf³´±°Væ 0¨ŒñúbëbÌÝ0ÆÈ!:laÆYQ¡…÷“ÖÿÖi«faŠï–4¿ï5ÿ`Íñ`ÍqóuN~2³ŠÂÃrƒõk'k}§.Õ›Ûj(W?ô ¥¤9Êø0ÖZm¤ä›J3Üàôàáp•èñ&
‡§†i ¿qË^“´s'tI†yt=d@‘|C6	5…LDôŽhþË8Ûx÷ƒ‰âÿ†2ðÑ™~ZAþŸðÒÏ©lÄ‰øRp¶y2…Gk#o†ßeÚŸp>Oqz×üçã°´±qP~µQÂ—?K#aL_…uN†+­Ê³d•+{°Vü¯ƒƒMs8>37ŽŠ9zD¡Ó¬¢„ û€©‡ðÐ*R#øŒ
¨ö¨(VŠøCQ¨ŠÓéê²ÊR>{ÜnSfÇ²qò*Í÷½|o`<õò?Âxêž¬èë6™O5`ñü.ÆH‹íÂ ª¾pJ{ø’ìûâzIjâÀ^qû§”^ì+ŽÄ¶ÛB¢O
:wKª•¯+2|ºæžZ°U`PJÔ0t0.Rƒ‰y·T2-œÕ­ƒqé©V²®nƒ¬®"Þ&â7Ê{øÔd¬5"ö%Ž¦tƒdÊVû°)JU\ÙxvÖ–«l‡µ.*U¶·ZU´«ZÏª1ƒªuñ¼:kOµ.^T•9ÕºxYekªuñc54Òšû©ú¶Ö­¬}åR•M©ÖE¹\•FTð½R•æSð}£ŠÆSðå~©À—çÕ¿!óâœ0‘”(»ý¢¨1f”@h‘¶X•
T	MÔô*Ò<-¥ÊT‰Ù¬Å‚p7báìÉÐ¥ÈÊ'—Š7ÃáÕ„%öÆ˜‰¢š‰4Ñú3h=n"wIBã”kË;®JØ‘,ûÊêÄ!‹&J½àR/Ž¥ñ]J‘—P$²È“ŒFqÂsy1ÂCjs-Qe„ÐmŒ±«£Ô³zF“Ø~·Õ¾„îÅ”R?a©OíZ§“ö¶\šÿº<ÿueþëù¯ŸÅ^gÌ||”(·Ø=‚–Ú1¦9è[´­°ÝÑ)çYŽçÍÍŒ›Ÿ '±™[’;â#!sNÆù}˜Ö­Ó=¸9´ûöÔP‚m¢Ý†sŽ%0Ôn”©GoŒ¥Àô	—œ-™T*†ñçÊ5)%ª¸n4~5ü4‚–†±i£¿n@’û‹5TB´÷ë;_sßÛqQ*Sßv®ïpÆ‰(;eæÃ©Œ„Œ—Ó†û;¸G|«Ä¸û&HÇ°Qö114tV2›EøJ¬Þ÷ÉUˆY“ÁxÚD	Ú9/¦<|þ“õ±#ÿ<DJtþeÄÍµéóEXBÍÁìtñI¬6âk¿ªâî“MŒ}RuIERPe²ÜAz²\•|øÔŸœ¬…/£¡±n¹W‚Ïõ«9E!Éˆö’Dâ¥„0œJUõOåSÕ'39‡(¡Ðš=‡ÙyÓ"«¼J— ;úR—oØn´¿(b©aÂ
‹“ê½‘¡µ5»Zzeÿ©*_4Pèüb‡Î/KšS‹VhåÊžñK6KlªÍRÆ™ÍPzêõGLM³Ž#w8íÄ?´ûÇ3ÑG^Sr½X’¾Áãsû‚² v,œ9Ä€‹Ÿ 1,­{k‡B0rb[™utžÞPÊÃ"wŠ?×¶~yß>ŽÒùFî˜^Mcb±µ×©à#9ä¦dqcºHÆ’²WL§¶‹Oï±d¡sS¦æº§È×·ÓÄ¡ƒOvK)Úp˜Ÿˆ±!“èPX:]ONì2•skã‹~®8¸ àuxù>4æÜk²);4
:ô5]Š¡Àßé5õd§@>é²wOEŠ­óþ¶™^ˆ:ºlµvóÝ­vñývûH4Úk~î¨xÀ&<h·ö»ø(ÈAÊ½±(—
åB©P*V6D¥²^~öÓ³õÊ?+•JéWfÜå-|âWK¤¡k{nàö\Ö:6Úò™5°¿ðWØP÷)P1þjQ^XÒÚ×9£7ãž›zÜá
æ'dlú:^FË¨‹ìpƒäÞ§èó°hlâRÌ¼©<U’oÆçU¯.ö`©žyapµª±õ¾ÓmíÕvw[×«ËœLÃHÿ”„½øi£Òð1&ÂwÒŒßâX×ySmåÅU]ÞZ-J-þJeº—cr
ñ!ÄÕrå%Îb¡¼Êžžñxr¥JScvŽ“üg&
.l0—U;M<ô×xï‹UÉà`ÅŠ±*òûõîûýæŸÈÏç5^7àkT•.XåNˆú^³/, 1´+ºfZ¡‚·:"—](‘Ðs€ÆÀÖUSß‚8	~X¯Ñ>(ªe†¥òø÷ˆQ®[šzÛI¤ÑÀnhTŽdp¥†1ÅIÅœ!.KB8D¼¼C„DZçÇBVŽ&e‚±ì¾îáõ<ƒ”åhGµiÓ^},%ÂØžôêþ| Šwj˜U#úYjÒO-õROsIAÚL¢ ¢Ñ
ËóPÈH?¬p€ô‰¬Þ('ÖÚ’àDŒÚrRŠHm†`sþ$2TrˆXjvî¹å›½å’Ë
É@$x2&")Hµ^£N j |T<,Ï%ež×÷| òQÐXÿ-ø•Ôãˆ28½î ·ó±v-Ò¢Þ*|Å“ÊG÷²dY
AÆŒv‘Vu£¢É/P9—r^¸ºŽª^?&Þ‘ú ƒ¼¾ïL~QÿR)OruªÛ—6ô{È‰É…¬©§»ÊÑføóT²AL$4	
‰i
+óTAùølý&[‚ì
Ï*îãðµâ(ÓŒM#ædú½ôs$F“a`ÓTåó}ü6c#‰ñŒ!ÑÌÏn†¼Š?i$ç“òÜ1Ic8HY˜‚óÌ†m…}Ì<$ób}#üü]lï·ÚQçÙI™z#³‰ÊC¿.|Ëé«¬ZÜè¢./.‡&êŽd–r‰„™RñGQ~Y)”_ÐòQþ	ý(ÞB˜ásÈbÄ uJÎ 6˜…Ä™YÙµF¶3ÃX¼—`‰0ŸÎG!dîº_d½ÿ¾ÈZˆõoÖÆ|ÿßÒËRIÅÿ.½xVFÿß•þ¿¿Åç;òÿ•ùÜÚîÓýW"÷7vþ]Õ~èÞº«©^¿œýaZÜv{ž“Ïß¢æã£;+ü.$|nÙýwåJVšØW$$¤¹éjÁ7¨5ã¼°p¦óoüw–ƒó}Åý†çs\~¥°õ;ºþÞÑÞ^MBTnv/Ò8“–ø8hÓ1‡Gë™æ ˜sÐ·Å‡Y–ÙÞää2JR’çœ%1×,A®+k˜ý
$%¿³+Î‚`ìo‹ „Níàlr‚–<=¦c˜žQ§Ó¤åˆŠ#TezêgînÞ]÷é$Ž™¾ßAÙBsdß°…äß1e.ù“>6(fÉV¾Óê¾†ÿŒ~ëêÎeÍmùŒ4W²2«ltæMi Åƒ{áþóJÒpnz^@_V å/Ôû5'ñïÕUyìûB2ó;aõÁIýþÔ¿µóôø³=Œ;NßÌYw»Vßk5ã~ÓS°¸ù;oÜÆ›AIâ¼V¦ï´XSÄŽ1P	¹ïß¼ßkðvL(LYãó;¨qÉŸŠHü»±Wú=8HGÈ|Ð¢,
þ÷>?ÿ«´$ˆß¬kò¿m¼|Æ{ö¢\AýÏóçúŸßäóéôŒ¿¢ÕyP…ø»OEPË¿K88yóüí›“_R1õ=DvÛG
|êv«¾ÏAÝÂRfT*$3sÜ•¹H”¹›Çþ„Ï	Nð=+	nÏì!–ÙýÆ2û-ã˜ý'Ä$ûæñÈ~óôCz´‡`cÁÆRµ=÷zîõÜë!¸×÷Üë!¬×oÖ‹VH0SŒ]èn¸âÚÙ‡ýÙ¥6¶	Â•ò†jÛÛø›|(áKú"<ïZ/À¶½µ·ØÚÈù„áØx«ë Ú÷ÌÑqOþkËÇ’ÂTkÕ•5ZŒ@¬šxÖñ¹;ðhÇ §1'®ÔeÝTÎ ðK9bK.7·IøÇ‰vRNPï½¡‚XëåÒ{¸1Ó{ðpcöðyø<|>Ÿ‡ÏÃçáóðyø<|>Ÿ‡ÏÃçáóðyø<|>Ÿ‡ÏÃçáóðyø<|nõùÿŠg5 h 