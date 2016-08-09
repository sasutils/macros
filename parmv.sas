%macro parmv
/*----------------------------------------------------------------------
Parameter validation with standard error message generation.
----------------------------------------------------------------------*/
(_parm     /* Macro parameter name (REQ)                              */
,_val=     /* List of valid values or POSITIVE for any positive       */
           /* integer or NONNEGATIVE for any non-negative integer.    */
           /* When _val=0 1, OFF N NO F FALSE snd ON Y YES T TRUE     */
           /* (case insensitive) are acceptable aliases for 0 and 1,  */
           /* respectively.                                           */
,_req=0    /* Value required? 0=No, 1=Yes.                            */
,_words=0  /* Multiple values allowed? 0=No ,1=Yes                    */
,_case=U   /* Convert case of parameter value & _val? U=upper,        */
           /* L=lower,N=no conversion.                                */
,_msg=     /* When specified, set parmerr to 1 and writes _msg as the */
           /* last error message.                                     */
,_varchk=0 /* 1=Issue global statement if parameter does not exist.   */
           /* 0=Will create local macro so that checks of _DEF and    */
           /*   _DEFVAR values will proceed.                          */
,_defvar=  /* Name of macro variable to check for a default value     */
           /* when parameter value not assigned by calling macro.     */
,_def=     /* Default parameter value when not assigned by calling    */
           /* macro or by macro variable named in _defvar.            */
);

/*----------------------------------------------------------------------
Notes:

The calling macro requires local variable PARMERR for return error code.

Invoke macro PARMV once for each macro parameter. After the last
invocation branch to the macro's end whenever PARMERR equals 1 (e.g.,
%if (&parmerr) %then %goto quit;).

Macro PARMV can be disabled (except for changing case) by setting the
global macro variable S_PARMV to 0.

PARMV tool cannot be used for macros variables with names that are used
as PARMV parameters or local macro variables.

Use the _MSG parameter to set PARMERR to 1 and issue a message based on
validation criteria within the calling program.

Note that for efficiency reasons, PARMV does not validate its own
parameters. Only code valid values for the _REQ, _WORDS, _CASE, and
_VARCHK parameters.

------------------------------------------------------------------------
Usage example:

%macro test;
%local parmerr;
%parmv(INTERVAL,_req=1,_words=1)
%parmv(IVAR,_req=1)
%if (%length(&visit) > 7) %then
 %parmv(IVAR,_msg=SAS name containing 7 or less characters)
;
%parmv(LZERO,_req=1)
%parmv(UZERO,_req=1)
%parmv(HIGH,_req=1,_val=0 1)
%parmv(DAY,_req=1)
%parmv(PRINT,_req=1,_val=0 1)
%if (&parmerr) %then %goto quit;
....
%quit:
%mend test;

-----------------------------------------------------------------------
History:

This code was developed by HOFFMAN CONSULTING as part of a FREEWARE
macro tool set. Its use is restricted to current and former clients of
HOFFMAN CONSULTING as well as other professional colleagues.
-----------------------------------------------------------------------
09SEP96 TRHoffman  Creation
16MAR98 TRHoffman  Replaced QTRIM autocall macro with QSYSFUNC and TRIM
                   in order to avoid conflict with the i command line
                   macro.
04OCT99 TRHoffman  Added _val=NONNEGATIVE. Converted _val=0 1 to map
                   N NO F FALSE OFF --> 0 and Y YES T TRUE ON --> 1.
                   Added _varchk parameter to support variables assumed
                   to be defined before macro invocation.
12APR00 TRHoffman  Changed the word 'parameter' in the message text
                   to 'macro variable' when _varchk=1. Fixed
                   NONNEGATIVE option.
10JUN01 TRHoffman  Added _DEF parameter. Returned S_MSG global macro
                   variable.
20MAR05 abernt     Added _DEFVAR parameter. Modified final unquote step
                   to skip unquoting if strings includes quote or dquote
                   (in addition to % and &).
2016-08-16 abernt  Take advantage of SAS 9.4 macro enhancements
----------------------------------------------------------------------*/
%local _macro _word _n _vl _pl _ml _error _parm_mv;

