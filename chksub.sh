#!/bin/sh
# Copyright 2020 Ali Cherry <cmcrc@alicherry.net>
# This file is part of Ali's Teaching Assistant Assistant (ATTA).
#
# ATTA is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# ATTA is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ATTA.  If not, see <https://www.gnu.org/licenses/>.

set -e

script_name="$(basename "$0")"
config="/etc/chksub.json"
usage="Lab submission validity check usage:
    ${script_name} [-c CONFIG] labid
Options:
    -h, --help          print this
    -c CONFIG, --config CONFIG
                        use CONFIG as the submission configuaration. Default is
                        ${config}
Where:
    labid               The lab # that you want to check your submissions for"

printusage () {
    echo "$usage"
}

valargs () {
    # $@
    # @out * config
    # @out lab_id
    while [ "$#" -gt 1 ];
    do
        case "$1" in
            -h|--help)
                printusage
                exit 0
                ;;
            -c|--config)
                config="${2}"
                shift 2
                ;;
            *)
                ;;
        esac
    done
    if [ "$#" -ne 1 ]; then
        echo "error: valargs - bad argumemts!" 1>&2
        printusage
        return 1
    fi
    lab_id="${1}"
}

ctype_digit () {
    case "${1}" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

chklab () {
    # $1 config
    # $2 labid
    local conf
    local lab
    local count
    local file
    local index
    local uservar
    conf="$1"
    lab="$2"
    if [ -z "${conf}" ]; then
        echo "error: chklab - config empty or not defined" 1>&2
        return 1
    fi
    if [ ! -f "${conf}" ]; then
        echo "error; chklab - config '${conf}' does not exists" 1>&2
        return 1
    fi
    if [ ! -r "${conf}" ]; then
        echo "error: chklab - config '${conf}' is not readable" 1>&2
        return 1
    fi
    if [ -z "${lab}" ]; then
        echo "error: chklab - lab empty or not defined" 1>&2
        return 1
    fi
    uservar=`jq -r ".user_variable" "${conf}"`
    if [ "${uservar}" = "null" ]; then
        uservar='$user'
    fi
    count=`jq -r ".labs[\"${lab}\"][\"problems\"]" "${conf}"`
    if [ -z "${count}" ]; then
        echo "error: chklab - invalid lab id '${lab}' or bad config" 1>&2
        return 1
    fi
    for index in $(seq -s " " "1" "${count}")
    do
        file=`jq -r ".labs[\"${lab}\"][\"paths\"][${index} - 1]" "${conf}"`
        if [ -z "${file}" ]; then
            echo "error: chklab - invalid path or bad config" 1>&2
            return 1
        fi
        file="$(echo "${file}" | sed "s/${uservar}/${USER}/g")"
        if [ -f "${file}" ]; then
            echo "lab ${lab}, problem ${index}: valid ($file)"
        else
            echo "lab ${lab}, problem ${index}: invalid ($file)"
        fi
    done
    return 0
}

run () {
    # $@
    valargs "$@"
    chklab "${config}" "${lab_id}"
}

run "$@"
