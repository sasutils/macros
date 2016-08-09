%macro direxist
/*----------------------------------------------------------------------
Test if directory exists
----------------------------------------------------------------------*/
(path    /* Name of directory to test for existance */
);
/*----------------------------------------------------------------------
Test if directory exists. Returns value 1 or 0.
 1 - Directory exists
 0 - Directory does not exist

Global macro variable SYSRC will be set to 1 when a file is found
instead of a directory.

----------------------------------------------------------------------*/
%local return rc did fileref;
%*----------------------------------------------------------------------
Set up return values as normal failure to find path.
-----------------------------------------------------------------------;
%let return=0;
%let sysrc=0;

%*----------------------------------------------------------------------
If path is not specified or does not exist then return normal failure.
-----------------------------------------------------------------------;
%if (%bquote(&path) = ) %then %goto quit;
%if ^%sysfunc(fileexist(&path)) %then %goto quit;

%*----------------------------------------------------------------------
Try to open it using DOPEN function.
Return 1 if it can be opened.
Otherwise set SYSRC=1 to mean that PATH exists but is not a directory.
-----------------------------------------------------------------------;
%if (0=%sysfunc(filename(fileref,&path))) %then %do;
  %let did=%sysfunc(dopen(&fileref));
  %if (&did) %then %do;
    %let return=1;
    %let rc=%sysfunc(dclose(&did));
  %end;
  %else %let sysrc=1;
  %let rc=%sysfunc(filename(fileref));
%end;

%quit:
%*----------------------------------------------------------------------
Return the value as the result of the macro.
-----------------------------------------------------------------------;
&return
%mend;
