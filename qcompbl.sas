%macro qcompbl / parmbuff;
/*----------------------------------------------------------------------------
Compress multiple spaces into one, return value with macro quoting.

When SYSPBUFF is shorter than 3 bytes there is no input, so do nothing.
Otherwise use SYSPBUFF to generate %QUOTE() macro function call so you can
pass the value to SAS function COMPBL() via %QSYSFUNC() macro function.
----------------------------------------------------------------------------*/
%if %length(&syspbuff)>2 %then %qsysfunc(compbl(%quote&syspbuff));
%mend;
