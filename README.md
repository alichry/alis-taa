# Ali's Teaching Assistant Assistant
I've developed of some shell tools to aid in automating some processes one might undertake in managing programming lab's handouts, submissions, grading and attendance.  Initially, these tools were not generalized. The shell scripts were modified to be generic and reusuable in the hope of being useful to the public. 

## Adding users
Suppose you have a list of students where each entry (username) is written on a newline. Use `addusers.sh` to add users to your system, LDAP and/or Grid Engine.
  
```
Usage:
    addusers.sh [-s [-u USERADD_ARGS] | -l GROUP [-a LDAP_ADDUSER]]
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
                        to ldapadduser
    -g ACL, --grid-engine ACL
                        Add user to grid engine access control list ACL using
                        qconf
    -q QCONF, --qconf QCONF
                        Set qconf binary path to QCONF. Defaults to qconf
Where:
    userslist           file containing a list of newline separated entries
                        of usernames to add
```

## Attendance
Suppose students login to a linux system during lab time. The `last` program prints login entries, we used that to infer student's attendance during lab time.  
Usually, a lab will be scheduled during a specific weekday and during some time interval. `attendance.sh` takes input date interval as well as the lab scheduled day and time and will return a list of logins during that dateinterval during the specified lab time. This is helpful since `last` can print entries between a datetime interval but it is not flexible enough to check logins on a specific daytime of the week during the specified datetime interval.  

```
Infer student's attendance from logins
Usage:
    attendance.sh [-l STUDENTS_LIST] [-u STUDENT] [-f F1 F2] [-c COLFORMAT]
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
                        Default is +%d/%m/%Y %H:%M:%S +%d/%m/%Y %H:%M:%S
    -c COLFORMAT        Use COLFORMAT as column display format.
                        Interpretted tokens:
                        %D1     from date, format specified in -f
                        %D2     to date, format specified in -f
                        Default is %D1 - %D2
    -s FROM_DATE -e TO_DATE
                        Report logins starting FROM_DATE until TO_DATE
                        Same format used by last, see man last
    -d DURING           Only use DURING as day time interval of the date for
                        the attendance time, e.g. -d 17:00-19:00
    -w WEEKDAY          Only use WEEKDAY as the day of the week for the
                        attendance day, e.g. -w Tuesday
    -S SEP              use SEP as the field seperator. Dfault is ,
    -z TIMEZONE         Use TIMEZONE for the input/output dates.
                        Defaults to Asia/Beirut. See /usr/share/zoneinfo
    -T                  transpose the output, the rows will be the dates and
                        the columns will be the user(s)
Note: Some GNU/Linux distributions only keep upto 4 weeks of backlog
for /var/log/wtmp files (files used by last to check logins)
check logrotate conifg (possibly at /etc/logrotate.conf)
```
## Broadcasting and gathering files
Suppose you want to distribute or gather files (inputs, handouts..) to or from students. You can use `bcast.sh` and provide it with a list of students, src and dst values. `bcast.sh` wraps cp by allowing the user to specify src or dst value with a custom variable `$user` that will be interpretted as the current username in the student list. Additionally, `bcast.sh` chowns the dst files to give permission for the student to read it.

```
Usage:
    bcast.sh [-n] [-g] [-f|-i] [-r] [-u NAME] [-o OWNER] userslist src [src2 .. srcn] dst
Options:
    -h, --help          print this
    -n, --dry_run       Do not modify anything, only print commands that will be
                        executed
    -g, --gather        will gather the files instead of bcasting it. This will
                        allow evaluation of $user in src
    -f, --force         force overwriting files that exists. This is not
                        default behavior
    -i, --interactive   prompt before overwriting a file that alreadty exists.
                        This is not default behavior
    -r, --recursive     recursively copy files if src is a directory. Exact
                        cp -r behavior occurs in this case. See man cp
    -u NAME, --user_variable NAME
                        use NAME as the user variable name. Defaults to
                        $user
    -o OWNER, --owner OWNER
                        Give OWNER ownership of dst. if dst contains
                        $user then the default owner is $user
                        of the current username in userslist, otherwise default
                        owner is the caller of bcast.sh (i.e. ali)
Where:
    userslist           list of usernames (seperated by new line).
    src                 The file we want to bcast or gather. If more than one
                        source files are passed, dst is expected to be a
                        directory.
    dst                 The destination file or directory that will hold the
                        copied file(s). Any occurrences of $user will
                        cause bcast.sh to evaluate it to the current
                        username in the userslist
Note:
    Usually ran as root
```
## Problem submission check
Suppose students must write their code in an instructed directory (e.g. /home/$user/labs/1/problem1.c). `chksub.sh` can help students in determining whether they have a proper submission. The Teaching Assistant must define a small JSON configuration file that contains these mappings.  
Sample JSON config file  

