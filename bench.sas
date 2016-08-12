%macro bench
/*----------------------------------------------------------------------
Measures elapsed time (in seconds) between sucessive invocations
----------------------------------------------------------------------*/
(mvar /* Macro variable used for recording start time (default=_bench)*/
);
/*----------------------------------------------------------------------
Call it once to start the timing and then a second time to report the
elapsed time and clear the saved time.

Use different values for MVAR to time multiple overlapping periods.
----------------------------------------------------------------------*/
%if (&mvar=) %then %let mvar=_bench;
%if ^%symexist(&mvar) %then %global &mvar;

%if (&&&mvar =) %then %let &mvar = %sysfunc(datetime());
%else %do;
  %put NOTE: Elapsed seconds = %sysevalf(%sysfunc(datetime()) - &&&mvar);
  %let &mvar =;
%end;
%mend bench;
