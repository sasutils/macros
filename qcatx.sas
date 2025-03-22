%macro qcatx /parmbuff;
/*---------------------------------------------------------------------------
Mimic CATX() function as a macro function. Return results with macro quoting.

The CAT... series of functions do not work well with %SYSFUNC() because they
can accept either numeric or character values.  So %SYSFUNC() has to try
and figure out if the value you passed is a number or a string. Which can
cause unwanted messages in the LOG and worse.

Example issue with %sysfunc(catx()):

    1    %put |%sysfunc(catx(^,a,,c))|;
    ERROR: %SYSEVALF function has no expression to evaluate.
    |a^c|

This macro uses the PARMBUFF option to accept a virtually unlimited number
of inputs. It then uses %QSCAN() to pull out the delimiter and loops over
the other items emitting them when not empty.

Examples:

%* Examples matching CATX() example ;
%put |%qcatx(^,A,B,C,D)| Expect: |A^B^C^D| ;
%put |%qcatx(^,E,,F,G)| Expect: |E^F^G|;
%put |%qcatx(^,H,,J)| Expect: |H^J| ;

%* Spaces are preserved in delimiter but not other items ;

%put |%qcatx(^, a ,b , c)| Expect: |a^b^c|;
%put |%qcatx( ,a,b,c)| Expect: |a b c|;

%* You can use either single or double quotes to protect commas.;
%* The quotes are kept as part of the values.;

%put |%qcatx(^,a,'b,b',c)| Expect: |a^'b,b'^c|;
%put |%qcatx(",",a,b)| Expect: |a","b|;

---------------------------------------------------------------------------*/
%local dlm i prefix item;
/*---------------------------------------------------------------------------
SYSPBUFF must have at least 5 characters, like (a,b), for any results to be
produced.  First remove () from around SYSPBUFF.  Then take first value as 
the delimiter.  Loop over rests of items.  When not empty emit the item.
Use of prefix macro variable enables only writing delimiter between items.
---------------------------------------------------------------------------*/
%if %length(&syspbuff)>4 %then %do;
  %let syspbuff=%qsubstr(&syspbuff,2,%length(&syspbuff)-2);
  %let dlm=%qscan(&syspbuff,1,%str(,),mq);
  %do i=2 %to %sysfunc(countw(&syspbuff,%str(,),mq));
    %let item=%qsysfunc(strip(%qscan(&syspbuff,&i,%str(,),mq)));
    %if %length(&item) %then %do;
      %*;&prefix.&item.
      %let prefix=&dlm.;
    %end;
  %end;
%end;
%mend qcatx;
