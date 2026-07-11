/* Caller for %fileref() from sasutils/macros (fileref.sas).
   %fileref verifies whether a fileref has been assigned, validating
   the fileref NAME itself (blank, too long, or not a valid SAS name
   all short-circuit to 1) before delegating to the native FILEREF()
   function. This bundle exercises all four short-circuit paths from
   the macro's own header, plus the real FILEREF() delegation for a
   fileref that has been assigned via a FILENAME statement versus one
   that never was. Results are captured into macro variables first
   (rather than used directly as %PUT arguments) since a bare
   %sysfunc(fileref(...)) return value is best read that way. */

%macro fileref
(fileref
);
%if %bquote(&fileref)= %then 1;
%else %if %length(&fileref) > 8 %then 1;
%else %if 0 = %sysfunc(nvalid(&fileref,v7)) %then 1;
%else %sysfunc(fileref(&fileref)) ;
%mend fileref;

%let r1 = %fileref();
%put case1 (expect 1, blank fileref name)=&r1;

%let r2 = %fileref(reallytoolongname);
%put case2 (expect 1, name over 8 chars)=&r2;

%let r3 = %fileref(9bad);
%put case3 (expect 1, invalid SAS name)=&r3;

%let r4 = %fileref(myref99);
%put case4 (expect positive, never assigned)=&r4;

filename myref2 temp;
%let r5 = %fileref(myref2);
%put case5 (expect 0, assigned and exists)=&r5;

data results;
  length case $40 value 8 as_expected 8;
  case='blank name';             value=&r1; as_expected=(value=1);        output;
  case='name over 8 chars';      value=&r2; as_expected=(value=1);        output;
  case='invalid SAS name';       value=&r3; as_expected=(value=1);        output;
  case='never assigned';         value=&r4; as_expected=(value>0);        output;
  case='assigned and exists';    value=&r5; as_expected=(value=0);        output;
run;

proc print data=results noobs;
run;