```
{
	"labs": {
		"1": {
			"problems": 2,
			"paths": [
				"/home/$user/labs/1/problem1.c",
				"/home/$user/labs/1/problem2.c"
			]
		},
		"2": {
			"problems": 1,
			"paths": [
				"/home/$user/labs/2/problem1.c"
			]
		}
	}
}
```
You can also specify a different `user_variable` other than `$user` by defining a root key `user_variable` and specifying your value, e.g.  

```
{
	"user_variable": "$dummy"
	"labs": {
		"1": {
			"problems": 2,
			"paths": [
				"/home/$dummy/labs/1/problem1.c",
				"/home/$dummy/labs/1/problem2.c"
			]
		},
		"2": {
			"problems": 1,
			"paths": [
				"/home/$dummy/labs/2/problem1.c"
			]
		}
	}
}
```
 This would be helpful if, for some strange reason, some of your paths contain the value `$user`.  
You should place `chksub.sh` somewhere in `$PATH` (e.g. /usr/local/bin/chksub) to make it accessible.  
`chksub.sh` takes lab id as argument and prints whether the student has a valid submission. Additionally, `chksub.sh` requires `jq` to be installed to parse the JSON file.

```
Lab submission validity check usage:
    chksub.sh [-c CONFIG] labid
Options:
    -h, --help          print this
    -c CONFIG, --config CONFIG
                        use CONFIG as the submission configuaration. Default is
                        /etc/chksub.json
Where:
    labid               The lab # that you want to check your submissions for
```

## Grading submissions
Dealing with a significant amount of submissions can be exhaustive. I've developed some tools to generate reports before processing submissions manually. First off, we use `bcast.sh` to gather submissions, or more precisely the corresponding lab directory (e.g. /home/$user/labs/1). The Resulting directory will contain a list of students as directory names where each student's submission is inside it. Secondly, we use some magical unpublished tool `probchk.sh` that will iteratore over the gathered driectories and tries to find problem1.c the equivalent of problem id, compiles it and reporting the results in CSV format. The reason `probchk.sh` is not yet published because I've still not yet generalized it. It is currently the result of a clueless experimentation of automating the grading procedure with an unknown halting states in mind.

The header (columns) of the CSV table will be 
`Lab,Username,Problem,Exists,Compilable,Inspected,Runnable[,...]`  

Suppose we have that lab report ready, we can use `probgrd.sh` to assign a grade to each problem submission by consulting the column values, e.g. if a submission has compilable as 1, then add 40 points. `probgrd.sh` compiles many problem reports into one output file with the addition of the added `Grade` column. To use `probgrd.sh`, first copy `probgrd.sh.dist` and modify the part in `partgrade` to reflect your current grading criteria.

```
Problem grader usage:
    probgrd-447.sh grades.out problem1.in [problem2.in [...]]
```  

Finally, we use `labgrd.sh` to compute the average of each lab and print the final grades table.

```
Lab grader usage:
    labgrd.sh probgrades.in
Note: probgrades.in should be sorted (probgrd.sh sorts it)
```
## Helping
It would be nice if you could star my repository, I'm already in love with stars.
## TODO
*	Attendance:
	- Add option to specify directory path of wtmp files (default is /var/log)
* 	Rewrite probgrader.php -- probchk.sh
*  Allow user to specify the separator instead of the default , (comma) in grading tools.
*  Add Moss helper (aids in only submitting compilable files)