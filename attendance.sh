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

# GNU date only

timezone="${TZ:-Asia/Beirut}"
output_from_format="+%d/%m/%Y %H:%M:%S"
output_to_format="+%d/%m/%Y %H:%M:%S"
output_column_format="%D1 - %D2"
separator=","
transpose=0

usage="Infer student's attendance from logins
Usage:
    `basename "$0"` [-l STUDENTS_LIST] [-u STUDENT] [-f F1 F2] [-c COLFORMAT]
                  [-s FROM_DATE] [-e TO_DATE] [-d DURING] [-w WEEKDAY]
                  [-S separator] [-z TIMEZONE]
Options:
    -h, --help          prints this
    -l STUDENTS_LIST    Use STUDENTS_LIST as the list of students
    -u STUDENT          Do not use STUDENTS_LIST, use STUDENT
    -f F1 F2            Specify from and to date output formats.
                        F1 specifies format for from date, and
                        F2 specifies format for to date. Both formats follows
                        format used by date. See man date
                        Default is ${output_from_format} ${output_to_format}
    -c COLFORMAT        Use COLFORMAT as column display format.
                        Interpretted tokens:
                        %D1     from date, format specified in -f
                        %D2     to date, format specified in -f
                        Default is ${output_column_format}
    -s FROM_DATE -e TO_DATE
                        Report logins starting FROM_DATE until TO_DATE
                        Same format used by last, see man last
    -d DURING           Only use DURING as day time interval of the date for
                        the attendance time, e.g. -d 17:00-19:00
    -w WEEKDAY          Only use WEEKDAY as the day of the week for the
                        attendance day, e.g. -w Tuesday
    -S SEP              use SEP as the field seperator. Dfault is ${separator}
    -z TIMEZONE         Use TIMEZONE for the input/output dates.
                        Defaults to ${timezone}. See /usr/share/zoneinfo
    -T                  transpose the output, the rows will be the dates and
                        the columns will be the user(s)
Note: Some GNU/Linux distributions only keep upto 4 weeks of backlog
for /var/log/wtmp files (files used by last to check logins)
check logrotate conifg (possibly at /etc/logrotate.conf)"

printusage () {
    # @env $usage
    echo "$usage"
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

valcl () {
    # @out * list
    # @out * student
    # @out * from_date
    # @out * to_date
    # @out * during
    # @out * week_day
    while [ "$#" -gt 0 ];
    do
        case "$1" in
            -h|--help)
                printusage
                exit 0
                ;;
            -l)
                if [ -n "$student" ]; then
                    echo "error: cannot use -l option, conflicts with -u" 1>&2
                    return 1
                fi
                list="$2"
                shift `maxshift 2 "$#"`
                ;;
            -u)
                if [ -n "${list}" ]; then
                    echo "error: cannot use -u option, conflicts with -l" 1>&2
                    return 2
                fi
                student="$2"
                shift `maxshift 2 "$#"`
                ;;
            -f)
                output_from_format="$2"
                output_to_format="$3"
                shift `maxshift 3 "$#"`
                ;;
            -c)
                output_column_format="$2"
                shift `maxshift 2 "$#"`
                ;;
            -s)
                from_date="$2"
                shift `maxshift 2 "$#"`
                ;;
            -e)
                to_date="$2"
                shift `maxshift 2 "$#"`
                ;;
            -d)
                during="$2"
                shift `maxshift 2 "$#"`
                ;;
            -w)
                week_day="$2"
                shift `maxshift 2 "$#"`
                ;;
            -S)
                separator="$2"
                shift `maxshift 2 "$#"`
                ;;
            -T)
                transpose=1
                shift 1
                ;;
            -z)
                timezone="$2"
                shift `maxshift 2 "$#"`
                ;;
            *)
                echo "Unknown option '$1'"
                printusage
                exit 1
                ;;
        esac
    done
    return 0
}

chktz () {
    # @env $timezone
    if [ ! -f "/usr/share/zoneinfo/${timezone}" ]; then
        echo "error: chktz - timezone '${timezone}' is invalid" 1>&2
        return 1
    fi
}

