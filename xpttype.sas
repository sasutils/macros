%macro xpttype(filename  /* fileref or quoted physical filename */);
/*----------------------------------------------------------------------------
Check file to see what type of transport file it is.

Returns
   CPORT for PROC CPORT/CIMPORT file
   XPORT for V5 export file
   XPORT_V9 for V8/9 export file
   SAS7BDAT for SAS dataset
   UNKNOWN for any other file

Examples:
  %put %xpttype('~/xport.xpt');
  %put %xpttype('~/subj.xpt');
  %put %xpttype('~/r_lrevw.xpt');
  %put %xpttype('~/test1.sas7bdat');

----------------------------------------------------------------------------*/
%local return rc ;
%*----------------------------------------------------------------------------
Set default value of UNKNOWN
-----------------------------------------------------------------------------;
%let return=UNKNOWN;

%*----------------------------------------------------------------------------
Use %SYSFUNC() to call DOSUBL to run a data step to read the first 80 bytes
of the file.
-----------------------------------------------------------------------------;
%let rc=%sysfunc(dosubl(%nrstr(
data _null_;
  infile &filename recfm=f lrecl=80 obs=1;
  input;
  list;
  if _infile_=
 '**COMPRESSED** **COMPRESSED** **COMPRESSED** **COMPRESSED** **COMPRESSED********'
    then call symputx("return",'CPORT');
  else if _infile_=:'HEADER RECORD*******LIB'
   and substr(_infile_,29)='HEADER RECORD!!!!!!!000000000000000000000000000000' then do;
   select (substr(_infile_,21,8));
    when ('LIBRARY') call symputx("return",'XPORT');
    when ('LIBV8') call symputx("return",'XPORT_V9');
    otherwise;
   end;
  end;
  else if _infile_=:'000000000000000000000000c2ea8160b31411cfbd92080009c7318c181f1011'x
    then call symputx("return",'SAS7BDAT')
  ;
run;
)));

%*----------------------------------------------------------------------------
Return to value of &RETURN as the output of the macro.
-----------------------------------------------------------------------------;
&return.
%mend xpttype ;
