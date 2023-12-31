#!/bin/bash
#  The MIT License (MIT)
# Copyright C 2023 Mateusz Piwek <https://200ms.net/>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


_FILE_REMOVE_CMD="rm"

[ -n "$DEBUG" ] && [[ $(echo "$DEBUG" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        set -xe || set -e

# also '--pretend' parameter can be used
[ -n "$PRETEND" ] && [[ $(echo "$PRETEND" | tr '[:upper:]' '[:lower:]') =~ ^y|yes|1|on$ ]] && \
        EXEC_RM='echo rm[pretend]' || EXEC_RM=$_FILE_REMOVE_CMD


OUTPUT="echo"


if [ "$_FILE_REMOVE_CMD" != "$EXEC_RM" ]; then
	echo "Pretend mode ON"
fi

MARK_DIR='/var/spool/fileswipe.timemark/'

OPT_FORCE=0

print_helpmsg_and_exit () {
	if [ -n "$1" ] ; then
		echo "error: $1"
		echo ""
	fi

	cat << EOF
$(basename $0) [--force|-f --pretend|-p] <dir path> <defer time> <rm freq.>
	selectively remove files from <dir path> location
	--force|-f   - force selective removal, ignore time lock
	--pretend|-p - don't remove just pretend
	<defer time> - time within files removal is deferred, all files that
	               are not old enough (specified by defer time) are not
	               removed
	<rm freq.>   - removal frequency of files after 'defer time' period
	               is passed

	Examples:
	$(basename $0) /path/to/directory 1week 2
	    remove every second file from '/path/to/directory' that is older
	    then 1week

	$(basename $0) /path/to/directory 7days 1
	    remove files from '/path/to/directory' that is older then 7 days

	$(basename $0) /path/to/directory 4weeks 3
	    remove every third file from '/path/to/directory' that has passed
	    one lunar cycle

$(basename $0) --help|-h
	print this help

EOF

	[ -n "$1" ] && exit 1 || exit 0
}


shopt -s extglob # enables extglob

for a in "$@"; do

	case $a in
		-h | --help)
			print_helpmsg_and_exit
		;;
		-f | --force)
			OPT_FORCE=1
		;;
		-p | --pretend)
			EXEC_RM='echo rm[--pretend]'
		;;
		+([0-9])d?(ay)?(s))
			SWIPE_DEFER_DAYS=$(echo $a | egrep -o '^[0-9]+')
		;;
		+([0-9])w?(eek)?(s))
			SWIPE_DEFER_DAYS=$(($(echo $a | egrep -o '^[0-9]+')*7))
		;;
		+([0-9]))
			RM_FREQ=$a
		;;
		*)
			if [ $(echo $a | cut -c -1) = '-' ]; then
				print_helpmsg_and_exit "Unknown option"
			else
				SWIPE_PATH=$a
			fi
	esac
done

shopt -u extglob

[ -z $SWIPE_PATH ] && print_helpmsg_and_exit "Missing dir. path"

if [ -d $SWIPE_PATH ]; then
	# absolute directory path
	ASWIPE_PATH=$(cd $SWIPE_PATH; pwd -P)
else
	print_helpmsg_and_exit "Path is not pointing to directory"
fi

[ -z $SWIPE_DEFER_DAYS ] && print_helpmsg_and_exit "Provide all required arguments"
if [ $SWIPE_DEFER_DAYS -lt 7 ] ; then
	echo "File removal defer time must be at least 7days"
	exit 2
fi

[ -z $RM_FREQ ] && print_helpmsg_and_exit "Provide all required arguments"
if [ $RM_FREQ -lt 1 ] || [ $RM_FREQ -gt 16 ]; then
	echo "Removal frequency must be between [1:16] range"
	exit 2
fi

