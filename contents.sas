%macro contents
/*----------------------------------------------------------------------------
Use data step and function calls to gather contents information on a dataset.
-----------------------------------------------------------------------------*/
(data    /* Name of dataset to inspect (default=&syslast) */
,out     /* Name of dataset to store results (default=DATAnn) */
,append=0 /* If &OUT exists then append to it */
);
/*----------------------------------------------------------------------------
Creates a CONTENTS dataset using ATTR/ATTRC/VARxxx function calls.

The resulting dataset has a combination of the metadata available from
PROC CONTENTS and DICTIONARY.COLUMNS.

%CONTENTS() can support dataset options. Such as RENAME= and WHERE=.
If you DROP a variable that is not at the end there will be a note in
the log.

The NOBS value does not consider values of FIRSTOBS= or OBS= dataset options
so the result is that it will be an overcount if those options are used.

Using WHERE= option could result in it taking a long time as the ATTRN()
function call will query the data to count the number of observations.

These variablee either appear in only one of PROC CONTENTS or
DICTIONARY.COLUMNS or they have the same definition in both:

 LIBNAME, MEMNAME, MEMLABEL, NVAR, NOBS, MEMTYPE, TYPEMEM, CRDATE, MODATE
 VARNUM, NAME, LENGTH, LABEL, FORMATL, FORMATD, INFORML, INFORMD

These variables use the DICTIONARY.COLUMNS definition:
 TYPE is character: num/char (for numeric version see TYPEN)
 FORMAT has the full format specification (not just the name);
 INFORMAT has the full informat specification (not just the name);

These variables are unique to %CONTENTS() output:
 FORMATN has format name (like FORMAT in PROC CONTENTS output)
 INFORMN has informat name (like INFORMAT in PROC CONTENTS output)
 TYPEN has variable type as a numeric: 1/2 (like TYPE in PROC CONTENTS output)
 TYPEF is the category returned by the 'cat' property of FMTINFO() function.
   Example values: num/char/date/datetime/time/curr/binary/UNKNOWN

-----------------------------------------------------------------------------*/
%local did ;
%*----------------------------------------------------------------------------
Default DATA to &SYSLAST and check that it can be opened.
-----------------------------------------------------------------------------;
%if 0=%length(&data) %then %let data=&syslast;
%if (%qupcase(&data) = _NULL_) %then %do;
  %let sysrc=1;
  %put ERROR: &sysmacroname: Cannot get attributes for _NULL_ dataset. ;
  %return;
%end;
%let did=%sysfunc(open(&data));
%if 0=&did %then %do;
  %put ERROR: &sysmacroname: Unable to open &=data..;
  %return;
%end;
%let did=%sysfunc(close(&did));

%*----------------------------------------------------------------------------
Use DATA step to create the contents information.
-----------------------------------------------------------------------------;
data &out;
%if &append=1 and %length(&out) %then %do;
  %if %sysfunc(exist(&out)) %then %do;
%*----------------------------------------------------------------------------
Use MODIFY to append to an existing dataset when APPEND=1.
-----------------------------------------------------------------------------;
  if 0 then modify &out;
  %end;
%end;
  length
    libname $8 memname $32
    varnum 8 name $32 length 8 typen 8 type $4 typef $8
    format $49 informat $49
    formatn $32 formatl formatd 8
    informn $32 informl informd 8
    label $256
    nvar 8 nobs 8 crdate 8 modate 8
    typemem $8 memtype $8
    memlabel $256
  ;
  format crdate modate datetime19.;
  dsid=open(symget('data'));
%*----------------------------------------------------------------------------
Read member information using ATTRN() and ATTRC() functions.
-----------------------------------------------------------------------------;
  nvar=attrn(dsid,'nvars');
  nobs=attrn(dsid,'nlobsf');
  crdate=attrn(dsid,'crdte');
  modate=attrn(dsid,'modte');
  libname=attrc(dsid,'lib');
  memname=attrc(dsid,'mem');
  memlabel=attrc(dsid,'label');
  typemem=attrc(dsid,'type');
  memtype=attrc(dsid,'mtype');
%*----------------------------------------------------------------------------
Loop until found all of the variables. Skip variables where VARNAME() is
empty.  That is caused by DROP=/KEEP= dataset options.
-----------------------------------------------------------------------------;
  do index=1 by 1 while (varnum<nvar);
    name=varname(dsid,index);
    if name=' ' then _error_=0;
    else do;
%*----------------------------------------------------------------------------
Read variable information using VARxxx functions.
-----------------------------------------------------------------------------;
      varnum+1;
      length=varlen(dsid,index);
      type=vartype(dsid,index);
      format=varfmt(dsid,index);
      informat=varinfmt(dsid,index);
      label=varlabel(dsid,index);
%*----------------------------------------------------------------------------
Derive TYPE variables. Split FORMAT and INFORMAT into parts. Get FMT Category.
-----------------------------------------------------------------------------;
      typen=1+(type='C');
      type=scan('num,char',typen);
      formatn=substrn(format,1,findc(format,'.',-49,'sdk'));
      formatl=input(scan('0'||substrn(format,lengthn(formatn)+1),1),??32.);
      formatd=input('0'||substrn(format,findc(format,'.')+1),??32.);
      informn=substrn(informat,1,findc(informat,'.',-49,'sdk'));
      informl=input(scan('0'||substrn(informat,lengthn(informn)+1),1),??32.);
      informd=input('0'||substrn(informat,findc(informat,'.')+1),??32.);
      typef=fmtinfo(coalescec(formatn,char('F$',typen)),'cat');
      output;
    end;
  end;
  dsid=close(dsid);
  if varnum ne index-1 then putlog 'NOTE: VARNAME notes above appear because '
    'some variables were dropped by a KEEP= or DROP= dataset option.';
  drop dsid index;
  stop;
run;
%mend contents;
