%macro curdir
/*----------------------------------------------------------------------
Returns (optionally changes) the current SAS directory physical name
----------------------------------------------------------------------*/
(curdir    /* Optional new current directory */
)
;
/*----------------------------------------------------------------------
Usage:

When a path is provided it will first change the current directory to
that directory. It returns the current SAS directory physical name,
after any optional change.

%put %curdir is the current directory.;
%put %curdir(~/sas) is the NEW current directory.;
%let here=%curdir;
%put Changed current directory to its parent directory %curdir(..);
------------------------------------------------------------------------
Notes:

It will open a fileref to find the current directory. Using that method
will not write a message to the log.

But when you want to change directories it will call the DLGCDIR()
function which will always write a message to the log.

The macro variable SYSRC will be set. 0 means success and any other
value is the error code from DLGCDIR() function call.

Based on code from Tom Hoffman.
-----------------------------------------------------------------------
History:

11MAR99 TRHoffman Creation - with help from Tom Abernathy.
06DEC00 TRHoffman Used . notation to reference current directory as
                  suggested by Fan Zhou.
19MAR2023 abernt Added option to change the directory using DLGCDIR().
----------------------------------------------------------------------*/
%local fr rc ;

%*---------------------------------------------------------------------
Set the SYSRC macro variable to default as success
----------------------------------------------------------------------;
%if not %symexist(sysrc) %then %global sysrc;
%let sysrc=0;

%*---------------------------------------------------------------------
When a path is provided use DLGCDIR() to change current directory.
Pass the return code to SYSRC macro variable.
----------------------------------------------------------------------;
%if %length(&curdir) %then %let sysrc=%sysfunc(dlgcdir(&curdir));

%*---------------------------------------------------------------------
Open a fileref pointing at the current directory and get its path.
----------------------------------------------------------------------;
%let rc = %sysfunc(filename(fr,.));
%let curdir = %sysfunc(pathname(&fr));
%let rc = %sysfunc(filename(fr));

%*---------------------------------------------------------------------
Return the current directory as the output of the macro.
----------------------------------------------------------------------;
&curdir

%mend curdir;