%*----------------------------------------------------------------------
Make sure return macro variables exists.
-----------------------------------------------------------------------;
%if ^%symexist(parmerr) %then %global parmerr;
%if ^%symexist(s_msg) %then %global s_msg;
%if ^%symexist(s_parmv) %then %let s_parmv=1;

%*----------------------------------------------------------------------
Initialize error flags, and returned message.
-----------------------------------------------------------------------;
%if (&parmerr = ) %then %do;
  %let parmerr = 0;
  %let s_msg = ;
%end;
%let _error = 0;

%*----------------------------------------------------------------------
Check that parameter exists. Quote parameter value.
-----------------------------------------------------------------------;
%if %symexist(&_parm) %then %let &_parm=%superq(&_parm);
%else %do;
  %if (&_varchk) %then %let _error=6;
  %if (&_req) & ^(&varhck) %then %global &_parm ;
  %else %local &_parm ;
%end;

%*----------------------------------------------------------------------
Get lengths of _val, _msg, and _parm to use as numeric switches.
-----------------------------------------------------------------------;
%let _vl = %length(&_val);
%let _ml = %length(&_msg);
%let _pl = %length(&&&_parm);

%if ^(&_pl) and %length(&_defvar) %then %do;
%*----------------------------------------------------------------------
Check for default values from &&&_defvar.
-----------------------------------------------------------------------;
  %if %symexist(&_defvar) %then %do;
    %let _defvar = %superq(&_defvar);
    %let _pl = %length(&_defvar);
    %let &_parm = &_defvar;
  %end;
%end;

%if ^(&_pl) and %length(&_def) %then %do;
%*----------------------------------------------------------------------
Check for default values from &_def.
-----------------------------------------------------------------------;
  %let _pl = %length(&_def);
  %let &_parm = &_def;
%end;

%*----------------------------------------------------------------------
When _MSG is not specified, change case of the parameter and valid
values conditional on the value of the _CASE parameter.
-----------------------------------------------------------------------;
%if ^(&_ml) %then %do;
  %let _parm = %upcase(&_parm);
  %let _case = %upcase(&_case);

  %if (&_case = U) %then %do;
    %let &_parm = %qupcase(&&&_parm);
    %let _val = %qupcase(&_val);
  %end;
  %else %if (&_case = L) %then %do;
    %if (&_pl) %then %let &_parm = %qsysfunc(lowcase(&&&_parm));
    %if (&_vl) %then %let _val = %qsysfunc(lowcase(&_val));
  %end;
  %else %let _val = %quote(&_val);

%*----------------------------------------------------------------------
When _val=0 1, map supported aliases into 0 or 1.
-----------------------------------------------------------------------;
  %if (&_val = 0 1) %then %do;
    %let _val=%quote(0 (or OFF NO N FALSE F) 1 (or ON YES Y TRUE T));
    %if %index(%str( OFF NO N FALSE F ),%str( &&&_parm )) %then
     %let &_parm = 0;
    %else %if %index(%str( ON YES Y TRUE T ),%str( &&&_parm )) %then
     %let &_parm = 1;
  %end;
%end;

%*----------------------------------------------------------------------
Bail out when no parameter validation is requested
-----------------------------------------------------------------------;
%if (&s_parmv = 0) %then %goto quit;

%*----------------------------------------------------------------------
Error processing - parameter value not null

Error 1: Invalid value - not a positive/nonnegative integer
Error 2: Invalid value - not in valid list
Error 3: Multiple values not allowed
Error 4: Value required
Error 5: _MSG specified
Error 6: Parameter does not exist
-----------------------------------------------------------------------;
%if _error=6 %then ;
%else %if (&_ml) %then %let _error = 5;

%*----------------------------------------------------------------------
Macro variable specified by _PARM is not null.
-----------------------------------------------------------------------;
%else %if (&_pl) %then %do;

%*----------------------------------------------------------------------
Loop through possible list of words in the _PARM macro variable.
------------------------------------------------------------------------;
  %if ((&_vl) | ^(&_words)) %then %do;
    %let _n = 1;
    %let _word = %qscan(&&&_parm,1,%str( ));
