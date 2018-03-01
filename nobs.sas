%macro nobs
/*----------------------------------------------------------------------
Return the number of observations in a dataset reference
----------------------------------------------------------------------*/
(data       /* Dataset specification (where clauses are supported) */
,mvar=nobs  /* Macro variable to store result. */
            /* Set MVAR= to use NOBS as an in-line function. */
);
/*----------------------------------------------------------------------
This code was developed by HOFFMAN CONSULTING as part of a FREEWARE
macro tool set. Its use is restricted to current and former clients of
HOFFMAN CONSULTING as well as other professional colleagues. Questions
and suggestions may be sent to TRHoffman@sprynet.com.
-----------------------------------------------------------------------
Calls to: mvartest.sas sasname.sas
-----------------------------------------------------------------------
Usage:

When the MVAR parameter is empty then NOBS will return the result as
the output of the macro call so that NOBS can be called in a %IF or
%LET statement. See examples.

------------------------------------------------------------------------
Examples:

%* Generating the default macro variable ;
%nobs(EVENTS)
%if (&nobs = -1) %then %put %sysfunc(sysmsg()) ;
%else %if (&nobs > 0) %then %do;
  ....

%* Use without generating macro variable ;
%if (%nobs(EVENTS,mvar=) > 0) %then %do;
  ....

%* Generating a different macro variable and use WHERE clause ;
%nobs(demog(where=(sex=1)),mvar=nmales)
%put Number of males = &nmales;

------------------------------------------------------------------------
Notes:

NOBS will return -1 when it cannot count the number of observations.
You can use %sysfunc(sysmsg()) to get the reason.

The macro variable specified in the MVAR parameter is globalized if not
previously defined in the calling environment.

When the DATA parameter is not specified, the last created data file is
used.

In the rare case that NLOBSF function cannot count the observations
then the NOBS macro will loop through the dataset and count.
Testing so far has found that sequential datasets such as V5 transport
libraries cannot use the NLOBSF function. For large sequential datasets
you will get faster results using an SQL query instead of NOBS macro.

-----------------------------------------------------------------------
History:
03DEC95  TRHoffman  Creation
12JUL96  TRHoffman  Protected against different values of MISSING
                    option.
20AUG97  TRHoffman  Protected against case changes in options table.
11MAR99  TRHoffman  Trimmed the returned macro variable. (Recommended
                    by Paulette Staum). Used macro mvartest to globalize
                    previously undefined variables.
25OCT2000 abernt    Updated to handle lowercase letters in where clause
                    and eight character libnames. Eliminated need to
                    use %TRIM() macro.
14OCT03  TRHoffman  Used qupcase function to permit macro variables in
                    where clause.
09JAN2009 abernt    Changed to use ATTRN functions. Test MVAR value.
                    Return results like a function when MVAR is blank.
01MAR2018 abernt    Removed usage of sasname and mvartest macros.
----------------------------------------------------------------------*/
%local dsid return ;

%if %length(&mvar) %then %do;
%*----------------------------------------------------------------------
MVAR parameter must be a valid variable name.
-----------------------------------------------------------------------;
  %if not %sysfunc(nvalid(&mvar)) %then %do;
    %put %str( );
    %put ERROR: Macro NOBS user error.;
    %put ERROR: "&mvar" is not a valid value for MVAR. Must be a valid SAS name.;
    %goto quit;
  %end;
%*----------------------------------------------------------------------
MVAR paramater cannot duplicate a variable name used by NOBS macro.
-----------------------------------------------------------------------;
  %if %sysfunc(indexw(DATA MVAR DSID RETURN,%upcase(&mvar))) %then %do;
    %put %str( );
    %put ERROR: Macro NOBS user error.;
    %put ERROR: "&mvar" is not a valid value for MVAR. Name in use by NOBS macro.;
    %goto quit;
  %end;
%*----------------------------------------------------------------------
Globalize macro variable when not defined.
-----------------------------------------------------------------------;
  %if not %symexist(&mvar) %then %global &mvar ;
%end;

%*----------------------------------------------------------------------
When DATA parameter not specified, use &syslast macro variable to get
last created data set.
-----------------------------------------------------------------------;
%if %bquote(&data) =  %then %let data=&syslast;

%*----------------------------------------------------------------------
DATA=_NULL_ will successfully OPEN, but cannot be queried with ATTRN
function. So by setting DATA=*_NULL_* the OPEN call will fail and set
an error message that can be retrieved with the SYSMSG() function.
-----------------------------------------------------------------------;
%if (%qupcase(&data) = _NULL_) %then %let data=*_NULL_*;

%*----------------------------------------------------------------------
Initialize for failure.
-----------------------------------------------------------------------;
%let return=-1;

%*----------------------------------------------------------------------
Open the dataset for random access.
  When there are no active where clauses then use NLOBS.
  If that did not get a count then try NLOBSF.
-----------------------------------------------------------------------;
%let dsid = %sysfunc(open(&data));
%if &dsid %then %do;
  %if not %sysfunc(attrn(&dsid,WHSTMT)) %then
    %let return = %sysfunc(attrn(&dsid,NLOBS));
  %if (&return = -1) %then %let return = %sysfunc(attrn(&dsid,NLOBSF));
  %let dsid = %sysfunc(close(&dsid));
%end;

%*----------------------------------------------------------------------
If unable to get a count then try to open dataset for sequential access
and count observations by fetching each one.
-----------------------------------------------------------------------;
%if (&return = -1) %then %do;
  %let dsid = %sysfunc(open(&data,IS));
  %if &dsid %then %do;
    %let return=0;
    %do %while (%sysfunc(fetch(&dsid)) = 0);
      %let return = %eval(&return + 1);
    %end;
    %let dsid = %sysfunc(close(&dsid));
  %end;
%end;

%*----------------------------------------------------------------------
Return the value.
-----------------------------------------------------------------------;
%if %length(&mvar) %then %let &mvar=&return;
%else &return;

%quit:
%mend nobs;
