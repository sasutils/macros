%macro catx(dlm) /parmbuff;
/*---------------------------------------------------------------------------
Mimic CATX() function as a macro function.

The CAT... series of functions do not work well with %SYSFUNC() because they
can accept either numeric or character values.  So %SYSFUNC() has to try
and figure out if the value you passed is a number or a string. Which can
cause unwanted messages in the LOG and worse.

Example issue with %sysfunc(catx()):

    1    %put |%sysfunc(catx(^,a,,c))|;
    ERROR: %SYSEVALF function has no expression to evaluate.
    |a^c|

This function will instead use %SCAN() to pull out the individual words and
only insert the delimiter string when the word value is not null.

It uses the PARMBUFF option to accept a virtually unlimited number of inputs.
It then uses %SCAN() to pull out each word and emit it when not empty.

Examples:
Simple examples without any special characters:
    1    %put |%catx(^,a,b,c)|;
    |a^b^c|
    2    %put |%catx(^,a,,c)|;
    |a^c|
    3    %put |%catx(^,,b,)|;
    |b|

You can use simple macro quoting for the delimiter value:
    4    %put |%catx(%str( and ),a,b,)|;
    |a and b|
    5    %put |%catx(%str(;),a,b,c)|;
    |a;b;c|

For the individual words add %NRSTR() around the quoted value:
    6    %put |%catx(^,a,%nrstr(%str( b )),c)|;
    |a^ b ^c|

---------------------------------------------------------------------------*/
%local i sep word;
%if %length(&syspbuff)>2 %then %do;
  %let syspbuff=%qsubstr(&syspbuff,2,%length(&syspbuff)-2);
  %do i=2 %to %sysfunc(countw(&syspbuff,%str(,),qm));
    %let word=%scan(&syspbuff,&i,%str(,),qm);
    %if %length(&word) %then %do;
      %*;&sep.&word.
      %let sep=&dlm.;
    %end;
  %end;
%end;
%mend catx;