%*----------------------------------------------------------------------
Check against valid list for each word in macro parameter
-----------------------------------------------------------------------;
    %do %while (%length(&_word));

%*----------------------------------------------------------------------
Positive integer check.
-----------------------------------------------------------------------;
      %if (&_val = POSITIVE) %then %do;
        %if %sysfunc(verify(&_word,0123456789)) %then %let _error = 1;
        %else %if ^(&_word) %then %let _error = 1;
      %end;

%*----------------------------------------------------------------------
Non-negative integer check.
-----------------------------------------------------------------------;
      %else %if (&_val = NONNEGATIVE) %then %do;
        %if %sysfunc(verify(&_word,0123456789)) %then %let _error = 1;
      %end;

%*----------------------------------------------------------------------
Check against valid list. Note blank padding.
-----------------------------------------------------------------------;
      %else %if (&_vl) %then %do;
        %if ^%index(%str( &_val ),%str( &_word )) %then
         %let _error = 2;
      %end;

%*---------------------------------------------------------------------
Get next word from parameter value
-----------------------------------------------------------------------;
      %let _n = %eval(&_n + 1);
      %let _word = %qscan(&&&_parm,&_n,%str( ));
    %end; %* for each word in parameter value;

%*----------------------------------------------------------------------
Check for multiple _words. Set error flag if not allowed.
-----------------------------------------------------------------------;
    %if (&_n ^= 2) & ^(&_words) %then %let _error = 3;
  %end; %* valid not null ;

%end; %* parameter value not null ;

%*----------------------------------------------------------------------
Error processing - Parameter value null

Error 4: Value required.
-----------------------------------------------------------------------;
%else %if (&_req) %then %let _error = 4;

%*----------------------------------------------------------------------
Write error messages
-----------------------------------------------------------------------;
%if (&_error) %then %do;
  %let parmerr = 1;

%*----------------------------------------------------------------------
Get calling macro name to use in error messages.
-----------------------------------------------------------------------;
  %let _macro=%sysmexecname(%sysmexecdepth-1);
  %if %sysmexecdepth>1 %then %let _macro=Macro &_macro;

%*----------------------------------------------------------------------
Adjust message based on whether _VARCHK was set.
-----------------------------------------------------------------------;
  %if (&_varchk) %then %let _parm_mv = macro variable;
  %else %let _parm_mv = parameter;

  %put %str( );
  %put ERROR: &_macro user error.;

  %if (&_error = 1) %then %do;
    %put ERROR: &&&_parm is not a valid value for the &_parm &_parm_mv..;
    %put ERROR: Only &_val integers are allowed.;
    %let _vl = 0;
  %end;

  %else %if (&_error = 2) %then
    %put ERROR: &&&_parm is not a valid value for the &_parm &_parm_mv..
  ;

  %else %if (&_error = 3) %then %do;
    %put ERROR: &&&_parm is not a valid value for the &_parm &_parm_mv..;
    %put ERROR: The &_parm &_parm_mv may not have multiple values.;
  %end;

  %else %if (&_error = 4) %then
    %put ERROR: A value for the &_parm &_parm_mv is required.
  ;

  %else %if (&_error = 5) %then %do;
    %if (&_parm ^= ) %then
    %put ERROR: &&&_parm is not a valid value for the &_parm &_parm_mv..;
    %put ERROR: &_msg..;
  %end;

  %else %if (&_error = 6) %then
    %put ERROR: The &_parm &_parm_mv does not exist.
  ;


  %if (&_vl) %then
   %put ERROR: Allowable values are: &_val..;

  %if %length(&_msg) %then %let s_msg = &_msg;
  %else %let s_msg = Problem with &_macro &_parm_mv values - see
LOG for details.;

%end; %* errors ;

%quit:

%*----------------------------------------------------------------------
Unquote the the parameter value, unless it contains an ampersand, per
cent sign, quote, or dquote.
-----------------------------------------------------------------------;
%if ^%sysfunc(indexc(&&&_parm,'&%"')) %then
 %let &_parm = %unquote(&&&_parm);

%mend parmv;
