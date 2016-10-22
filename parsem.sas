%macro parsem
/*----------------------------------------------------------------------
Macro tool for parsing a macro variable text string
----------------------------------------------------------------------*/
(_str_      /* Text string */
,word=      /* Macro variable to hold first (or last) word in _str_.
               When not specified, macro call resolves to this word,
               except when NWORDS=1. Defaults to W when strip=ALL. */
,rest=      /* Macro variable to hold remainder of string. */
,strip=LAST /* Which word(s) to strip: LAST, FIRST, ALL */
,nstrip=1   /* Number of words to strip */
,delimit=   /* Delimiter character. Defaults to blank. */
,nwords=0   /* Return number of words in string? 0=No,1=as value
               returned by macro, OR macro variable holding the number
               of words. Defautls to NWORDS when strip=ALL. */
);

/*----------------------------------------------------------------------
This code was developed by HOFFMAN CONSULTING as part of a FREEWARE
macro tool set. Its use is restricted to current and former clients of
HOFFMAN CONSULTING as well as other professional colleagues. Questions
and suggestions may be sent to TRHoffman@sprynet.com.
-----------------------------------------------------------------------
Usage:

In all examples, assume that the calling macro defines the &list text
string.

1) Return last word as value of macro:
%put %parsem(&list) is the last variable in &list;

2) Return last word as value of macro variable:
%parsem(&list,word=lbyvar)
%put &lbyvar is the last variable in &list;

3) Return number of words as value of macro:
%put &list includes %parsem(&list,nwords=1) words;

4) Return number of words as value of macro variable:
%parsem(&list,nwords=nw)
%put &list includes &nw words;

5) Return all words:
%unquote(%parsem(&list,strip=all)
%do j=1 %to &n;
  word &j equals &&w&j;
%end;

6) Return the first two words:
%put %parsem(&list,strip=first,nstrip=2) are the first two words in &list;
------------------------------------------------------------------------
WARNING:

When using PARSEM in a command line tool, use the GSUB command to
submit the PARESM call. For example, gsub '%parsem(&list,nwords=nw)'.
Otherwise, SAS may crash with a 'segment violation' on UNIX or a
'HOST INTERNAL ERROR: 99' on Windows.
------------------------------------------------------------------------
Notes:

The WORD, REST, and NWORDS parameters cannot equal themselves. For
example, %parsem(word=word) returns an error message.

When the text string contains only one word, the value of &rest is null.

When the text string is null, the returned macro variables will be null.

The &rest variable includes any delimiters. Consecutive delimit
characters are returned as a single character.

When STRIP=ALL, the PARSEM macro must be called as the argument to the
UNQUOTE function.  If the WORD and NWORDS parameters are not set to
macro variable names, then the PARSEM macro returns macro variable N,
equal to the number of words, and W1,W2,...,W&n, equal to the individual
word values. The names of these macro variables can be changed by
specifying macro variable names for the the WORD and/or NWORDS
parameters.
-----------------------------------------------------------------------
History:

21JAN96 TRHoffman Creation
20APR99 TRHoffman Globalized WORD and REST when necessary.
06DEC99 TRHoffman Added NWORDS parameter. Added functionality to return
                  all words and to return the result as value of macro
                  rather than macro variable.
11APR00 TRHoffman Protected against empty string. Changed name of
                  string parameter. Added support for STRIP parameter
                  to equal number of words.
02JUN00 TRHoffman Added WARNING about command line usage.
14NOV00 TRHoffman Prevented returning last word when nwords parameter
                  was set to a macro variable.
----------------------------------------------------------------------*/
%local macro parmerr _n _w _r _mode j _word;
%let macro = parsem;

%*----------------------------------------------------------------------
Validate macro parameters
-----------------------------------------------------------------------;
%parmv(STRIP,_req=1,_val=FIRST LAST ALL)
%parmv(NSTRIP,_req=1,_val=POSITIVE)
%parmv(NWORDS,_req=1)
%if (&parmerr) %then %goto quit;

%*----------------------------------------------------------------------
Set parameter defaults.
Define _MODE and _LW variables.
-----------------------------------------------------------------------;
%if (&strip = ALL) %then %do;
  %if (&word =) %then %let word = w;
  %if (&nwords = 0) | (&nwords = 1) %then %let nwords = n;
  %let _mode = ALL;
