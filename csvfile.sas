%macro csvfile
/*----------------------------------------------------------------------
Write SAS dataset as CSV file.
----------------------------------------------------------------------*/
(dataset     /* Dataset to write to CSV file. DSNoptions are allowed. */
,outfile=    /* Fileref or physical filename. (Def uses dataset name) */
,varlist=    /* Variable names to include. Variable lists are allowed */
,dlm=        /* Use single character, 2 digit hexcode, a keyword  */
             /* (SPACE COMMA TAB PIPE) or quoted string. (Def=comma) */
,names=1     /* Include header row in output file? */
,label=0     /* Use LABEL in place of NAME in header row? */
);
/*----------------------------------------------------------------------
Write SAS dataset as CSV file.

If DATASET is not specified then it will use &SYSLAST. You can add
dataset options (such as KEEP=, DROP= and OBS=) to the DATASET
parameter.

If OUTFILE is not specified then name will be built by adding a csv
suffix to the membername of the input dataset.  If the value supplied is
a fileref then it will write to that fileref. Otherwise if &OUTFILE is
not quoted then quotes are added so it can be used in the FILE
statement.

VARLIST is a space delimited list of variable names to output. If you
do not specify then _ALL_ variables are used. You can use variable lists
such as PROC1-PROC10, a--c, prefix: in the VARLIST parameter.  You can
use the VARLIST parameter to control the order of the columns in the
output.

If you just want to limit the variables but not change the order they
are written then use the KEEP= dataset option on the DATASET parameter.

The DLM option can be any single character, one of the supported keywords
(SPACE COMMA TAB PIPE), a two digit hexcode, or a quoted string.

Example:
  * write last created dataset to a tab delimited file. ;
  %csvfile(dlm=tab);

  * Write first 50 observations of csv file. ;
  %csvfile(mydata(obs=50),outfile=sample.csv);

  * Write selected variables to pipe delimited file. ;
  %csvfile(dlm=pipe,varlist=id diag1-diag5 proc1-proc5);

----------------------------------------------------------------------*/
%local previous parmerr rc addquote dsn dsnopts dlmq;
%let parmerr=0;

%*----------------------------------------------------------------------
Retrieve &SYSLAST value to use as default and save so can reset it.
-----------------------------------------------------------------------;
%let previous=&syslast;

*----------------------------------------------------------------------;
* Make sure delimiter value is quoted, support keywords and hex codes.;
*----------------------------------------------------------------------;
data _null_;
  length dlm $200;
  dlm=coalescec(left(symget('DLM')),',');
  if upcase(dlm)='SPACE' then dlm=' ';
  else if upcase(dlm)='TAB' then dlm='09';
  else if upcase(dlm)='COMMA' then dlm=',';
  else if upcase(dlm)='PIPE' then dlm='|';
  if length(dlm)=1 then dlm=quote(trim(dlm));
  else if length(dlm)=2 and not notxdigit(trim(dlm)) then
     dlm=quote(trim(dlm))||'x'
  ;
  else if 1 ^=indexc(dlm,'"',"'") then stop;
  call symputx('DLMQ',dlm);
run;
%if (NOT %length(&dlmq)) %then %do;
  %put ERROR: DLM value of %superq(dlm) not valid.;
  %let parmerr=1;
%end;

%*----------------------------------------------------------------------
Set default values for DATASET name.
When _NULL_ set to "_NULL_" so that OPEN() will fail.
-----------------------------------------------------------------------;
%if %bquote(&dataset)= %then %let dataset=&previous;
%if %qupcase(&dataset)=_NULL_ %then %let dataset="_NULL_";

%*----------------------------------------------------------------------
Test if dataset can be opened.
-----------------------------------------------------------------------;
%let rc=%sysfunc(open(&dataset,i));
%if &rc %then %let rc=%sysfunc(close(&rc));
%else %do;
  %put ERROR: Cannot open &dataset.. ;
  %let parmerr=1;
%end;

%if (&parmerr) %then %goto quit;

%*----------------------------------------------------------------------
Split DATASET into DSN and DSNOPTS
-----------------------------------------------------------------------;
%let dsn=%scan(&dataset,1,());
%let dsnopts=%substr(&dataset%str( ),%length(&dsn)+1);
%if %length(&dsnopts)>1 %then
  %let dsnopts=%substr(&dsnopts,2,%length(&dsnopts)-2)
;

%*----------------------------------------------------------------------
Make sure that OUTFILE parameter is in proper form for FILE statement.

- Default to membername with .csv suffix
- Add quotes unless name starts with a quote or is a valid fileref.
-----------------------------------------------------------------------;
%let addquote=1;
%if %bquote(&outfile)= %then
  %let outfile=%sysfunc(lowcase(%scan(&dsn,-1,.))).csv
;
%else %if 1=%sysfunc(indexc(&outfile,'"')) %then %let addquote=0;
%else %if %length(&outfile) <= 8 and %sysfunc(nvalid(&outfile)) %then
  %if %sysfunc(fileref(&outfile))<=0 %then %let addquote=0
;
%if &addquote %then %let outfile=%sysfunc(quote(&outfile));

%*----------------------------------------------------------------------
Set default values for VARLIST parameter.
-----------------------------------------------------------------------;
%if %bquote(&varlist)= %then %let varlist=_all_;

*----------------------------------------------------------------------;
* Generate list of variable names ;
*----------------------------------------------------------------------;
proc transpose data=&dsn(&dsnopts obs=0) ;
  var &varlist;
run;

%if (&syserr) %then %do;
%*----------------------------------------------------------------------
When PROC TRANSPOSE has trouble then generate message and skip writing.
-----------------------------------------------------------------------;
  %put ERROR: Unable to generate variable names. &=varlist ;
  %let parmerr=1;
%end;
%else %do;
*----------------------------------------------------------------------;
* Write header row ;
*----------------------------------------------------------------------;
data _null_;
  file &outfile dlm=&dlmq dsd lrecl=1000000 ;
%if (&names) %then %do;
  length _name_ _label_ $255 ;
  array _ _name_ _label_;
  set &syslast end=eof;
%if (&label) %then %do;
  _name_ = coalescec(_label_,_name_);
%end;
  put _name_ @;
  if eof then put;
%end;
run;

*----------------------------------------------------------------------;
* Write data rows ;
*----------------------------------------------------------------------;
data _null_;
  set &dsn(&dsnopts);
  file &outfile mod dlm=&dlmq dsd lrecl=1000000 ;
  put (&varlist) (+0);
run;
%end;

*----------------------------------------------------------------------;
* Remove the variable names dataset. ;
*----------------------------------------------------------------------;
proc delete data=&syslast ;
run;

%quit:
%*----------------------------------------------------------------------
Restore &SYSLAST setting.
-----------------------------------------------------------------------;
%let syslast=&previous;
%let sysrc=&parmerr;

%mend csvfile;
