#!/bin/sh

set -eu

. ./lib/getoptions.sh
. ./lib/getoptions_help.sh
. ./lib/getoptions_abbr.sh

VERSION=0.1
BLOOD_TYPES='A | B | O | AB'

: "${LANG:=C}"

# shellcheck disable=SC1083,SC2016,SC2145
parser_definition() {
	array() { param ":push $@"; } # custom helper function
	setup   REST error:error on:1 off: export:true plus:true width:35 help:usage abbr:true -- \
		"Usage: ${2##*/} [options...] [arguments...]" '' \
		'getoptions advanced example' ''
	msg     label:"OPTION" -- "DESCRIPTION"
	flag    FLAG_A    -a --flag-a on:1 off: init:= export:
	flag    FLAG_B    -b +b --{no-}flag-b on:ON off:OFF init:@off
	flag    FLAG_C    -c +c --{no-}flag-c on:1 off:0 init:@unset
	flag    VERBOSE   -v +v --{no-}verbose counter:true init:=0
	param   PARAM     -p    --param init:="default"
	param   LANG            --lang init:@none # or init:="$LANG" for using current value
	param   NUMBER          --number validate:number
	param   RANGE           --range validate:'range 10 100' \
		-- '10 - 100'
	param   PATTERN         --pattern pattern:'foo | bar' \
		-- 'foo | bar'
	param   BLOOD_TYPE      --blood-type validate:blood_type pattern:"$BLOOD_TYPES" \
		-- "$BLOOD_TYPES"
	param   REGEX           --regex validate:'regex "^[1-9][0-9]*$"' \
		-- '^[1-9][0-9]*$'
	param   :multiple       --multiple init:'MULTIPLE=""' var:MULTIPLE
	array   ARRAY           --append init:'ARRAY=""' var:ARRAY
	param   :'action "$1" p1 p2' --act1 --act2 var:param
	option  OPTION    -o +o --{no-}option on:"on value" off:"off value"
	disp    :"getoptions parser_definition parse ''" --generate \
		-- 'Display parser code'
	disp    :usage -h --help
	disp    VERSION --version
}

error() {
	case $2 in
		unknown) echo "$1" ;;
		number:*) echo "Not a number: $3" ;;
		range:1) echo "Not a number: $3" ;;
		range:2) echo "Out of range ($5 - $6): $3"; return 2 ;;
		pattern:"$BLOOD_TYPES") echo "Invalid blood type: $3"; return 2 ;;
		regex:*) echo "Not match regex ($4): $3" ;;
		*) return 0 ;; # Display default error
	esac
	return 1
}

number() {
	case $OPTARG in (*[!0-9]*) return 1; esac
}

blood_type() {
	# Normalization only
	case $OPTARG in
		a) OPTARG="A" ;;
		b) OPTARG="B" ;;
		[aA][bB]) OPTARG="AB" ;;
		o) OPTARG="O" ;;
	esac
}

range() {
	number || return 1
	[ "$1" -le "$OPTARG" ] && [ "$OPTARG" -le "$2" ] && return 0
	return 2
}

regex() {
	awk -v s="$OPTARG" -v r="$1" 'BEGIN{exit match(s, r)==0}'
}

multiple() {
	MULTIPLE="${MULTIPLE}${MULTIPLE:+,}${OPTARG}"
}

push() {
	# Store multiple (escaped) values in one variable in a POSIX compliant way
	set -- "$1" "$OPTARG"
	until [ "${2#*\'}" = "$2" ] && eval "$1=\"\$$1 '\${3:-}\$2'\""; do
		set -- "$1" "${2#*\'}" "${2%%\'*}'\"'\"'"
	done

	# for bash, etc
	# eval "$1+=(\"\$OPTARG\")"
}

action() {
	# Example of passing options and parameters
	echo "Do action: option => [$1], param=>[$2, $3], arg => [$OPTARG]"
	exit
}

eval "$(getoptions parser_definition parse "$0")"
parse "$@"
eval "set -- $REST"

# shellcheck disable=SC2153
{
	echo "FLAG_A: $FLAG_A"
	echo "FLAG_B: $FLAG_B"
	if [ ${FLAG_C+x} ]; then
		echo "FLAG_C: $FLAG_C"
	else
		echo "FLAG_C: <unset>"
	fi
	echo "VERBOSE: $VERBOSE"
	echo "PARAM: $PARAM"
	echo "LANG: $LANG"
	echo "NUMBER: $NUMBER"
	echo "RANGE: $RANGE"
	echo "PATTERN: $PATTERN"
	echo "BLOOD_TYPE: $BLOOD_TYPE"
	echo "REGEX: $REGEX"
	echo "MULTIPLE: $MULTIPLE"
	echo "OPTION: $OPTION"
	echo "VERSION: $VERSION"
	disp_array() {
		eval "set -- $1"
		i=0
		while [ $# -gt 0 ] && i=$((i + 1)); do
			echo "ARRAY $i: $1"
			shift
		done
	}
	disp_array "$ARRAY"
	# printf '%s\n' "${ARRAY[@]}" # for bash

	i=0
	while [ $# -gt 0 ] && i=$((i + 1)); do
		echo "$i: $1"
		shift
	done
}
