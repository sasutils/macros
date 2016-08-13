%macro parmv
/*----------------------------------------------------------------------
Parameter validation with standard error message generation.
----------------------------------------------------------------------*/
(_parm     /* Macro parameter name (REQ) */
,_val=     /* Space delimited list of valid values. (OPT) */
      /* There are three special values of _VAL. To test for integers */
      /* use either _val=POSITIVE or _val=NONNEGATIVE. To test for    */
      /* boolean values use _val=0 1. PARMV will accept the aliases   */
      /* (OFF N NO F FALSE) or (ON Y YES T TRUE) and convert them to  */
      /* 0 or 1, respectively. To test just for 1 and 0 then use */
      /* _val=1 0 instead. */
,_req=0    /* Is a value required? 0=No, 1=Yes.                       */
,_words=0  /* Multiple values allowed? 0=No ,1=Yes                    */
,_case=U   /* Change case of value? U=Upper, L=Lower, N=No conversion */
,_force=0  /* Force macro variable to exist? 0=No, 1=Yes.             */
,_defvar=  /* Name of macro variable to check for a default value     */
           /* when parameter value not assigned by calling macro.     */
,_def=     /* Default parameter value when not assigned by calling    */
           /* macro or by macro variable named in _defvar.            */
,_msg=     /* When specified, set parmerr to 1 and writes _msg as the */
           /* last error message.                                     */
);
/*----------------------------------------------------------------------
Use the PARMV macro to validate parameter values and generate error
messages in a standardized format. It can insure that values are in a
consistent value by setting default values and casing.

The calling macro requires local variable PARMERR to return error code.

Invoke macro PARMV once for each macro parameter. After the last
invocation branch to the macro's end whenever PARMERR equals 1 (e.g.,
%if (&parmerr) %then %goto quit;).

Set the global macro variable S_PARMV to 0 to disable the error testing
without disabling the case adjustment and default value setting.

When _VAL=0 1 then parameter will default to 0 when empty.

PARMV tool cannot be used for macros variables with names that match
the parameters (_PARM _VAL _REQ _WORDS _CASE _FORCE _DEFVAR _DEF _MSG)
or local macro variables (_WORD _N _VL _PL _ERROR _PARMTYP)
used by PARMV itself.

Use the _MSG parameter to set PARMERR to 1 and issue a message based on
errors detected by criteria within the calling program.

Note that for efficiency reasons, PARMV does not validate its own
parameters. Only code valid values for the _PARM, _REQ, _WORDS, _CASE,
and _FORCE parameters.

------------------------------------------------------------------------
Usage example:

%macro test(internal,ivar,lzero,uzero,high,day,print);
  %local parmerr;
  %parmv(interval,_req=1,_words=1)
  %parmv(ivar,_def=period)
  %parmv(visit,_req=1)
  %if (%length(&visit) > 7) %then
    %parmv(visit,_msg=SAS name containing 7 or less characters)
  ;
  %parmv(lzero,_req=1)
  %parmv(uzero,_req=1)
  %parmv(high,_req=1,_val=0 1)
  %parmv(day,_req=1)
  %parmv(print,_def=1,_val=0 1)
  %if (&parmerr) %then %goto quit;
  ....
  %quit:
%mend test;

-----------------------------------------------------------------------
History:

Based on original macro developed by Tom Hoffman of HOFFMAN CONSULTING.

2005-03-20 abernt  Added _DEFVAR parameter. Modified final unquote step
                   to skip unquoting if strings includes quote or dquote
                   (in addition to % and &).
2016-08-16 abernt  Rewritten to use SAS 9.4 macro enhancements

----------------------------------------------------------------------*/
%local _word _n _vl _pl _error _parmtyp;

%*----------------------------------------------------------------------
Make sure return macro variables exists.
-----------------------------------------------------------------------;
%if ^%symexist(parmerr) %then %global parmerr;
%if ^%symexist(s_msg) %then %global s_msg;
%if ^%symexist(s_parmv) %then %let s_parmv=1;

%*----------------------------------------------------------------------
If PARMERR has never been set then initialize it and S_MSG.
-----------------------------------------------------------------------;
%if (&parmerr = ) %then %do;
  %let parmerr = 0;
  %let s_msg = ;
%end;

%*----------------------------------------------------------------------
Quote the parameter value and calculate length for a numeric switch.

When parameter does not exist then create it as local or gobal based on
the setting of _FORCE.
-----------------------------------------------------------------------;
%if ^%length(&_parm) %then %let _pl=-1;
%else %if %symexist(&_parm) %then %do;
  %let &_parm=%superq(&_parm);
  %let _pl = %length(&&&_parm);
%end;
%else %do;
  %if (&_force) %then %do;
    %global &_parm;
    %let _pl = 0;
  %end;
  %else %do;
    %local &_parm;
    %let _pl = -1;
  %end;
%end;

%*----------------------------------------------------------------------
Get length of _val to use as a numeric switch.
-----------------------------------------------------------------------;
%let _vl = %length(&_val);

%if (&_pl=0) & %length(&_defvar) %then %if %symexist(&_defvar) %then %do;
%*----------------------------------------------------------------------
Take default value from macro variable defined by _DEFVAR parameter.
-----------------------------------------------------------------------;
  %let &_parm = %superq(&_defvar);
  %let _pl = %length(&&&_parm);
%end;

