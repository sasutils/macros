%macro bench;
%*----------------------------------------------------------------------
Measures elapsed time (in seconds) between sucessive invocations
------------------------------------------------------------------------
This code was developed by HOFFMAN CONSULTING as part of a FREEWARE
macro tool set. Its use is restricted to current and former clients of
HOFFMAN CONSULTING as well as other professional colleagues. Questions
and suggestions may be sent to TRHoffman@sprynet.com.
----------------------------------------------------------------------;
%global _bench;

%if (&_bench =) %then %let _bench = %sysfunc(datetime());
%else %do;
  %put Elapsed seconds = %sysevalf(%sysfunc(datetime()) - &_bench);
  %let _bench =;
%end;
%mend bench;
