%macro lowcase/parmbuff;
/*----------------------------------------------------------------------
Replacement for SAS supplied LOWCASE macro that eliminates errors when 
value contains commas.
----------------------------------------------------------------------*/
%if %length(&syspbuff)>2 %then %sysfunc(lowcase&syspbuff);
%mend;
