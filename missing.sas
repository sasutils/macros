%macro missing;
/*----------------------------------------------------------------------------
Return current MISSING statement settings
----------------------------------------------------------------------------*/
%local missing rc;
%let rc=%sysfunc(dosubl(%nrstr(
options nonotes;
data _null_;
  missing='_ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  do i=1 to 27;
    if .=input(char(missing,i),??1.) then substr(missing,i,1)=' ';
  end;
  call symputx('missing',compress(missing,' '));
run;
)));
&missing.
%mend missing;
