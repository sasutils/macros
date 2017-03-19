%macro cfmtgen
/*----------------------------------------------------------------------
Generate C-format in catalog &libref..CFORMATS from info in
&libref.FORMATS.
----------------------------------------------------------------------*/
(format      /* List of format names */
,libref=WORK /* Library reference for format catalogs */
,data=       /* PROC FORMAT output data set */
);

/*----------------------------------------------------------------------
This code was developed by HOFFMAN CONSULTING as part of a FREEWARE
macro tool set. Its use is restricted to current and former clients of
HOFFMAN CONSULTING as well as other professional colleagues. Questions
and suggestions may be sent to TRHoffman@sprynet.com.
-----------------------------------------------------------------------
Usage:

%* creates C-formats for _WGTUNT and INVEST;

%cfmtgen($WGTUNT INVEST,libref=FORMATS)

%* create C-formats for formats contained in FMTOUT data set. Useful as
second step in format creation ;

%cfmtgen(data=FMTOUT,libref=FORMATS)
------------------------------------------------------------------------
Notes:

Normally the CFMTGEN macro is invoked by the FMTGEN macro (when cfmt=1).

C-formats map a code into the code plus a label. For example, the
C-format for the format that maps 1 into 'MALE' would map 1 into
'1 MALE'. These formats are useful to programmers who need to use the
code in a program, but also require knowledge of the description.

The FMTSEARCH option can be used to switch between C-formats and
regular formats.

Do not generate C-formats for formats that include a range of values.
-----------------------------------------------------------------------
History:

21FEB96 TRHoffman  creation
08NOV97 TRHoffman  Protected against numeric to character conversions.
10OCT00 TRHoffman  Cleaned up work data sets.
----------------------------------------------------------------------*/
%local
  parmerr macro /* required by parmv */
  dsid varid    /* used by OPEN and VARNUM SCL functions */
  stype         /* variable START data type (N or C) */
  ltype         /* variable LABEL data type (N or C) */
  type          /* =0 if variable TYPE not in input data set */
  hlo           /* =0 if variable HLO not in input data set */
  ;
%let macro = CFMTGEN;

%parmv(LIBREF,_req=1)

%if (&parmerr) %then %goto quit;

%*----------------------------------------------------------------------
Use PROC FORMAT to unload requested formats when the data parameter is
not specified.

Exclude picture formats (TYPE = P) and informats (TYPE = I and J).
Select specified entries.
-----------------------------------------------------------------------;
%if ^%length(&data) %then %do;
  %let type = type;
  %let hlo = 1;
  %let stype = C;
  proc format cntlout=_cfmt(where=(type in ('N' 'C'))
    keep=fmtname type hlo start label)
    lib=&libref..formats;
  %if (%length(&format)) %then
    select &format
  ;
    ;
  run;
%end;

%*----------------------------------------------------------------------
Otherwise sort the input data set in the same order as the CNTLOUT data
set. Exclude picture formats and informats.

Look up variable type of START and LABEL variables.
-----------------------------------------------------------------------;
%else %do;
  %let dsid = %sysfunc(open(&data));
  %let hlo = %sysfunc(varnum(&dsid,hlo));
  %if (&hlo) %then %let hlo = hlo;
  %else %let hlo =;
  %let type = %sysfunc(varnum(&dsid,type));
  %if (&type) %then %let type = type;
  %else %let type =;
  %let varid = %sysfunc(varnum(&dsid,start));
  %let stype = %sysfunc(vartype(&dsid,&varid));
  %let varid = %sysfunc(varnum(&dsid,label));
  %let ltype = %sysfunc(vartype(&dsid,&varid));
  %let dsid = %sysfunc(close(&dsid));

  proc sort data=&data out=_cfmt(keep=fmtname &type &hlo start label);
  %if (&type = type) %then
    where upcase(type) in ('N' 'C');
  ;
    by descending &type fmtname;
  run;
%end;

%*----------------------------------------------------------------------
Determine the length of the data in the START variable.
Select specified members.

When START is numeric, convert to character.
-----------------------------------------------------------------------;
data _length(keep=fmtname &type length);
  set _cfmt;
%if (&hlo = hlo) %then
  where (hlo = '')
;
%else %if (&stype = C) %then
  where (start ^= :'**OTHER')
; ;
%if (&stype = N) %then
  length = length(left(put(start,32.)))
;
%else
  length = length(left(start))
; ;
run;

%*----------------------------------------------------------------------
Determine maximum length.
Exclude 'OTHER' from start length calculations.
-----------------------------------------------------------------------;
proc summary data=_length nway;
  by descending &type fmtname;
  var length;
  output out=_mlength(keep=&type fmtname length) max=length;
run;

%*----------------------------------------------------------------------
Add start value to beginning of each label. Use maximum length of
start to right align start value.
-----------------------------------------------------------------------;
data _cfmt(rename=(_start=start _label=label));
  length _start _label $200;
  merge _cfmt
        _mlength;
  by descending &type fmtname;
  drop start label length;
%if (&ltype = N) %then
  _label = left(put(label,32.))
;
%else
  _label = label
; ;

%if (&stype = N) %then
  _start = left(put(start,32.))
;
%else
  _start = start
; ;

  _label = right(putc(left(_start),'$'||left(put(length,2.))))
          ||' '||_label;
run;

proc format cntlin=_cfmt lib=&libref..cformats;
run;

proc sql;
  drop table _cfmt;
  drop table _length;
  drop table _mlength;
quit;

%quit:
%mend cfmtgen;