%end;
%else %do;
  %if (&nwords = 1) %then %let _mode = NWORDS;
  %else %if (&word =) & (&rest =) & (&nwords = 0) %then %do;
    %let _mode = WORD;
    %let word = _word;
  %end;
%end;

%*----------------------------------------------------------------------
Set the default value of the delimiter.
-----------------------------------------------------------------------;
%if ^%length(&delimit) %then %let delimit = %str( );

%*----------------------------------------------------------------------
Partition string into words.
-----------------------------------------------------------------------;
%let _n = 0;
%do %until (^%length(&&_w&_n));
  %let _n = %eval(&_n + 1);
  %local _w&_n;
  %let _w&_n = %qscan(&_str_,&_n,&delimit);
%end;
%let _n = %eval(&_n - 1);
%if (&nstrip > &_n) %then %let nstrip = &_n;

%*----------------------------------------------------------------------
_mode = ALL
-----------------------------------------------------------------------;
%if (&_mode = ALL) %then %do;
  %if (%length(&word&_n) > 8) %then %do;
    %parmv(word,_msg=Length cannot exceed %eval(8-%length(&_n))
characters)
    %goto quit;
  %end;
  %nrstr(%let ) &nwords = &_n %str(;)
  %do j=1 %to &_n;
    %nrstr(%let ) &word&j = &&_w&j %str(;)
  %end;
  %goto quit;
%end;

%*----------------------------------------------------------------------
WORD specified
-----------------------------------------------------------------------;
%if (&word ^=) %then %do;
  %if (%upcase(&word) = WORD) %then %do;
    %parmv(word,_msg=WORD cannot equal itself)
    %goto quit;
  %end;
  %if ^%mvartest(&word) %then %do;
    %global &word;
  %end;
  %if (&_n = 0) %then %let &word =;
  %else %if (&strip = FIRST) %then %do j = 1 %to &nstrip;
    %if (&j = 1) %then %let &word = &_w1;
    %else %let &word = &&.&word.&delimit.&&_w&j;
  %end;
  %else %if (&strip = LAST) %then %do j = &_n-&nstrip+1 %to &_n;
    %if (&j = &_n-&nstrip+1) %then %let &word = &&_w&j;
    %else %let &word = &&.&word.&delimit.&&_w&j;
  %end;
%end;

%*----------------------------------------------------------------------
REST specified
-----------------------------------------------------------------------;
%if (&rest ^=) %then %do;
  %if (%upcase(&rest) = REST) %then %do;
    %parmv(rest,_msg=REST cannot equal itself)
    %goto quit;
  %end;
  %if ^%mvartest(&rest) %then
    %global &rest
  ; ;
  %if (&_n < 2) %then %let &rest =;
  %else %if (&nstrip = &_n) %then %let &rest =;
  %else %if (&strip = LAST) %then %do j = 1 %to &_n-&nstrip;
    %if (&j = 1) %then %let &rest = &_w1;
    %else %let &rest = &&.&rest.&delimit.&&_w&j;
  %end;
  %else %if (&strip=FIRST) %then %do j = &nstrip+1 %to &_n;
    %if (&j = &nstrip+1) %then %let &rest = &&_w&j;
    %else %let &rest = &&.&rest.&delimit.&&_w&j;
  %end;
%end;

%*----------------------------------------------------------------------
NWORDS specified
-----------------------------------------------------------------------;
%if ^(&nwords = 1 | &nwords = 0) %then %do;
  %if (%upcase(&nwords) = NWORDS) %then %do;
    %parmv(nwords,_msg=NWORDS cannot equal itself)
    %goto quit;
  %end;
  %if ^%mvartest(&nwords) %then
    %global &nwords
  ; ;
  %let &nwords = &_n;
%end;

%*----------------------------------------------------------------------
_mode = NWORDS
-----------------------------------------------------------------------;
%if (&_mode = NWORDS) %then
   &_n
;

%*----------------------------------------------------------------------
_mode = WORD
-----------------------------------------------------------------------;
%else %if (&_mode = WORD) & (&_n ^= 0) %then
  &_word
;

%quit:

%mend parsem;
