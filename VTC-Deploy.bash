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
� �|W �}k{۸��~��8��ZW��TI����kK��$��>~i���H�JRv\G�9��9���@�)˗즭խ#�� ��\
�[���cyv�o�)�����?�|������R�=/���^V�?�+/7^B���J�r�����:�&~`zB��<��ZY��`�[t��<~T<����-?�F����Lԝs�s���b�u�v`�@wb�C}+��E�#��s�c����z���y�y�)���ŶX�� (
�-���c��l}�^��?���k��(Ta<�/E�T~����[w�L�ga�|C��JYT��x[�BmC�?�AX�3W+W�t45��;�o��;A�홶#>��m�-_�X�\�ߦ��a�(�-LNը�d�}�_56ʆ�LƖG�����e9���5��}�?'|{a(��N�j���Sq�����Jg���phZ�W+Ww::<:����L^�>4^	k�[�� ɉ��h��������Aavj���A?W�:�l���=���2�ا�
ˇ��y�;�����}���۷�U�dsh��Vy~P�??�Z���������Go�+�y�;,�>���m{���}���_�U���]���5�;��� 	�gӷ{�� ߲6t�5	Ɠ@֗@\����C׃�f�}wSt������W��Ko��`�9P�o�R1�&�p=Q.��Y�9B`� ������	��}+0�_X^����e�-�l,/�LX+W��T����� �g�s*�<,����d4�;-#'v~���<y��^%j��sۺX'0f��	��\� }��7ͷq`�Bh�܉ >n]X}1S���~k?^	װ��=�s~a�ɺ[��nc����8S�{��{nϲ�T����kw���YEu&go���j�K.a�foy�?��(//m�#�bp���S��%E�����,��+�8<���Iƥ�x�:�E�,�/����<�;�^����cہ#��<�[�b�&�,7�[� �w�奡�3�����e��{f�����P��.��cKuT*+��n�Վ��#F����k3�-�qq��[�֍�q%��bh���1G3X�}��qg�E�8��Nv��6�\kF��h��}��5������[U�{��iXd��X����Ȑ�͇3"���""��0��\�T��9-��L�(*]�V�$2��t�@2R��(��'�	�ةg�
˴ta� �bR8�R�sh�~��yV���ط΋�d8�}]I�g�!?�(��֩o��۝j	��I�nň����9L��������h]I�yV��c���l�@"������G�H��ׯ)wj�]��i�֭��@F]B�f9u气 H�ȆE5*��hp9��hBv8=���
Y�x�{�E ��3�6�����8æ���ǔ� �}w��4 ra��TA�;�z�a�@~˓���&�&/�)�yh�����������3m�r��h�b$�#����: ������&��=;��V/\�'��{
�n����3���L$F�x��������A��A+BgcK�/F ~�>�7Ch����5��L�@��v��(K8�7�59��H�sB`W��e�i��Q�=�p�Z�}�;��mds����'O
%U\��r�4e�J&�7S�'���o��K)��W���B*9��C�c�:���d"�YZ����k��MgBQ�EO�/��� �A�TgIo�լ7[�^��\͙e�p�Q����Ƒ���V���'��r�H�65��y�n�7�p1�5��$'8��՚�M�~���waM�BI�C�7WR���2=���;�r����G�$%)}��x#�Z ��Ԩh>���,-������4f��D�zT%� ���&(M2��r���\2�(O6�TV����Q���E����Y�,?�
�CK@��lǄ��@|%`��GL��5m�\�;��2�.pЁ�玔p�ݾM����jR� ��7���ĳR{"'6�{��^8��
7� <��*������{���o���$���0J��Ƈ�� ����Nc�~�.��i�,R���u��� ��SZ
�87c�Z'�zxY�	߽u�ny����]lv*�ć�E9z�"l��!쏛���n�.W����FB�,V��� �L%�-w2���{`���n��d*�#��()0a w�)B�|�+߈�y)N,1q�����Ȝ��@��J��E��Nz�<�h�v�C��'����d���;9m�:K� #�Ƌ�|�;�Z)��N%�7�Ȩ��S��ONXH�i�|Y�\���J��&�x�=Ƈ����~#�ˉ�"x�gL��e��n_�u���%���SC{e����XM��
?yR}?�̢����7���RG���.<��`z/H���#z���%ٗ�t��1���?Q��'�-�u��, ;�^�8ݫC�j��6��
��z�	7���_'��l���Կ��݃���R����;+:&��^�������d���
��K��go�@=D��Ң�L(�1.9)���z{�S����]V袶V�M�3n�c�>Ƚi����Ƶ:H�Fp�㷸��1 ��Cv�%���\��&*+z X�������x���b�+t����R!~�k���1{���������G�8Xc9Z�	��A�����n��V�(:�9�(�0�Q�K��"���E't�
����AB5�j�Tt�S	+���Xj�����HTi�Ǩ
�=�dmZ����^n�	����	��:Ӹ>	ɒԍ�x켓���O���f놫{��c^�B���1�G7�ka�>�^�< 'a����z�7g������C��qb��;�B�=��tC32�V�p�2�^�}�|�_7��x�L����y��)-ܭ3��-�l�)��\8x�7^��������U��s�
WZP*��^%��점�zh��i<4�S��r4�$3	�����S������0E_/��_/sBIv�+k~m��6ݯ��+�J��"�?��[C�y��2F��0��o!rt�6�7����h��$#ژ/�$X��9p�0���"�Q�� R�(n��t����&iK)�;�LA�;";���ik��p ,f��Pb�)��ݘFE�W-\��oi���A�Z�������D7Dr�`I�*r���WN�Z[z�Ė���[�T=����2YT�/C�����%^kr��^���;~���_'v���̆�]�l��t�Q�)[[�d�t������V��5�?sGp�=�L�J�u��}kBa��MO��g�K@C=�+1���e���P���+����V��}���f��%G>q8����%���G���[+|W�rU��w����T|��g�zE+@O�p^[)妫1��򒎵��Uw�p�Vy�X�!����My���$8s=��ǟ�K9�	{�ȅ2�/2��YF���F/"I���[�F�i��{��gl�������Kk]�,5�T0�^xYS�9�;��Q�(��!<4@�W�W8_܉ӏ�PH������޵�����_���M�1- h��{�YON�ä�?4�;	{���-#yݱ�_��>(��#��W��M-@�ٟ�\?p�"� �Pȶ��s������*��� �!���	ђ�&V_�gȗP6 Y^�������'w�	�]��NCE>�S�'���5p�\�aQ/��ߩ�@�,2�+c��%a?"9̯xe�%W]Q�;�ޖ;�Ğ@�_����cΔ���/�����*���C{@x�Z((�	�g#�/^�JYe�Ɏ�+�V�ώ��S��?��}� ��e���ȋ�l�HDK�6+��a���~��U�0��fD�m�o��Jt:��-����3�f�]�~׃c� 3�p��Th�諁k/����X��FξN��ύ��8P�ֵ)]w��,��ٶ�ϯ��V���l�F�:v�� ފ�������&���m��	\�7]��S{3�Y�W~��&V����5<�h�4k�B�m�r�}y+�m��Hr ��8��/�E� a�Hy���Ed���
O�D�8���b	����=_�����ݹ�To�I&"����:jgP��b42����1�y ]A/HU}Ǟ��;�(�.�ʒo���+������*�z�Tf{#ӹL
p�M��s�<{�"�fS
zd��!����u���[
Z���Υuaf� '��;h��S�4����5�Zze�)F���?�1�S�S\NU�y��+W���ɓͧSz�Ʊ��nNIW@�,/��C<��C}��z��T��i-��JSO�N]��p��Q��V��U����[������>0�u8�ȍ ���[ %Y��Y�����}�<�)�4 B),\=��}�>�Gqk �7<�z}�#>������&�r����	�<1�3��)a<�h�$�F��q$S�اL� ��@n��p��go ÈФ$ ��P�9O�]����s �TOKq�%���RK��wL�rG�L����#���D6P�s�FJ3���I��h�DRC88�K�$�� ��i
�����Z��ꙮ���c$��Z ��T2�W���2[��n�kG(�xA�t��j�'ʫ�l �-�Y5��� ��RX�쓥����Ϫ*X�J��@�|Kkr��Q}ŋ_�����Od��K!���8��A�}�ٝ�F�x��ڇ���^�W���n�ώ�w[��;%��׶��8W��4���,'��j RI�.' ��9��Qpc�gxG7Eu�A؈�RHQ���SC�f?ۍN���i|�o��o�\�hJm}&�pm9���֬7�S�1h���qT0n�ݯ�r�<4�e��˾'M%)��q��L��MX�
Q�o��x5�mU����,%�iIs\BO�ȓ'�dd�yt����QY$=����O����L@G	H����!�EFSi��h'T�R����I��C�ȕ=X[��ۀ���@�O��թ?9Y3�놑{Ś�{J����/�V�NWs"��}\�U�,?8(=9,��3S��9X/_>*�E1��F�T[�:)<���Kl��y����)�
P�����i����t����;�T"��Ё$" f�­V���t��o\߉3�/Զ4���kzQ�^��ls��0�b���MV��w���$㔭6x�纠;krhB�"n��3Z�NJ��"�fl�O~���p��o&��?ĳXK�-�Veߟ�W��Y��iF�J6���W�J�$ƧO�`�-���T��8RQ9gpi�f����U)���$��U��#��3���'��8�O䔫84;�J�dNo�؛�z�@�4���u��Y��T�dU�,Py#�����4-Ɋ�0�L�~���;��7{=8�����lńO^ƹ"&s��-"����u�P��|96�sS�j��~�ӆ��n�xo��\��~H"���KlƟj�9(:����+��y`���	�J�}*3$�C�@u�5U����f	��?��ʶ#�O
�;*����f��Z�=,~��~*h��hkǼ:EǀG�1Fb�ov��M����{�]Ў?t�ϓ�M{Qg;싂�H$M�O4R����N^���=$@�݋�����Iw�o�5E9Dt֫&�z����qP��N)��<�f^�/KM1rQ�X�����P�ka�$i
5tgA0�,�1�|@�+�����)jp\�-������)���L�R� �I7�e�D-5�c�����vc��u��I;�������hm\]�:����Z��6�*.���)�G��5%�*��Ġ�F�Cm���N���P�W�S���|~k!���^½5X�N���ҋ�C6�� ��u"x�uj�����hX�]M'�hv�K־������q&��n\�I�� &��/R�Rz4�S�F^�^�"���$Րr6��@� 1�=�yޅK�g�Y۫w����7��L^A�SZ�	G��c8
�'�{xT���������Y��x�+��`��puf���%N=�w���w�F�ސ�]�F��!S�����(>�����bI�]h�쓝V�)#���%S��`T��d){�!����"R)h�r�ں�5� N�,&����S۪ӷ:mw�@����3_�{Ũ6Z�����t|��:0������!ڊR��S�㖆x��lN���ݪj�Y9I-Gۢ[��������*�W�����ә�I�F>�
���O�j���rdMg1<���UԷ��*z3KRs�zܸ[~F���5��N!"|��e:}��L�+��t��>~꽐/�H�1���?���z���s��:�]��Ҵ��B�j�xT�W�S����jZon_�2Y���R��x��ёh��ȏ�u@�;L�b�z���vn�-,��k������$��0���c
VP���>[��!��G�=ܱ84]���6'������=0w�",�Ͼ�d�܆�f�[x����A	"a�M� c<���!����r{�l����c���8�y�G��U8p�ӷ��+�������o�j@�?4z<WW)�����^����R�Q��Tbo~�����x���lD ��T*Ub��z?�n���D�W\ʏ���~W�+��?&~�����N�ۈ��a$�H�䒳��!�K����{d��d'�#;���9<�F�Pؖ����&\rU5{C���_i6�������Y-�QV�-|�,��@x6�D��M��ICó��)���&���}�v��3�]��ZIنn�Rd�-cD�Z�G�|�5��+.�	4�a��zC]0)RAH�F}���fٙ
͆.ީ�G�;��p5��آ�N3�!���ta�B�k�Y :�j�~BV~�5?i��М)d�^L�gB��Ee�Vj��t�^�f����n�[�.����&)ڦ8V���q���m�5�%�9�ɔ
��RWg�S��q�u�t�`�Pә�4���H @C�w���8{�	^����C�C��,��k1V�X}w��5��[�gS��t�[�����"W M|���C[�g�F�����w��_��ѥN*�ɶ�+��r(\����K��/�D��d�%h0L7�t�,]-0p=v��lt[�T�<��(��@rd2f��G���b�	t�ۂC"{R�D�| f�~?�hߩ-4? ��6�"��K���Y����^��A�h��׆���戥�U��B�%�3i1Ӽ)�-��~Ra	8<�<�j7dő�����Q�).	�đQ@᾽갗uǟx�:�h��*D@�9�~CU�#6yel�&��Ð2�Z��a��5�wۗ�J��Z�x�S�z��`c�Ծ�VO�A�D��g	������=��*J��q$h�O�18��c
|k�*#�P�iIV��:���u��C�g(���$�
i�O]�#K�;i�ޔ1�
`��^ |@���|)�ڢ����s�㱜=��مʸHVy	VO\G>Qib?�T�0U�^Ӊbh��9fI�Ir���CC�� �@��e���gӼ���1q�����w�kQ�G{ �B������>��d^d�J�>�	J��K�f٨E��,!�m'&*s5��RS�G+���)�(���U[t���UyI�a$?���R'Q�+�L��}� �h7A;~|����52���TO��#�d�B���"O��?�`�v	�k����Ul���a�-�Q^���:�o��V�����tI_���i�8����	nh&����}#M=��6d���PRc~F��C�t)l9-.���*<�[�p��l�%��(�����jq5��h���v,V�
�Y��FT��sj�4�R	r�!���93&y��HWaѪ�zeD���_v��4`�mc�A�rg��mxta��}���Y	~��c/����
��\>�0����p������,�c�4�7�ld~9�ً҇Ge��%C_�5|S�o�3���u�S���=?َ|7������^���O� 6p���*��Wy��u}�drJ/�q�L#�;V���||b��g��O,��������v�?����nw~E.s4=�NW��o��"V���c{`B[�R���f��֘��o�Ҿ�g��EJ��,�����z�1�Q�"ՁM�����p@�SA�.a]����,�x�o�G� �<Q�?9=Z��� M�XpCj �2Α~W�]�E�4Ͼ|�����M��>�������md��c���@GV�No8�
��ک����H��ù��W�t��Ϋ�_����;��n�ȓ��^���CO�4��+/�	\��L"�8�0�^�ϴ(;�?v�k�ʕ7=z�����qF<��*UC��[��˪���ZW��Rї��d�����	D̡�������!4��-`��`���%UT��zm�S��b$�f$7&Ē���[�Bz���GT2�P�T�<Ka��VW5.OA(��vt&H� I�Jϊ�rWF�b�������0V�`��^����}�(�Q�bV���P�G�z�Xٔ�e��bo�����~-��r.�l�Ѵ\[=�̟S�O��0t�E���:b���Qqq���[A��cy)!ɉ��(5��X�����zI���\,%�243>e�vd6�#�		C�>l��t��p��U l�փ����J6��H�̄ي%�L�!�̘��2
�o���!ce[p�9���4#�!���Y�4���K�ݐ�%��,�0��iQWT_��D,�-`���F"�2����-b���O��&+�X�B��~xS�����.�3�"i��y��ႍ�m��Doq)�
���N��ަe�"�x<4;n��HY�KW�j�yژ��pƔfko)c热&J���"%�H����ی0���vԿI�źXi�0��)�)\m1�k����;V�)c!Fy={���kX[����Z���Y�l!}m�JHYY�ժ�-ʵTl�7>Ժ�޵843�B�ȭ��7<0dp�9���Xl���c(~�$g�Y�*'F)WA�_�jC!(�z�&PQ<f/XU>Lz 둏��9\
�p~h8v����4�:���ȜyU�W���g{��[��`z�Τ��c�~�a(��,q��+r�La1H�CV6�jI�AٌI��o��ݶ��{���:;���:���8b`b���(Dn×A�1h1�<7�K��rj��4 Պ
9�?,/�Y$m�
�� Tƥ�c�²9.h4J���
���4L�E������K�$Ki2�<���H�VQ��R���W7U;�)�|��[�[(���	�o�)w�#J��
���J�W(��3}� Z^����MF��&�9`��#��}�\_��c�[ĸ���;XÜ{��t[�tK��S��>�����i0N6�	3-t7G|&u��~H�I1\�:�gI2�X
i.6#x����R���Lk��	!WL�Y��Ù-u����S���u�XX>���|?햼2��ze�y5����h݈+�W��)���p�,���M�WeO����=Y���\���Eݷ�ȓ��&5�~�-q��2_�I�E����-T��gd=-�-V]"���DT'j���V~C^_���*5�E5k	��N�U �gigp3���U�v�9�Y7�/b9��2���_Z�1�Jףr㉣|����+�wj_�:����6�#�>xApZ��Կ�d%�;����вY�*��s�'^��5��r]�rM�K�І���y��8�NL�L.��K�����w�o�U��~*v5���`���ӥ�T�j��O(�c�.�]��=Û8��u�\S����U�u3��j��mâH�"�K/�)������oTc�M��h���2[m5U�t=ͭ��T-i���KŔ�<�X!�̝VE����iB�%q��d��S�M�`#MF|%�v��F�k�fl���x=�hH�L�[k�}�{rW(S��2�vayn�l�~�.�tm��2=}[��}_B�1C#h�=�ڞ��rS掠,"�z��')�C��5�ĉ��%���G���������T]Y�Ǭ2���0�k�4�/���I�M�K�m)@&A�Dt-�!
�t�nl���W�Z^�%c��Q��������?�/���;�����eu9g�D�#��ճ�M!���� L����bƖ�*-8:j�]3{���?W��������������qh戛]�V<Uj2�:��ړ��]�Ȅ���I����ė��鉼#�<8��ThpD�BT0�����l���ƃ�R�5
Dݏ:�^��=mE�$�FG
����{Ƕ?��i4�q�8��L�t���u��Ŕ��ض�щ={T�)4�)�� �/��
6�Ix'̷Pя�*1P�Nu�+�+ ���#U \^;�ww��Z�֐S�^G뇐����.gJ(��[*�_̶����к���{㉟���7���6���}#k�lkߥ��t��Ԑzڝsh�Mò��EK�g����ڤ]?�~��D��yz>X�����,��H�s����ʈm4u8��f�+�]��6jj1E�h�b�h3�.��r���>9�D+n�)�O ;h����A{0��I�7F��Tk�S��RB��|�*(,�<L$����,�o:,�>I4�X4�1�Y�;إ�5�X>�v��l$�6?�Q�;HP	�TKa"� '�V�qy)�m��:(�h�k��[1��	Y$feq��0k׊��Q���i:��f�<qfhҖM�`J�W>�(	�F}Z���df�8�-B����Q4�{�'�bP�*1�)HB�����h:f������tu�j?�l3K<����-Vc�T$뭊َ�<��_b�_�s2��g�k��$ω��ir1J��\|��b���gق��0�H��C)��	�0QZyմ��V��sŕց������XD�y�jc�g�rv�B��F�O	��<��Ϙ�w]�L��H�Qse�g�ԇ���e?��	mN��c�z�o-���T,�������s2s��9�����}���O�iT&����n9�MW�,"�&"�T�N������f�r�@c���Ck`�)�(t����T1�Q���yܩ���Z�mr��Ϊv�O��ű�����}��LS`�8\;΅����#?�N6���B+�������}��r	qx8(E�װ?9�C0���W�U=��H#  �(��C~"_ⷯ��Lh
M!�	B���Z��\�]�O�ÿE��uL�t�Lr�s���~��X��~��}�Ǳ�ò<? 	c����C9�/�]WOy��#�k>@R�;T��m���#�x�` ]�¼[C�|֭Ⱇ�"����M�s����Aa�b��n�65�^4o�JS�������S��ˤ�~��S%�m2��d;84��e]l/���*�y-"2�2�#ظ�N!�=2F�֟�ls��;c�ڨ���[\߉�}ƺĖ�mFn|ޘ�L�s'�L<6"�ZKZ��'@��&��޻��>db��t��B�����~0K�%�D������d�䒬w�d�2k��o$�	z�8����³A+8��<4p�>Y~�/�·���'(M�����X�#�o��o����L�$�ʣ�*V[u��Vm�m�ِ��41��9be�	��
!oJ �I�2���A|��ٛI�h���?��'�(�S ���������└�f�)��cU����QI�$|[_l��Ф�9�)g:����Ǔt=$����݊��b�z�Q>�F�j�NI6��B�LTI?M$�u�99�3��l0�jܓ!�91�.OQ���CpR�Ԟ���wȊ�����8� S�B��Wqb�
u"��3P�r� s)�!��Q'�}t����ƕ֨���I��ѧ�xi�M��e�:+c!/�>����T���#7��C�|�H<�\D�1��(�n�֗������ۖ'Pv� � Y�]�g���4��TrS�L���F�`� H�з�Q����F��R����Yl�e-�B��}��k;ltbҔ�J�5�1�WkEϗu�Y z{q�X418�j9�2𯸅>s�E;W�!����=w|6u�B��p�f��6H�ğU@�^�&����D.�ܡ��~�iQ����S��	�T�9�	͡OM���ϱ�U�8r�������y�(�Jt��s��"aՠݽ�ݷ_�۪�}��e*PN���6�/�&
cx�Otzqǰ���r"�=Ej���N�[R����E�;�2g�>L��P�0���[߶Nl���[�}}�s�����[��>�~�N�~�[��Ao���Kj#9��˥�tn��X�ڴ�IJ'�W�S-n���+�כx��5�Y��M�p�	ca�iTu��8oO��}�Gn��Bvn�]�ꗵ�6�0v:�<P�W���LѬ��ؽ�o�����C#�R�����$Sh%��lG*��f���̽�
��ʫ.�O��J]�Y��F�%���һ�I�����<�h 6��"�#V�`6�I}%ClcLt����NǶZ���2bM,�F�曺��g��yǂW�mU1�
��؍�D,�
�h8��םs�sT���6�ȵ��\��|������O<�)���1i��d�jek�P��š�j3�v��&ew�x�LN�	ŻJ���q�T� z�������g7��_��͖�+^�܌����`�`��8����*�scHU��R`��Tо-�\�aQ�蟥 ���D�,���i���Ǣ=� �Ix����R.�� \�۰���h�ɖ���Yݧ/��T���C�fH	1��,z�(�T��q�AC��d��V3ݴ���'%P�:�	�:�,Bs���Y`��&�psb��'��n4s3�*5.���ި�����8rxu��q��̇��
�M|���h��ɤ��O�%�ES�ʞ���!�CNP8ͪ���Ƙ�v�k�=?�􊬲DI]PG��F3��w��âO�k�!0?M��9R��d`���<*q�����`˄�0Lϭ���41Y����������V;�*��g<k�r�d����Hn����w����N�ZW0�)��h�N���@��9�lQ�������H���I���A9bZ ��Fn��,���p{�4,���I;	_��R�g:� 1Mp�w�G#�����B ��a�j ���e��Ӆ��Q\G�����/���↲j%k����꼔�>�x� a�}��S��e%Vw����bq��A�^=���!��?�����P)+�G�;Ȭ��tP�c��cpA�ў�#��6�N`~� v��a�ɼ,��"��G�'��^^��B�������������n��ꭝo���}�)~qê02������^;����P��g��T*��x��r��Ƌ�/*��9�xY�A��U���eB!~p ��C+�~����Ǐ(����}K�G�R;���Sz^H*錅��[��(SC�ল�Xx!�"[�o��̻nQNu�G��06
X���_&�KQ�C]Vm��$���c��r��x[�Bm�%���C������v�ҷ�۝ #�T�������`�`8�������ꍶ��kA8!�W��`����hGm��w E�(,�&<�T���}�����E)0,$O� c�{ERq� ��g�MU;?�e�Ы����i�"�D�vop����l�b2������T���yv�b���T�ȣg5��(b&k<t/��K���k�6t׊l���_rnY���퓨)_��Y��7�L�;R�y��|��X�h�n�3P�ۙzYJ�Ê����hY���(����Ө���"�a*s��s@�(W_�x�}���g[Վ�J*6��n���hcr�r��~�Q����ւU�q�U'(���KY,Y��)"d����5������ӕ���L6D=S2z�l�o��8�4K�Z"vIx�\�ߜ��j�LL��Y=�uGPs��F��"���P��v[*��؇�E|���J��Ug���g��X�/wK���)F��:W�<���3w1�ʞk�����ӸC�s�&	���%�(�H�,LKG��'�S`H9�^�y�Fvq��$My�D����o�@��� ��(\oR�  w�[M���R
�^�B���-xmhۈE�=C�- �G��?��� �
pnF��&��Ȁ'�p�꯴U�}!S�Hg�T��x��+]�?��k'w�0ظ�t���5t/�|C��1��| F\J��|�T�/�1��w����oRW9��{j	U���j�Mkw"X4u�-8��ہ���T�d-�%8	R���ڝ�M�d-��p�����W��C_��}}(V�jlz���o��^��v�.h�c2J��u���Nc�[��n��Z��4gh�]G��̝MF4�=�m잮mVq��嶶|R)>��K�8:xx#q���3���Ե���	�sXG!#�D�d8䯇������uֈ\����M����E���\.�{�lUQ�ټh��L�8�t�*[�]��JDQݕ�*솮Rօ�Xm�~�u�h�^Y��C��Ĉ842�K��K�IfQ0�by9��f�q��[sK��X���O)!�2:�O�z���<X	�Ns�x����vw��U�=t�ώwj����u��[�U�_4��.�h5n���K�?t����V��:���?4�ԩZ���Va4�ݽZ��I�^��nv�c�V��X����
�|Vx�q6o2������D��[M�l`=���>�ٹ��[��B��_�}���q_���6��)�ً3en����a������ۖ���6�M���fv�|�;�,'�;Q�>��fIj=m����H�A��F1�w��Bɯ�N�����'���)���Lb�c.��>��Ƿjc���Ƴ�/+t�����xA��/�=�������������op���������Z�w���}���������o�ϞC�`���W'���s�K��UpTǉ$5�8�s�Ŭ��}[
�`�/��k�4���Y�Č�+,g����`���������s��ڒ���
]���,`��f����V� 0����b�b��0��!:la�YQ�������i�fa��4��5�`��`�q�uN~�2����r��k'k}�.՛�j(W?� ��9ʏ�0�Zm��J3�����p���&
���i �q��^��s'tI�yt=d@�|C6	5�LD�h��8�x������2�љ~�ZA����ϩlĉ�Rp�y2�Gk#o���eڟp>Oqz���㰴�qP~�Q?K#aL_�uN�+�ʳd�+{�V����Ms8>37���9zD�Ӭ�� ������*R#��
���(V��CQ������R>{܍nSf��q�*����|o`<��?�xꞬ���6�O5`��.�H�� ��pJ{������zIj��^q����^�+�Ķ�B�O
:wK���+2|���Z�U`PJ�0t�0.R��y�T2-�խ�q�V��n���"�&�7�{�Ԑd�5"�%��t��d�V��)JU\�xv���l��.*U��ZU��ZϪ1��u�:kO�.^T�9պxYek�u�c54�Қ����֭�}�R�M��E�\�FT�R��S�}���S��~����տ!��0��(����1f�@h��X�
T	M��*�<-��T�٬łp7b���Х��'��7��Մ%�Ƙ����4��3h=n"wIB�k�;�Jؑ,����!�&J��R/���]J��P$�ȓ�Fq�sy1�Cjs-Qe��m����ԳzF��~�վ��ō��R?a�O�Z����\���<�ue������^g�||�(��=����1�9�[�����)�Y����͌�� '��[�;�#!sN��}�֭�=�9�����P�m�݆s�%0�n��Go����	��-�T�*����5)%��n4~5�4����i��n@���5TB���;�_s��qQ*S��v��pƐ�(;e�é����ӆ�;�G|�ĸ�&HǰQ�114tV2�E�J����U�Y��x�D	�9/�<|�����#�<DJt�e�͵��EXB���t�I�6�k����M�}RuIERPe��Az�\�|�ԟ���/���n�W����9E!Ɉ��D❥�0�JU�O�S�'39�(�К=��y�"��J��;�R�o�n��(b�a�
��꽑��5�Zze��*_4P��b��/K�S�Vh�ʞ�K6Kl���Rƙ�Pz��GLM��#w8��?����3�G^Sr�X����s����v,�9���� 1,�{k�B0rb[�ut��P��"w�?׶~y�>���F�^Mcb��ש�#9�dqc�Hƒ�WL���O�d�sS�����׷�ġ��OvK)�p����!��PX:]ON�2�sk�~�8���ux�>4��k�);4
:�5]���ߐ�5�d�@>�wOE�������^�:�l�v�ݭv��v�H4�k~�x�&<h����(�A���(�
�B�P*V6D��^~�ӳ����?+�J�W�f��-|�WK��k{n��\�:6��5���W�P�)P1�jQ^X���9�7���z܍�
�'dl�:^Fˍ����p�������hl�R̼��<U�o��U�.�`��yap������m��vw[�׫˜L�H������i���1&�wҌ��X�ySm��U]�Z-J-�Je��cr
�!��r�%�b��ʞ��xr�JScv���g&
.l0�U;M<��x��U��`ō��*����������5^7�kT�.X�N��^�/,�1�+�fZ���:"�](��s����US߂8	~X��>(�e������Q�[�z�I���nhT�dp��1�IŜ!.KB8D��C�DZ��BV�&e�������<���hG�i�^},%�؞���| �wj�U#��Yj�O-��ROsIA�L�����
��P�H?�p���('�ڒ�D��rR�Hm�`s��$2Tr�Xjv�国���
�@$x�2&")H�^�N�j�|T<,�%e���| �Q�X�-����28��v-Ң�*|œ�G��dY
Aƌv�Vu���/P9��r^����^?&ޑ� ����L~Q�R)O�ru���6�{ȉɅ������f��T�AL$4	
�i
+�TA��l�&[��
�*����(ӌM#�d���s$F�a`�T��}�6c#��!���n���?i$���1Ic8HY���̆m�}�<$�b}#��]l��Q��I�z#���C��.|�髬Z��./.�&�d�r���R�GQ~Y)�_Џ�Q�	�(�B��s�bĠuJΠ6��ęYٵF�3�X��`�0��G!d�_d����Z��o��|���ˍRI��.�xVF��������;���������W"�7v�]�~�޺��^���aZ�v{���ߢ��;+�.$|n��w�JV���W$$���j�7�5���p��o�w���}����s\~���;�����^MBTnv/�8����8h�1�G�栘s��ŇY�����2JR��%1�,A�+k��
$%��+΂`�o� �N��lr��<=�c��Q�Ӥ刊#Tez�g�n�]��$�����A�Bsd߰���1e.��>6(f�V�������~���e�m��4W�2�lt�Mi Ń{���J�pnz^@_V �/��5'���Uy��B2�;a��I���Կ�����=�;N��Yw�V�k5�~�S���;o���AI�V��XSĎ1P	��ߝ��k�vL(LY��;�qɟ�H���W�=8HG�|Т,
��>?���$�߬�k�m�|�{��\A����������􌿢�yP���OEP˿K88y����_R1�=Dv�G
|�v���A��RfT*$3s܏��H�������	N�=+	n��!����2�-��'�$����~���Cz��`c��R�=�z����!�����!��o֋VH0S�]�n���ه�٥6�	�j����|(�K�"<�Z/�������������x�끠����qO�k�ǒ�TkՕ5Z�@��x��;�h� �1'��e�TΠ�K9bK.7�I�ǉvRNP｡�X���{�1�{�pc��y�<|>��������y�<|>��������y�<|>��������y�<|n����g5 h 