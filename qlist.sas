%macro qlist2
/*----------------------------------------------------------------------
Adds quotes to each word in a list, and optionally separate multiple
words with a comma and adds parentheses to the entire string.
----------------------------------------------------------------------*/
(list      /* List of words */
,paren=1   /* Include list in parentheses? 1=Yes,0=No */
,comma=1   /* Use comma delimiter in output list? 1=Yes,0=No */
,delimit=  /* Word delimiter for input list */
,dsd=      /* Adjacent delimiters indicate blank value? 1=Yes,0=No */
,quote=1   /* Quote character type. 1=Single 2=Double */
);
%local rp i sep ;

%*----------------------------------------------------------------------
Set COMMA to value to use as separator in the output list.
-----------------------------------------------------------------------;
%if "&comma" = "1" %then %let comma = ,;
%else %let comma = %str( );

%*----------------------------------------------------------------------
When delimiter not specified set to a blank and default DSD to 0.
-----------------------------------------------------------------------;
%if ^%length(&delimit) %then %do;
  %let delimit = %str( );
  %if ^%length(&dsd) %then %let dsd=0;
%end;

%*----------------------------------------------------------------------
Set DSD to value needed for COUNTW() and SCAN() function calls.
-----------------------------------------------------------------------;
%if "&dsd"="0" %then %let dsd=;
%else %let dsd=M;

%*----------------------------------------------------------------------
Set QUOTE to value needed for QUOTE() function calls.
-----------------------------------------------------------------------;
%if "&quote"="1" %then %let quote=%str(%');
%else %let quote=%str(%");

%*----------------------------------------------------------------------
Add parentheses when requested.
-----------------------------------------------------------------------;
%if ("&paren" = "1") %then %do;
  %let rp = );
  (
%end;

%*----------------------------------------------------------------------
Process each word individually using the SCAN() and QUOTE() functions.
-----------------------------------------------------------------------;
%do i=1 %to %sysfunc(max(1,%sysfunc(countw(&list,&delimit,&dsd))));
%*;%unquote(&sep)%sysfunc(quote(%qsysfunc(scan(&list,&i,&delimit,&dsd)),&quote))
  %let sep=&comma;
%end;

%*----------------------------------------------------------------------
Add parentheses when requested.
-----------------------------------------------------------------------;
%*;&rp
%mend qlist2;

%put where=name in %qlist(%bquote(Alfred  Don Mary),dsd=1,delimit=,comma=1,quote=1);
%put where=name in %qlist2(%bquote(Alfred  Don Mary),dsd=1,delimit=,comma=1,quote=1);
%put |%qlist(paren=0)|;
%put |%qlist2(paren=0)|;

%let x1=%qlist(a b c,comma=0);
%let x2=%qlist2(a b c,comma=0);
data _null_;
  set sashelp.vmacro;
  where name in ('X1','X2');
  hex=putc(value,cats('$HEX',2*length(value),'.'));
  put (name value hex) (=/);
run;