getintervals () {
    # $1 fromdate
    # $2 todate
    # $3 weekday
    # $4 during
    local fromdate
    local todate
    local during
    local weekday
    local currentdate
    local enddate
    local timestart
    local timeend
    local intv1
    local intv2
    fromdate="$1"
    todate="$2"
    weekday="$3"
    during="$4"
    if [ -z "${fromdate}" ]; then
        echo "error: getintervals - fromdate is empty or not defined" 1>&2
        return 1
    fi
    if [ -z "${todate}" ]; then
        echo "error: getintervals - todate is empty or not defined" 1>&2
        return 1
    fi
    if ! currentdate=$(date --iso-8601=seconds -d "${fromdate}"); then
        echo "error: getintervals - from date '$fromdate' is invalid" 1>&2
        return 1
    fi
    if ! enddate=$(date --iso-8601=seconds -d "${todate}"); then
        echo "error: getintervals - to date '$todate' is invalid" 1>&2
        return 1
    fi
    if [ -z "${during}" -a -z "${weekday}" ]; then
        intv1=`TZ="${timezone}" date -d "${currentdate}" "+%Y-%m-%d %H:%M:%S"`
        intv2=`TZ="${timezone}" date -d "${enddate}" "+%Y-%m-%d %H:%M:%S"`
        printf "%s#%s\n" "${intv1}" "${intv2}"
        return 0
    fi
    if [ -n "${during}" ]; then
        timestart=$(echo "${during}" | sed -E 's/^(.*)-(.*)$/\1/g')
        timeend=$(echo "${during}" | sed -E 's/^(.*)-(.*)$/\2/g')
        if ! timestart=$(TZ="${timezone}" date -d "$timestart" "+%H:%M:%S"); then
            echo "error: getintervals - invalid during value" 1>&2
            return 1
        fi
        if ! timeend=$(TZ="${timezone}" date -d "${timeend}" "+%H:%M:%S"); then
            echo "error: getintervals - invalid during value" 1>&2
            return 1
        fi
    else
        if ! timestart="$(TZ="${timezone}" date -d "${fromdate}" "+%H:%M:%S")"; then
            echo "error: getintervals - invalid from date" 1>&2
            return 1
        fi
        timeend="23:59:59"
    fi
    case "$(echo "${weekday}" | tr '[:upper:]' '[:lower:]')"  in
        monday)
            weekday="Monday"
            ;;
        tuesday)
            weekday="Tuesday"
            ;;
        wednesday)
            weekday="Wednesday"
            ;;
        thursday)
            weekday="Thursday"
            ;;
        friday)
            weekday="Friday"
            ;;
        saturday)
            weekday="Saturday"
            ;;
        sunday)
            weekday="Sunday"
            ;;
        '')
            ;;
        *)
            echo "error: getintervals - invalid weekday '${weekday}'" 1>&2
            return 1
            ;;
    esac
    enddate="$(TZ="${timezone}" date -d "${enddate}" "+%s")"
    while [ "$(TZ="${timezone}" date -d "$currentdate" "+%s")" -le "${enddate}" ];
    do
        if [ -n "${weekday}" ]; then
            # check if currentdate is weekday, if not go to next day
            # I wish we could have used ${currentdate} next "${weekday}"
            # but did not work! Since it did not work, we are going
            # day by day and checking if we are on ${weekday}
            if [ "$(TZ="${timezone}" date -d "${currentdate}" "+%A")" != "${weekday}" ]; then
                currentdate="$(TZ="${timezone}" date -d "${currentdate} +1 day" "+%Y-%m-%d")"
                continue
            fi
        fi
        intv1=`TZ="${timezone}" date -d "${currentdate}" "+%Y-%m-%d ${timestart}"`
        intv2=`TZ="${timezone}" date -d "${currentdate}" "+%Y-%m-%d ${timeend}"`
        printf "%s#%s\n" "${intv1}" "${intv2}"
        currentdate="$(TZ="${timezone}" date -d "${currentdate} +1 day" "+%Y-%m-%d")"
    done
}

att () {
    # $1 listfile
    # $2 separator
    # $3 intvfile
    # $4 tranpose
    # $5 fromformat
    # $6 toformat
    # $7 colformat
    local sep
    local listfile
    local intvfile
    local tp
    local fromformat
    local toformat
    local colformat
    local first
    local tmpfile1
    local tmpfile2
    local tmpfile3
    listfile="$1"
    sep="$2"
    intvfile="$3"
    tp="$4"
    fromformat="$5"
    toformat="$6"
    colformat="$7"
    first=1
    if [ -z "${listfile}" ]; then
        echo "error: att - listfile is empty or not defined" 1>&2
        return 1
    fi
    if [ "${tp}" -eq 1 ]; then
        tmpfile1=`mktemp`
        tmpfile2=`mktemp`
        tmpfile3=`mktemp`
    fi
    while IFS= read -r user
    do
        if [ "${tp}" -ne 1 ]; then
            useratt "${sep}" "${user}" "${intvfile}" "${first}" "${tp}" \
                "${fromformat}" "${toformat}" "${colformat}"
        else
            useratt "${sep}" "${user}" "${intvfile}" "${first}" "${tp}" \
                "${fromformat}" "${toformat}" "${colformat}" > "${tmpfile1}"
            if [ "${first}" -ne 1 ]; then
                paste -d "${sep}" "${tmpfile2}" "${tmpfile1}" > "${tmpfile3}"
                cp "${tmpfile3}" "${tmpfile2}"
            else
                cp "${tmpfile1}" "${tmpfile2}"
            fi
        fi
        if [ "${first}" -eq 1 ]; then
            first=0
        fi
    done < "${listfile}"
    if [ "${tp}" -eq 1 ]; then
        cat "${tmpfile3}"
        rm "${tmpfile1}"
        rm "${tmpfile2}"
        rm "${tmpfile3}"
    fi
}

