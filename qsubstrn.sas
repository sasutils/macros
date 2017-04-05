%macro qsubstrn
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
----------------------------------------------------------------------;
%let len=%length(&string);
%let s=%sysfunc(max(&position,1));
%let e=%sysfunc(min(&len,&length+&position-1));
%*---------------------------------------------------------------------
Use QSUBSTR to return the part of the string requested.
----------------------------------------------------------------------;
%if (&s <= &len) and (&s <= &e) %then %qsubstr(&string,&s,&e-&s+1);
%mend qsubstrn;
