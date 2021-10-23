%macro replace_crlf
/*----------------------------------------------------------------------------
Replace carriage return or linefeed characters that are inside quotes
----------------------------------------------------------------------------*/
(infile   /* Fileref or quoted physical name of input file */
,outfile  /* Fileref or quoted physical name of output file */
,cr='\r'  /* Replacement string for carriage return */
,lf='\n'  /* Replacement string for linefeed */
);
/*----------------------------------------------------------------------------
SAS cannot parse delimited text files that have end of line characters in the
value of a column, even if the value is quoted.  This macro will read a file
byte by byte and keep track of the number of quote characters seen. When the
number of quotes seen is odd then the location is inside of quotes.  So any
carriage return or linefeed inside quotes will be replaced with the CR or LF
parameter, respectively.

The values of CR and LF can be anything that is valid in a PUT statement.

To write nothing in place of the character just set the parameter empty:
To leave one of the characters unchanged just set the hexcode as the value:
  CR='0D'x  or LF='0A'x

Examples:

* Replace only CR characters ;
%replace_crlf('in.csv','out.csv',lf='0A'x);

* Remove CR and replace LF ;
%replace_crlf('in.csv','out.csv',cr=);

* Replace LF with pipe character and leave CD unchanged ;
%replace_crlf('in.csv','out.csv',cr='0D'x,lf='|');

* Read from ZIP file ;
%replace_crlf('myfile.zip' zip member='myfile.csv','myfile.csv')

----------------------------------------------------------------------------*/
%if 0=%length(&infile) or 0=%length(&outfile) %then %do;
  %put ERROR: Both the INFILE and OUTFILE parameters are required by &sysmacroname..;
  %put ERROR: &=infile ;
  %put ERROR: &=outfile ;
%end;
%else %do;
data _null_;
  infile &infile recfm=f lrecl=1;
  file &outfile recfm=f lrecl=1;
  input ch $char1. ;
  retain q 0;
  q=mod(q+(ch='"'),2);
  if q and ch='0D'x then put &cr ;
  else if q and ch='0A'x then put &lf ;
  else put ch $char1. ;
run;
%end;
%mend replace_crlf;
