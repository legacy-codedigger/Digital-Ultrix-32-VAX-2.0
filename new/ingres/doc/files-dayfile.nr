.\"		@(#)files-dayfile.nr	1.2	(ULTRIX)	2/1/85
.th DAYFILE FILES
.sh NAME
\&.../files/dayfile7 \- \*(II login message
.sh DESCRIPTION
The contents of the dayfile
reflect
user information of general system interest, and is
more or less analogous to
.bd /etc/motd
in \*(UU.
The file has no set
format;
it is simply copied at login time to the standard
output device by the monitor if the
.bd \-s
or
.bd \-d
options
have not been requested.
Moreover the dayfile is not mandatory, and
its absence will not generate errors of any sort;
the same is true when the
dayfile is present but not readable.
