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

usage="Lab grader usage:
    `basename "$0"` probgrades.in
Note: probgrades.in should be sorted"

printusage () {
    echo "${usage}"
}

valargs () {
    # @out grades_file
    if [ "$#" -eq 0 ]; then
        echo "error: valargs - missig probgrades argument" 1>&2
        printusage
        return 1
    fi
    if [ "$1" = "-h" -o "$1" = "--help" ]; then
        printusage
        printusage
        exit 0
    fi
    grades_file="$1"
}

labgrd () {
    # $1 gradesfile
    local gradesfile
    gradesfile="$1"
    if [ -z "${gradesfile}" ]; then
        echo "error: problem grades argument is empty or not defined"
        exit 1
    fi
    if [ ! -f "${gradesfile}" ]; then
        echo "error: grades file '${gradesfile}' does not exiss!"
        exit 2
    fi
    minlab="$(tail -n +2 "${gradesfile}" | cut -d , -f 1 | uniq | sort -n | head -n 1)"
    maxlab="$(tail -n +2 "${gradesfile}" | cut -d , -f 1 | uniq | sort -nr | head -n 1)"
    labcount=$((maxlab - minlab + 1))
    seq="$(seq -s " " "${minlab}" "${maxlab}")"

    printf "Student,"

    for lab in ${seq}
    do
        printf "Lab $lab,"
    done

    printf "Total\n"

    # loop through students
    # gradesfile should be sorted already
    tail -n +2 "${gradesfile}" | cut -d , -f 2 | uniq | while IFS= read -r student
    do
        labgrades=""
        totalgrade=0
        # loop through labs
        for lab in $(seq -s " " "${minlab}" "${maxlab}")
        do
            grade=`awk -F , -v lab="${lab}" -v student="${student}" \
                '$1 == lab && $2 == student {sum+=$NF;count++}; END{print sum/count};' \
                "${gradesfile}"`
            [ -z "${labgrades}" ] && labgrades="${grade}" \
                || labgrades="${labgrades},${grade}"
            grade="$(echo "scale=2;${grade}/1" | bc -l)"
            totalgrade="$(echo "scale=2;${totalgrade}+${grade}" | bc -l)"
        done
        totalgrade="$(echo "scale=2;${totalgrade}/${labcount}" | bc -l)"
        printf "%s\n" "${student},${labgrades},${totalgrade}"
    done
}

run () {
    valargs "$@"
    labgrd "${grades_file}"
}

run "$@"
