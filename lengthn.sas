%macro lengthn / parmbuff;
/*----------------------------------------------------------------------------
Length of string ignoring trailing spaces. Leading spaces are counted.

Notes:
When SYSPBUFF is shorter than 3 bytes there is no input, so return 0.
Otherwise use SYSPBUFF to generate %QUOTE() macro function call so you can
pass the value to the SAS function LENGTHN() via %SYSFUNC() macro function.

Example:
%put 4 3 0 0=%lengthn( abc ) %lengthn(abc ) %lengthn( ) %lengthn;

----------------------------------------------------------------------------*/
%if %length(&syspbuff)<3 %then 0;
%else %sysfunc(lengthn(%quote&syspbuff));
%mend lengthn;