%if (&_pl=0) & %length(&_def) %then %do;
%*----------------------------------------------------------------------
Take default value from _DEF parameter.
-----------------------------------------------------------------------;
  %let _pl = %length(&_def);
  %let &_parm = &_def;
%end;

%*----------------------------------------------------------------------
Adjust CASE of the parameter value and valid values if requested.
-----------------------------------------------------------------------;
%if (&_pl>0) and (%qupcase(&_case) = U) %then %do;
  %let &_parm = %qupcase(&&&_parm);
  %let _val = %qupcase(&_val);
%end;
%else %if (&_pl>0) and (%qupcase(&_case) = L) %then %do;
  %if (&_pl) %then %let &_parm = %qsysfunc(lowcase(&&&_parm));
  %if (&_vl) %then %let _val = %qsysfunc(lowcase(&_val));
%end;

%*----------------------------------------------------------------------
Handle aliases for BOOLEAN flags. Default to 0 when not required.
-----------------------------------------------------------------------;
%if (&_pl>-1) and (&_val = 0 1) %then %do;
  %if ^(&_req) & ^(&_pl) %then %let &_parm=0;
  %else %if %sysfunc(indexw(OFF NO N FALSE F,%upcase(&&&_parm)))
    %then %let &_parm = 0;
  %else %if %sysfunc(indexw(ON YES Y TRUE T,%upcase(&&&_parm)))
    %then %let &_parm = 1;
  %let _pl=%length(&&&_parm);
%end;

%*----------------------------------------------------------------------
Bail out when no parameter validation is requested
-----------------------------------------------------------------------;
%if (&s_parmv = 0) %then %goto quit;

%*----------------------------------------------------------------------
Initialize to no errors seen.
-----------------------------------------------------------------------;
%let _error = 0;

%*----------------------------------------------------------------------
Error 5: _MSG specified
-----------------------------------------------------------------------;
%if %length(&_msg) %then %let _error = 5;

%*----------------------------------------------------------------------
Error 6: Parameter does not exist
-----------------------------------------------------------------------;
%else %if (&_req) and (&_pl=-1) %then %let _error=6;

%*----------------------------------------------------------------------
Macro variable specified by _PARM is not null.
-----------------------------------------------------------------------;
%else %if (&_pl>0) %then %do;

%*----------------------------------------------------------------------
Error processing - parameter value not null

Error 1: Invalid value - not a positive/nonnegative integer
Error 2: Invalid value - not in valid list
Error 3: Multiple values not allowed
Error 4: Value required
-----------------------------------------------------------------------;

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
        %if ^%index(%str( &_val ),%str( &_word )) %then %let _error = 2;
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

%*----------------------------------------------------------------------
Set PARMERR to indicate error was found.
-----------------------------------------------------------------------;
  %let parmerr = 1;

%*----------------------------------------------------------------------
Force parameter name to uppercase for clearer messages.
-----------------------------------------------------------------------;
  %let _parm = %upcase(&_parm);

%*----------------------------------------------------------------------
Call the parameter a macro variable when called from open code or when
_FORCE was set.
-----------------------------------------------------------------------;
  %if (&_force) | (1=%sysmexecdepth) %then %let _parmtyp=macro variable;
  %else %if (&_pl>-1) %then %let _parmtyp = parameter;

%*----------------------------------------------------------------------
Write initial error message line.
-----------------------------------------------------------------------;
  %put %str( );
  %put ERROR:%str( )%sysmexecname(%sysmexecdepth-1) user error.;

  %if (&_error = 1) %then %do;
    %put ERROR: &&&_parm is not a valid value for the &_parm &_parmtyp..;
    %put ERROR: Only &_val integers are allowed.;
    %let _vl = 0;
  %end;

  %else %if (&_error = 2) %then
    %put ERROR: &&&_parm is not a valid value for the &_parm &_parmtyp..
  ;

  %else %if (&_error = 3) %then %do;
    %put ERROR: &&&_parm is not a valid value for the &_parm &_parmtyp..;
    %put ERROR: The &_parm &_parmtyp may not have multiple values.;
  %end;

  %else %if (&_error = 4) %then
    %put ERROR: A value for the &_parm &_parmtyp is required.
  ;

  %else %if (&_error = 5) %then %do;
    %if (&_parm ^= ) and (&_pl) %then
    %put ERROR: &&&_parm is not a valid value for the &_parm &_parmtyp..;
    %put ERROR: &_msg..;
  %end;

  %else %if (&_error = 6) %then
    %put ERROR: The &_parm &_parmtyp does not exist.
  ;

  %if (&_vl) %then %do;
    %if (&_val = 0 1) %then
      %let _val=%quote(0 (or OFF NO N FALSE F) 1 (or ON YES Y TRUE T)) ;
    %put ERROR: Allowable values are: &_val..;
  %end;

  %if %length(&_msg) %then %let s_msg = &_msg;
  %else %let s_msg = Problem with%str( )%sysmexecname(%sysmexecdepth-1) &_parmtyp
validation - see LOG for details.;

%end; %* errors ;

%quit:

%*----------------------------------------------------------------------
Unquote the the parameter value, unless it contains an ampersand, per
cent sign, quote, or dquote.
-----------------------------------------------------------------------;
%if ^%sysfunc(indexc(&&&_parm,'&%"')) %then
 %let &_parm = %unquote(&&&_parm);

%mend parmv;
