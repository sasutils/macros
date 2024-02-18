%macro lowcase/parmbuff;
/*----------------------------------------------------------------------
Replacement for SAS supplied LOWCASE macro that eliminates errors when 
value contains commas.  The %IF conditions make sure the argument is
not empty.
----------------------------------------------------------------------*/
%if %length(&syspbuff) %then %if %length&syspbuff %then %sysfunc(lowcase&syspbuff);
%mend;
