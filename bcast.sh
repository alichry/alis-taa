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
dry_run=0
gather=0
cp_args="-n"
user_variable="\$user"
chown_args=""
custom_owner=""

usage="Usage:
    ${script_name} [-n] [-g] [-f|-i] [-r] [-u NAME] [-o OWNER] userslist src [src2 .. srcn] dst
Options:
    -h, --help          print this
    -n, --dry_run       Do not modify anything, only print commands that will be
                        executed
    -g, --gather        will gather the files instead of bcasting it. This will
                        allow evaluation of ${user_variable} in src
    -f, --force         force overwriting files that exists. This is not
                        default behavior
    -i, --interactive   prompt before overwriting a file that alreadty exists.
                        This is not default behavior
    -r, --recursive     recursively copy files if src is a directory. Exact
                        cp -r behavior occurs in this case. See man cp
    -u NAME, --user_variable NAME
                        use NAME as the user variable name. Defaults to
                        ${user_variable}
    -o OWNER, --owner OWNER
                        Give OWNER ownership of dst. if dst contains
                        ${user_variable} then the default owner is ${user_variable}
                        of the current username in userslist, otherwise default
                        owner is the caller of ${script_name} (i.e. ${USER})
Where:
    userslist           list of usernames (seperated by new line).
    src                 The file we want to bcast or gather. If more than one
                        source files are passed, dst is expected to be a
                        directory.
    dst                 The destination file or directory that will hold the
                        copied file(s). Any occurrences of ${user_variable} will
                        cause ${script_name} to evaluate it to the current
                        username in the userslist
Note:
    Usually ran as root"

printusage () {
    echo "${usage}"
}

quote () {
    # from http://www.etalabs.net/sh_tricks.html thanks!
    printf %s\\n "$1" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/" ;
}

xexec () {
    echo "$@"
    "$@"
    return $?
}

valargs () {
    # $@ - cl args
    # @out users_list
    # @out * user_variable
    # @out * custom_owner
    # @out * cp_args
    # @out src
    # @out dest
    local interactive
    local force
    local recursive
    interactive=0
    force=0
    recursive=0

    while [ "$#" -gt 0 ];
    do
        case "$1" in
            -h|--help)
                printusage
                exit 0
                ;;
            -n|--dry_run)
                dry_run=1
                shift 1
                ;;
            -g|--gather)
                gather=1
                shift 1
                ;;
            -f|--force)
                force=1
                shift 1
                ;;
            -i|--interactive)
                interactive=1
                shift 1
                ;;
            -r|--recursive)
                recursive=1
                shift 1
                ;;
            -u|--user_variable)
                if [ "$#" -eq 1 ]; then
                    echo "error: valargs - missing user variable value" 1>&2
                    return 1
                fi
                user_variable="${2}"
                shift 2
                ;;
            -o|--owner)
                if [ "$#" -eq 1 ]; then
                    echo "error: valargs - missing owner value" 1>&2
                    return 1
                fi
                custom_owner="${2}"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done

    if [ "${interactive}" -eq 1 -a "${force}" -eq 1 ]; then
        echo "error: valargs - arg conflict between -f and -i"
        return 1
    fi
    if [ "${interactive}" -eq 1 ]; then
        cp_args="-i"
    fi
    if [ "${force}" -eq 1 ]; then
        cp_args="-f"
    fi
    if [ "${recursive}" -eq 1 ]; then
        cp_args="${cp_args} -r"
        chown_args="-R"
    fi

    if [ "$#" -lt 3 ]; then
        echo "Error, need more arguments" 1>&2
        printusage
        return 1
    fi
    users_list="${1}"
    shift 1
    while [ "$#" -gt 1 ];
    do
        # While there exists at least 2 args..
        # eat one for the src
        file="$(quote "${1}")"
        [ -n "${src}" ] && file=" ${file}"
        src="${src}${file}"
        shift 1
    done
    dst="$(quote "${1}")"

    if [ -z "${users_list}" ]; then
        echo "Error: chkargs - userslist is not defined or empty" 1>&2
        return 1
    fi
    if [ -z "${src}" ]; then
        echo "Error: chkargs - src is not defined or emoty" 1>&2
        return 1
    fi
    if [ -z "${dst}" ]; then
        echo "Error: chkargs - dst is not define dor empty" 1>&2
        return 1
    fi
    if [ ! -f "${users_list}" ]; then
        echo "Error: chkargs - userslist is not a file" 1>&2
        return 1
    fi
    if [ ! -r "${users_list}" ]; then
        echo "Error: chkargs - userslist is not readable" 1>&2
        return 1
    fi
}

confirm () {
    read -p "$1" yn
    case "${yn}" in
        y|Y)
            return 0
            ;;
        *)
            echo "Ignoring, bye" 1>&2
            return 1
            ;;
    esac
}

run () {
    # $@ cl args
    local header
    valargs "$@"

    header='#!/bin/sh
set -Ee
trap err_trap ERR
trap exit_trap EXIT
failed=0
err_trap () {
    local status=$?
    failed=1
    echo "Error: an executed command failed with a non-zero status code (${status})" 1>&2
}
exit_trap () {
    if [ "${failed}" -eq 0 ]; then
        echo "All commands executed successfully!"
    fi
}'
    shfile=`mktemp`
    echo "${header}" > "${shfile}"
    # cp
    echo 'echo "Copying files..."' >> "${shfile}"
    while IFS= read -r user
    do
        if [ "${gather}" -ne 1 ]; then
            srcfull="${src}"
        else
            srcfull=`echo "${src}" | sed "s/${user_variable}/${user}/g"`
        fi
        dstfull=`echo "${dst}" | sed "s/${user_variable}/${user}/g"`
        echo "cp -v ${cp_args} ${srcfull} ${dstfull}" >> "${shfile}"
    done < "${users_list}"

    # chown
    echo 'echo "Chowning files..."' >> "${shfile}"

    if ! echo "${dst}" | grep -Fq "${user_variable}"
    then
        owner="${custom_owner:-${USER}}"
        echo "chown -v ${chown_args} ${owner} ${dst}" >> "${shfile}"
    else
        while IFS= read -r user
        do
            owner="${custom_owner:-${user}}"
            dstfull=`echo "${dst}" | sed "s/${user_variable}/${user}/g"`
            if [ -n "${chown_args}" ]; then
                echo "chown -v ${chown_args} ${owner} ${dstfull}" >> "${shfile}"
            else
                echo "chown -v ${owner} ${dstfull}" >> "${shfile}"
            fi
        done < "${users_list}"
    fi

    if [ "${dry_run}" -eq 1 ]; then
        cat "${shfile}"
        return 0
    fi

    sh "${shfile}"
    return $?
}

run "$@"
