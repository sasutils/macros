%macro squote(value);
%if %sysevalf(&sysver < 9.3) %then
%unquote(%str(%')%qsysfunc(tranwrd(%superq(value),%str(%'),''))%str(%'))
;
%else %sysfunc(quote(%superq(value),%str(%'))) ;
%mend squote;
