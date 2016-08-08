%macro mvartest
/*----------------------------------------------------------------------
Test for the existence of a macro variable with option scope limitation
----------------------------------------------------------------------*/
(mvar   /* Name of macro variable */
,scope  /* Macro scope to check (optional) */
);
/*----------------------------------------------------------------------
This macro extends the functionality of the %SYMEXIST() macro function
by allowing you the check for the existance of the macro variable in
a particular macro's scope.
-----------------------------------------------------------------------
Usage:

1) Write a message when an expected macro variable is not defined.

%if ^%mvartest(abcd) %then %put macro variable ABCD is not defined.

2) Globalize the variable that holds the returned number of
observations if not defined by the user of the NOBS macro ;

%macro nobs(data,mvar=);

%if ^%mvartest(&mvar) %then %do;
  %global &mvar;
%end;

... see nobs code ...

%mend nobs;
------------------------------------------------------------------------
Notes:

Returns a 1 when the macro variable exists and 0 otherwise.
----------------------------------------------------------------------*/
%local dsid rc where;

%if %length(&scope) %then %let where=scope=%upcase("&scope");
%else %let where=scope ^= "&sysmacroname" ;
%let where=name=%upcase("&mvar") and &where;

%let dsid = %sysfunc(open(sashelp.vmacro(where=(&where))));
%if (&dsid) %then %do;
  %eval(%sysfunc(fetch(&dsid)) ^= -1)
  %let rc = %sysfunc(close(&dsid));
%end;
%else 0;

%mend mvartest;
