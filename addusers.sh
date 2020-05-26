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

script_name="$(basename "${0}")"
system=0
ldap=0
gridengine=0
qconf="qconf"
useradd="useradd"
ldapadduser="ldapadduser"
usage="Usage:
    ${script_name} [-s [-u USERADD_ARGS] | -l GROUP [-a LDAP_ADDUSER]]
                [-g ACL [-q QCONF]] userslist
Options:
    -h, --help          print this
    -s, --system        Add user to the system using useradd. Mutually exclusive
                        with -l (ldapp)
    -u USERADD_ARGS, --useradd_args USERADD_ARGS
                        USERADD_ARGS are passed to the useradd command, this is
                        helpful to specify the user's group or other options.
    -l GROUP, --ldap GROUP
                        Add user to ldap directory to the GROUP group
                        using ldapadduser. Mutually exclusive with -s (system)
    -a LDAP_ADDUSER, --ldapadduser LDAP_ADDUSER
                        Set ldapadduser binary path to LDAP_ADDUSER. Defaults
                        to ${ldapadduser}
    -g ACL, --grid-engine ACL
                        Add user to grid engine access control list ACL using
                        qconf
    -q QCONF, --qconf QCONF
                        Set qconf binary path to QCONF. Defaults to ${qconf}
Where:
    userslist           file containing a list of newline separated entries
                        of usernames to add"

printusage () {
    echo "${usage}"
}

maxshift () {
    # $1 - the desired shift
    # $2 - the "$#" of the caller
    local desired
    local nargs
    desired="${1}"
    nargs="${2}"
    if [ -z "${desired}" ]; then
        echo "error: maxshift - desired is not defined or empty" 1>&2
        return 1
    fi
    if [ -z "${nargs}" ]; then
        echo "error: maxshift - nargs is not defiend or empty" 1>&2
        return 1
    fi
    if [ "${desired}" -gt "${nargs}" ]; then
        echo "${nargs}"
    else
        echo "${desired}"
    fi
}

valargs () {
    # $@ cl args
    # @out * system
    # @out * useradd_args
    # @out * ldap
    # @out * ldap_group
    # @out * gridengine
    # @out * gridengine_acl
    # @out * qconf
    # @out * users_list
    while [ "$#" -gt 0 ];
    do
        case "$1" in
            -h|--help)
                printusage
                exit 0
                ;;
            -s|--system)
                if [ "${ldap}" -eq 1 ]; then
                    echo "error: valargs - conflicting arguments" 1>&2
                    return 1
                fi
                system=1
                shift 1
                ;;
            -u|--useradd_args)
                useradd_args="$2"
                shift `maxshift 2 "$#"`
                ;;
            -l|--ldap)
                if [ "${system}" -eq 1 ]; then
                    echo "error: valargs - conflicting arguments" 1>&2
                    return 1
                fi
                ldap=1
                ldap_group="${2}"
                shift `maxshift 2 "$#"`
                ;;
            -a|--ldapadduser)
                ldapadduser="${2}"
                shift `maxshift 2 "$#"`
                ;;
            -g|--gridengine)
                gridengine=1
                gridengine_acl="${2}"
                shift `maxshift 2 "$#"`
                ;;
            -q|--qconf)
                qconf="${2}"
                shift `maxshift 2 "$#"`
                ;;
            *)
                break
                ;;
        esac
    done

    if [ "$#" -ne 1 ]; then
        echo "error: valargs - bad arguments!" 1>&2
        printusage
        return 1
    fi

    users_list="$1"

    if [ -z "${users_list}" ]; then
        echo "error: valargs - userslist is empty" 1>&2
        return 1
    fi
    if [ ! -f "${users_list}" ]; then
        echo "error: valargs - userslist '${users_list}' does not exists" 1>&2
        return 1
    fi
    if [ ! -r "${users_list}" ]; then
        echo "error: valargs - userslist '${users_list}' is not readable" 1>&2
        return 1
    fi
    return 0
}

chkbins () {
    # @env system
    # @env useradd
    # @env ldap
    # @env ldapadduser
    # @env gridengine
    # @env qconf
    if [ "${system}" -eq 1 ]; then
        if ! command -v "${useradd}" > /dev/null 2>&1; then
            echo "error: chkbins - ${useradd} not found" 1>&2
            return 1
        fi
    elif [ "${ldap}" -eq 1 ]; then
        if ! command -v "${ldapadduser}" > /dev/null 2>&1; then
            echo "error: chkbins - ${ldapadduser} not found" 1>&2
            return 1
        fi
    fi

    if [ "${gridengine}" -eq 1 ]; then
        if ! command -v "${qconf}" > /dev/null 2>&1; then
            echo "error: chkbins - ${qconf} not found" 1>&2
            return 1
        fi
    fi
    return 0
}

addusers_system () {
    # $1 user
    # $2 useradd args
    # @env useradd
    local user
    local args
    user="$1"
    args="$2"
    if [ -z "${user}" ]; then
        echo "error: addusers_system - user is empty or not defined" 1>&2
        return 1
    fi
    if [ -n "${args}" ]; then
        "${useradd}" ${args} "${user}"
    else
        "${useradd}" "${user}"
    fi
}

addusers_ldap () {
    # $1 user
    # $2 group
    local user
    local group
    user="$1"
    group="$2"
    if [ -z "${user}" ]; then
        echo "error: addusers_ldap - user is empty or not defined" 1>&2
        return 1
    fi
    if [ -z "${group}" ]; then
        echo "error: addusers_ldap - group is empty or not defined" 1>&2
        return 1
    fi
    "${ldapadduser}" "${user}" "${group}"
    # ldapadduser does not create the user's home directory. For some reason,
    # invoking any command or SSH'ing will create the home dir. We use the
    # below to create a home directory.. in case it did not exist
	su -c "date > /dev/null 2>&1" "${user}"
}

addusers_qconf () {
    # $1 user
    # $2 ACL
    # @env qconf
    local user
    local acl
    user="$1"
    acl="$2"
    if [ -z "${user}" ]; then
        echo "error: addusers_qconf - user is empty or not defined" 1>&2
        return 1
    fi
    if [ -z "${acl}" ]; then
        echo "error: addusers_qconf - acl is empty or not defined" 1>&2
        return 1
    fi
    # if the ACL does not exist, it will be created
	"${qconf}" -au "${user}" "${acl}"
}

run () {
    # $@
    valargs "$@"
    chkbins
    #if [ "$(id -u)" != 0 ]; then
    #    echo "error: not root"
    #    exit 1
    #fi
    while IFS= read -r user
    do
        echo "Adding ${user}"
        if [ "${system}" -eq 1 ]; then
            addusers_system "${user}" "${useradd_args}"
        elif [ "${ldap}" -eq 1 ]; then
            addusers_ldap "${user}" "${ldap_group}"
        fi
        if [ "${gridengine}" -eq 1 ]; then
            addusers_qconf "${user}" "${gridengine_acl}"
        fi
    done < "${users_list}"
}

run "$@"
