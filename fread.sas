%macro fread
/*----------------------------------------------------------------------
Reads file using only macro code.
----------------------------------------------------------------------*/
(file      /* Fileref or path name */
,mode=3    /* Operation Mode */
   /* Mode=1 returns macro variable array (requires %UNQUOTE()) */
   /* Mode=2 puts file contents to SAS log */
   /* Mode=3 returns file contents as macro result */
,eol=|     /* Characters to output after each line when MODE=3 */
,lineno=0  /* Include line numbers when Mode=2? 0=No 1=Yes */
);

/*----------------------------------------------------------------------
Read a file. The resulting values will be macro quoted.

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
                  Added MODE=4 and EOL= parameter.
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
Open file for streaming input access.
-----------------------------------------------------------------------;
%let fid = %sysfunc(fopen(&fileref,s));

%*----------------------------------------------------------------------
Initialize line block counter.
-----------------------------------------------------------------------;
%let n = 0;

%*----------------------------------------------------------------------
Read through file and process each line.
-----------------------------------------------------------------------;
%if (&fid > 0) %then %do;
  %do %while(%sysfunc(fread(&fid)) = 0);
    %let n = %eval(&n + 1);
    %let rc = %sysfunc(fget(&fid,text,32767));
    %if (&mode = 1) %then %do;
      %local w&n;
      %let w&n = %superq(text) ;
    %end;
    %else %if (&mode = 2) %then %do;
      %if ^(&lineno) %then %put %superq(text) ;
      %else %put %syseval(putn(&n,Z5)) %superq(text) ;
    %end;
    %else %do;%superq(text)&eol.%end;
  %end;
  %let rc = %sysfunc(fclose(&fid));
%end;

%*----------------------------------------------------------------------
Clear fileref when assigned by macro,
-----------------------------------------------------------------------;
%if ^(&filerc) %then %let rc = %sysfunc(filename(fileref));

%*----------------------------------------------------------------------
Create quoted %let statements to be used by calling program.

Use QUOTE() and DEQUOTE() functions to allow passing of values that
might be macro triggers.
-----------------------------------------------------------------------;
%if (&mode = 1) %then %do;
  %*;%nrstr(%let )n=&n%str(;)
  %do j = 1 %to &n;
    %*;%nrstr(%let )w&j=%nrstr(%qsysfunc)(dequote(%*;
    %*;%sysfunc(quote(%superq(w&j),%str(%')))))%str(;)%*;
  %end;
%end;

%mend fread;
