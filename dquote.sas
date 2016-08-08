%macro dquote(value);
%sysfunc(quote(%superq(value)))
%mend dquote;
