%macro qcompbl / parmbuff;
%if %length(&syspbuff)>2 %then %qsysfunc(compbl(%quote&syspbuff));
%mend;
