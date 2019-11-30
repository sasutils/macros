%macro substrn
/*----------------------------------------------------------------------
Subset string (simulation of SUBSTRN function)
----------------------------------------------------------------------*/
(string   /* String to subset */
,position /* Start position */
,length   /* Length of substring */
);
%local len s e;
%*----------------------------------------------------------------------
Get length of string. Calculate start and end positions within string.
When LENGTH is not specified use length of string.
----------------------------------------------------------------------;
%let len=%length(&string);
%if 0=%length(&length) %then %let length=&len;
%let s=%sysfunc(max(&position,1));
%let e=%sysfunc(min(&len,&length+&position-1));
%*---------------------------------------------------------------------
Use SUBSTR to return the part of the string requested.
----------------------------------------------------------------------;
%if (&s <= &len) and (&s <= &e) %then %substr(&string,&s,&e-&s+1);
%mend substrn;