SWIPE_DEFER_SEC=$(($SWIPE_DEFER_DAYS*24*60*60))
KEEP_MIN_CNT=$(($SWIPE_DEFER_DAYS*4)) # 7 * 4
TIME_LOCK_TEST_MARGIN=$((65*60)) # one hour and 5 min.


MARK_FILE=$MARK_DIR$(echo $ASWIPE_PATH | cut -c 2- | sed 's/\//_/g')

if [ ! -e $MARK_DIR ]; then
	if ! $(mkdir $MARK_DIR) ; then
		echo "Create '$MARK_DIR' directory, ensure full access for $(id -u):$(id -g) (current user)"
		exit 2
	fi
elif [ ! -d $MARK_DIR ]; then
	echo "'$MARK_DIR' shall be a directory"
	exit 2
fi

# Check when last swipe took a place
if [ -f $MARK_FILE ] && [ $(($(date +%s) - $(date +%s -r "$MARK_FILE") + $TIME_LOCK_TEST_MARGIN)) -lt $SWIPE_DEFER_SEC ]; then

	if [ $OPT_FORCE -eq 0 ]; then
		echo "No action due to early call, swipe allowed after $SWIPE_DEFER_DAYS day(s) since last removal."
		echo "Last removal date: $(date -r $MARK_FILE)"

		exit 0
	else
		echo "Forcing swipe operation, files might be removed although defer time has not been exceeded"
		echo "Last removal date: $(date -r $MARK_FILE)"

		while
			read -p "If you are sure, type 'yes|y', otherwise 'no|n'" conf

			case $(echo $conf | tr '[:upper:]' '[:lower:]') in
				y|yes)
					break
				;;
				n|no)
					echo "Exiting"
					exit 3
				;;
				*)
					continue
				;;
			esac
		do true; done
	fi
fi

# create new mark file
rm -f $MARK_FILE
cat > $MARK_FILE <<EOF
Last run of $0 $ASWIPE_PATH:
    $(date)
EOF

TO_KEEP_CNT=0
FOR_REMOVAL_CNT=0
RM_LIST=""

#date_integrity_chk_status=0
parity=$(($RM_FREQ-1))
for file in $(find "$SWIPE_PATH" -type f | sort); do
	age_in_sec=$(($(date +%s) - $(date +%s -r "$file")))

	if [ $age_in_sec -gt $SWIPE_DEFER_SEC ] && parity=$((($parity + 1)%$RM_FREQ)) && [ $parity -eq 0 ]; then
		echo -n 'For removal '

		FOR_REMOVAL_CNT=$(($FOR_REMOVAL_CNT+1))
		RM_LIST="$RM_LIST $file"

		#if [ $date_integrity_chk_status -ne 0 ]; then
		#	echo "!File name might not reflect file creation time"
		#fi
	else
		echo -n 'Keep        '
		TO_KEEP_CNT=$(($TO_KEEP_CNT+1))

		#if [ $date_integrity_chk_status -eq 0 ]; then
		#	date_integrity_chk_status=1
		#fi
	fi

	echo "$(($age_in_sec/(86400))) days old: $file"
done


if [ $TO_KEEP_CNT -gt $KEEP_MIN_CNT ]; then
	if [ -n "$RM_LIST" ]; then
		echo "Removing: "
		echo "    $(du -ch $RM_LIST | tail -n 1): $FOR_REMOVAL_CNT file(s)"

		$EXEC_RM $RM_LIST

		SUMMARY="$(du -ch $RM_LIST | tail -n 1): $FOR_REMOVAL_CNT file(s) removed"
		echo "$SUMMARY"
	else
		echo "No files found for removal"
		SUMMARY="No files old enough that could be removed"
	fi
else
	# keep last 30 files regardless of age
	echo "Too low pool ($TO_KEEP_CNT files - min. to keep: $KEEP_MIN_CNT), skipping any removals"
	SUMMARY="Too low file pool"
fi

echo "    with result:  $SUMMARY" >> $MARK_FILE

exit 0
