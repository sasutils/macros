%macro fread
/*----------------------------------------------------------------------
Reads file using only macro code.
----------------------------------------------------------------------*/
(file      /* Fileref or path name */
,mode=1    /* Operation Mode */
   /* Mode=1 returns macro variable array (requires %UNQUOTE()) */
   /* Mode=2 puts file contents to SAS log */
   /* Mode=3 returns file contents as macro result */
,eol=|     /* Characters to output after each line when MODE=3 */
,lineno=0  /* Include line numbers when Mode=2? 0=No 1=Yes */
);

/*----------------------------------------------------------------------
Read a file to (mode=1) local macro variables, (mode=2) the log or
(mode=3) the macro function result. Values will be macro quoted.

MODE=1
------
This will return the lines in the form of a series of %LET statements
to create an array of macro variables (N,W1,W2,....).  You will need
to wrap the %FREAD() call inside of %UNQUOTE() to have the macro
variables created in the calling environment.

  %unquote(%fred(config.dat))
  %do i=1 %to &n ;
    %if (&&w&i = YES) %then %let found=1;
  %end;

MODE=2
------
Write the file to the SAS log using %PUT statements.  Set LINENO=1 to
have the lines prefixed with 5 digit line numbers.

MODE=3
------
Return the file as the result of the macro call. You can use the EOL=
parameter to insert a delimiter string between the lines.


Note files larger than macro variable limit (64K bytes) will not work
with MODE=1 or MODE=3.

-----------------------------------------------------------------------
This macro was adopted from code developed by Tom Hoffman.

History:

07APR00 TRHoffman Creation
01MAY00 TRHoffman Cleared fileref. Protected length statement against
                  unmatched parentheses in input file.
03MAY00 TRHoffman Corrected invalid file close.
08MAY00 TRHoffman Added MODE parameter.
2016-08-12 abernt Removed the code that was stripping macro triggers.
                  Replaced with QUOTE()/DEQUOTE() calls.
                  Added LINENO and EOL parameters.
----------------------------------------------------------------------*/
%local filerc rc fileref j fid text n;

%*----------------------------------------------------------------------
Assign fileref when physical file.
-----------------------------------------------------------------------;
%let filerc = 1;
%let fileref = _fread;
%if %sysfunc(fileexist(&file)) %then
  %let filerc = %sysfunc(filename(fileref,&file))
;
%else %let fileref = &file;

%*----------------------------------------------------------------------
Initialize line block counter.
-----------------------------------------------------------------------;
%let n = 0;

%*----------------------------------------------------------------------
Open file for streaming input access.
-----------------------------------------------------------------------;
%let fid = %sysfunc(fopen(&fileref,s));

%if (&fid > 0) %then %do;
%*----------------------------------------------------------------------
Read through file and process each line.
-----------------------------------------------------------------------;
  %do %while(%sysfunc(fread(&fid)) = 0);
    %let n = %eval(&n + 1);
    %let rc = %sysfunc(fget(&fid,text,32767));

%*----------------------------------------------------------------------
MODE=1 Store the quoted value into local macro variable.
-----------------------------------------------------------------------;
    %if (&mode = 1) %then %do;
      %local w&n;
      %let w&n = %sysfunc(quote(%superq(text),%str(%')));
    %end;

%*----------------------------------------------------------------------
MODE=2 Write line to LOG with optional line numbers.
-----------------------------------------------------------------------;
    %else %if (&mode = 2) %then %do;
      %if ^(&lineno) %then %put %superq(text) ;
      %else %put %syseval(putn(&n,Z5)) %superq(text) ;
    %end;

%*----------------------------------------------------------------------
MODE=3 Return the line with optional end of line string.
-----------------------------------------------------------------------;
    %else %do;%superq(text)&eol.%end;

  %end;
  %let rc = %sysfunc(fclose(&fid));
%end;

%*----------------------------------------------------------------------
Clear fileref when assigned by macro,
-----------------------------------------------------------------------;
%if ^(&filerc) %then %let rc = %sysfunc(filename(fileref));

%if (&mode = 1) %then %do;
%*----------------------------------------------------------------------
Create quoted %let statements to recreate the macro variables.

Use %QSYSFUNC(DEQUOTE()) to remove the quoting added above.
-----------------------------------------------------------------------;
  %*;%nrstr(%let )n=&n%str(;)
  %do j = 1 %to &n;
    %*;%nrstr(%let )w&j=%nrstr(%qsysfunc)(dequote(&&w&j))%str(;)%*;
  %end;
%end;

%mend fread;
