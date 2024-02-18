%macro qlowcase2/parmbuff;
  %if %length(&syspbuff)>2 %then %qsysfunc(lowcase(%quote&syspbuff));
%mend;