useratt () {
    # $1 separator
    # $2 user
    # $3 intvfile
    # $4 first
    # $5 transpose
    # $6 fromformat
    # $7 toformat
    # $8 colformat
    local user
    local intvfile
    local transpose
    local fromformat
    local toformat
    local colformat
    local first
    local wtmps
    local start
    local end
    local fstart
    local fend
    local sep
    local columns
    local row
    local rows
    sep="$1"
    user="$2"
    intvfile="$3"
    first="$4"
    tp="$5"
    fromformat="$6"
    toformat="$7"
    colformat="$8"
    if [ -z "${sep}" ]; then
        echo "error: useratt - separator is empty or not defined" 1>&2
        return 1
    fi
    if [ -z "${user}" ]; then
        echo "error: useratt - user is empty or not defined" 1>&2
        return 1
    fi
    if [ -z "${intvfile}" ]; then
        echo "error: useratt - interval file is empty or not defined" 1>&2
        return 1
    fi
    if [ -z "${first}" ]; then
        echo "error: useratt - first '${first}' is empty or not defined" 1>&2
        return 1
    elif [ "${first}" -eq 1 ]; then
        if [ -z "${fromformat}" ]; then
            echo "error: useratt - fromformat is empty or not defined" 1>&2
            return 1
        fi
        if [ -z "${toformat}" ]; then
            echo "error: useratt - toformat is empty or not defined" 1>&2
            return 1
        fi
        if [ -z "${colformat}" ]; then
            echo "error: useratt - colformat is empty or not defined" 1>&2
            return 1
        fi
        if echo "${fromformat}" | grep -Fq ','; then
            echo "error: useratt - fromformat must not contain ," 1>&2
            return 1
        fi
        if echo "${toformat}" | grep -Fq ','; then
            echo "error: useratt - toformat must not contain ," 1>&2
            return 1
        fi
    fi
    if [ -z "${transpose}" ]; then
        echo "error: useratt - transpose is empty or not defined" 1>&2
        return 1
    fi
    for wtmp in /var/log/wtmp*
    do
        [ -z "${wtmps}" ] && wtmps="-f ${wtmp}" || wtmps="${wtmps} -f ${wtmp}"
    done
    if [ "${tp}" -ne 1 ]; then
        columns="Student"
        row="${user}"
        while IFS="#" read -r start end
        do
            # Run less
            if [ "${first}" -eq 1 ]; then
                fstart=`date -d "${start}" "${fromformat}"`
                fend=`date -d "${end}" "${toformat}"`
                columns="${columns}${sep}`echo "${colformat}" \
                    | sed "s,%D1,${fstart},g;
                           s,%D2,${fend},g"`"
                #columns="${columns}, ${start} - ${end}"
            fi
            if ! TZ="${timezone}" last -s "${start}" -t "${end}" $wtmps "${user}" \
                | grep -Eq "pts/[0-9]+"; then
                row="${row}${sep}0"
            else
                row="${row}${sep}1"
            fi
        done < "${intvfile}"
        if [ "${first}" -eq 1 ]; then
            echo "${columns}"
        fi
        echo "${row}"
    else
        if [ "${first}" -eq 1 ]; then
            columns="Interval${sep}"
        fi
        columns="${columns}${user}"
        echo "${columns}"
        while IFS="#" read -r start end
        do
            if [ "${first}" -eq 1 ]; then
                fstart=`date -d "${start}" "${fromformat}"`
                fend=`date -d "${end}" "${toformat}"`
                printf "%s%s" "`echo "${colformat}" \
                    | sed "s,%D1,${fstart},g;s,%D2,${fend},g"`" "${sep}"
            fi
            if ! TZ="${timezone}" last -s "${start}" -t "${end}" $wtmps "${user}" \
                | grep -Eq "pts/[0-9]+"; then
                printf "0\n"
            else
                printf "1\n"
            fi
        done < "${intvfile}"
    fi
}

run () {
    # $@ all args
    local tmpfile
    valcl "$@"
    chktz
    tmpfile=`mktemp`
    getintervals "${from_date}" "${to_date}" "${week_day}" "${during}" \
                 > "${tmpfile}"
    if [ -n "${student}" ]; then
        useratt "${separator}" "${student}" "${tmpfile}" 1 \
            "${transpose}" "${output_from_format}" "${output_to_format}" \
            "${output_column_format}"
    elif [ -n "${list}" ]; then
        att "${list}" "${separator}" "${tmpfile}" "${transpose}" \
            "${output_from_format}" "${output_to_format}" \
            "${output_column_format}"
    fi
    rm "${tmpfile}"
}

run "$@"
