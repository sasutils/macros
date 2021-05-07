%macro dbcon
/*----------------------------------------------------------------------
Summarize the contents of a dataset.
----------------------------------------------------------------------*/
(data               /* Dataset name */
,maxchar=40         /* Maximum length of character variables */
,maxobs=100000      /* Maximum observations before using sampling */
,select=            /* Variable names to select for analysis */
,exclude=           /* Variable names to exclude from analysis */
,outval=_dbvals     /* Dataset name for values output */
,outsum=_dbvars     /* Dataset name for variable summary output */
,fname=             /* Fileref or filename in quotes for text file */
,nval=10            /* Number of distinct values to print */
,printn=0           /* Include value frequency when text file is made */
);
/*----------------------------------------------------------------------


Calls: parmv.sas qlist.sas contentv.sas nobs.sas

Usage notes:
This macro will potentially generate a very large work dataset to
contain all of the possible values. To reduce the size of this dataset
and reduce processing time you can use these options:

 -   Use the SELECT and/or EXCLUDE options to limit the variables that
     will be summarized.

 -   Use the MAXCHAR option to truncate long character variables.

 -   Set MAXOBS to a value > 0.  This will cause macro to sample the
     dataset when there are more than MAXOBS observations.

----------------------------------------------------------------------*/
%local macro parmerr nobs sample varlist maxlen flen trunc anynum anychar;
%let macro=&sysmacroname;
%parmv(data,_req=1)
%parmv(nval,_val=positive,_def=10)
%parmv(maxchar,_val=nonnegative,_def=40)
%parmv(exclude,_words=1)
%parmv(select,_words=1)
%parmv(outval,_req=1)
%parmv(outsum,_req=1)
%parmv(maxobs,_val=nonnegative)
%parmv(printn,_val=0 1)

%if (&parmerr) %then %goto quit;

%nobs(&data);
%if (&nobs < 0 ) %then %do;
  %parmv(DATA,_msg=Dataset not found)
  %goto quit;
%end;
*----------------------------------------------------------------------;
* Get attributes for variables in the input dataset ;
*----------------------------------------------------------------------;
%contentv(&data,out=dsinfo,genfmt=0)

*----------------------------------------------------------------------;
* Reduce to variables of interest and find maximum length char var ;
*----------------------------------------------------------------------;
proc sql noprint;
  create table dsinfo as
   select libname,memname,name,varnum,type,length,format,label
    from dsinfo
    where 1
%if %length(&select) %then
    & upcase(name) in %qlist(&select)
;
%if %length(&exclude) %then
    & upcase(name) ^in %qlist(&exclude)
;
   order name
  ;
  select name into :varlist separated by ' ' from dsinfo;
  select max(length),max(type='num'),max(type='char')
    into :maxlen,:anynum,:anychar
    from dsinfo
;
quit;
%if (^%length(&varlist)) %then %do;
  %parmv(_msg=No variables selected from &data)
  %goto quit;
%end;


%let sample=0;
%if (&maxobs and (&nobs > &maxobs)) %then %do;
*----------------------------------------------------------------------;
* NOTE: When dataset is large then only take a sample of the data ;
*----------------------------------------------------------------------;
  %let sample=%sysfunc(ceil(&nobs/&maxobs));
  %put NOTE: &data has &nobs observations. This macro will only read
every &sample.th observation.;
%end;

%*---------------------------------------------------------------------
When MAXCHAR is specified then use instead of the actual max length.
Set TRUNC flag to indicate that values have been truncated.
-----------------------------------------------------------------------;
%let trunc=0;
%if (&maxchar and (&maxchar < &maxlen)) %then %do;
  %let trunc=1;
  %let maxlen=&maxchar;
%end;

*----------------------------------------------------------------------;
* Get values for all variables into tall skinny table. ;
*----------------------------------------------------------------------;
data &outval(rename=(__name=name __cvalue=cvalue __value=value));
  set &data(keep=&varlist);
  keep __name __cvalue __value;
%if (&sample) %then %do;
  if (mod(_n_,&sample) = 0);
%end;
%if (&anychar) %then %do;
  array _c _character_;
%end;
%if (&anynum) %then %do;
  array _n _numeric_;
%end;
  length __name $32 __value 8 __cvalue $&maxlen;
  format __value best12.;
%if (&anychar) %then %do;
  __value=.;
  do _i = 1 to dim(_c);
    call vname(_c{_i},__name);
    __name = upcase(__name);
    __cvalue = _c{_i};
    output;
  end;
%end;
%if (&anynum) %then %do;
  __cvalue = '';
  do _i = 1 to dim(_n);
    call vname(_n{_i},__name);
    __name = upcase(__name);
    __value = _n{_i};
    output;
  end;
