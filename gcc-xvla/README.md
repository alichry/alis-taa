# Disabling variable length array in gcc
It can be disabled by using a command-line option to the gcc command, but we want to disable it transparently (by default) so that students get that error message regarding VLA without specifying any additional clopts. 
  
It's done by modifying the specs file, during solution hunting I could not find adequate resources on where to place the file.
I remember that specs file is no longer created by default in newer versions of gcc and it has to be generated using gcc.
  
To generate the specs file:  

```
gcc -dumpspecs
```

To check if gcc is using the specsfile  

```
ali@somewhere:/usr/lib/gcc/x86_64-linux-gnu/7$ gcc -v
Reading specs from /usr/lib/gcc/x86_64-linux-gnu/7/specs
....
gcc driver version 7.5.0 (Ubuntu 7.5.0-3ubuntu1~18.04) executing gcc version 7.4.0
```

The important part of the specs file to modify  
```
*cc1:
-Werror=vla -Wall ....
```

My specs file is placed in /usr/lib/gcc/x86_64-linux-gnu/7
