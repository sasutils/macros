%macro lowcase/parmbuff;
/*----------------------------------------------------------------------
Replacement for SAS supplied LOWCASE macro that eliminates errors 

SYSPBUFF must have at least 3 characters or nothing was passed in.
Use SYSPBUFF to generate %QUOTE function call so value can be passed
to %SYSFUNC(LOWCASE()).
----------------------------------------------------------------------*/
%if %length(&syspbuff)>2 %then %sysfunc(lowcase(%quote&syspbuff));
%mend;