%end;
run;

*----------------------------------------------------------------------;
* Summarize to unique values and frequency. ;
*----------------------------------------------------------------------;
proc summary data=&outval nway missing;
  class name value cvalue / groupinternal;
  output out=&outval(keep=name value cvalue _freq_);
run;

%if (^&trunc) %then %do;
*----------------------------------------------------------------------;
* Calculate maximum actual length of character variables ;
*----------------------------------------------------------------------;
  proc sql noprint;
    create table _maxlen as
      select name,max(length(cvalue)) as maxlen
      from &outval
      where cvalue ne ' '
      group by name
    ;
  quit;
%end;

*----------------------------------------------------------------------;
* Count number of unique values for each name.;
*----------------------------------------------------------------------;
proc summary data=&outval nway;
  by name;
  var _freq_;
  output max=maxfreq
    out=&outsum(keep=name _freq_ maxfreq rename=(_freq_=nval))
  ;
run;

*----------------------------------------------------------------------;
* Combine the attribute information with number of distinct values and ;
* keep the actual first value. ;
*----------------------------------------------------------------------;
data &outsum;
  merge
    dsinfo
    &outsum
    &outval(drop=_freq_)
%if (^&trunc) %then _maxlen;
  ;
  by name;
  if first.name;
  if nval=1 and ((type='char' and cvalue=' ') or
                 (type='num' and value=.)) then nval=0;
  label value='First value (numeric)'
       cvalue='First value (character)'
        nval ='Number of distinct values (0=all missing)'
      maxfreq='Frequency of most frequent value'
       maxlen='Maximum length of character data'
  ;
%if (&trunc) %then %do;
  maxlen=.;
%end;

run;


%if (%length(&fname)) %then %do;
/*----------------------------------------------------------------------
When FNAME is supplied then write summary to output text file.
For names with more than &NVAL unique values, only list &nval values
(half each from the start and the end) are listed.
When PRINTN is requested then frequency count for each value will be
printed before the values.
When formatted value is different than the raw value then the formatted
value is printed after the raw value.
----------------------------------------------------------------------*/

%*----------------------------------------------------------------------
Round NVAL up to next even number
-----------------------------------------------------------------------;
%if %sysfunc(mod(&nval,2)) %then %do;
  %let nval=%eval(&nval+1);
  %put NOTE: Rounding NVAL up to even number &nval..;
%end;

%if (&printn) %then %do;
*----------------------------------------------------------------------;
* Determine characters needed to display frequencies using COMMA format;
*----------------------------------------------------------------------;
  proc sql noprint;
    select max(maxfreq) into :flen from &outsum;
  quit;
  %let flen=%sysfunc(max(&flen,&flen),comma32.);
  %let flen=&flen;
  %let flen=%length(&flen);
%end;

data _null_;
  merge &outsum &outval;
  by name;
  file &fname;
  if (_n_=1) then put
     '~' 69*'='
   / memname "NOBS=&nobs [Display limited to &nval values]"
%if (&trunc) %then " <Max length &maxlen>" ;
   / 70*'='
  ;
  if (first.name) then do;
    k = 1;
%if (&printn) %then %do;
    put @&flen 'N ' @;
%end;
    put name 'LEN=' @;
    if type='char' then put '$'@;
    put length nval= @;
    if maxlen ne . then put maxlen= @;
    if format ne ' ' then put format= @;
    if name ne label and label ne ' ' then put label= @;
    put ;
    if nval then put 70*'-';
  end;
  else k + 1;
  if nval=0 then out=0;
  else if nval<= &nval+1 then out=1;
  else out = (k <= ceil(&nval/2)) | (nval - k < ceil(&nval/2));
  if (out);
%if (&printn) %then %do;
  put _freq_ comma&flen.. +1 @;
%end;
  if (type = 'num') then do;
    if (format = '') then put value best12.;
    else do;
      cvalue = putn(value,format);
      if (input(cvalue,??best12.) ^= value) then put value best12. +1 cvalue;
      else put value best12.;
    end;
  end;
  else do;
    put cvalue @;
    if (compress(format,'$1234567890.') ^= '') then do;
      fcvalue = left(putc(cvalue,format));
      if (fcvalue ^= cvalue) then put @&maxlen+1 fcvalue;
      else put;
    end;
    else put;
  end;
  if (nval > &nval+1) & (k = ceil(&nval/2)) then put
%if (&printn) %then &flen*'.' '.' ;
    '............'
  ;
  if (last.name) then put 70*'_';
run;

%end;
%quit:
%mend dbcon;
