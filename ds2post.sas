%macro ds2post
/*----------------------------------------------------------------------------
Generate data step suitable for on-line posting to create an existing dataset
----------------------------------------------------------------------------*/
(data   /* Name of input (def=&syslast Use data=-help to see syntax in log)*/
,file   /* Fileref or quoted physical name of where to write code (def=LOG) */
,obs    /* Number of observations to include. Use obs=max for all (def=20) */
,target /* Dataset name to create. (def=memname of input dataset) */
);
/*----------------------------------------------------------------------------
You can use this macro to create a data step for sharing an example of your
existing data.  It will create a data step that will re-create the existing
dataset variables formatting (including the order, type, length, format,
informat and label) and data by reading from in-line delimited data lines.

OBS=MAX will dump all of the data. Default is the first 20 observations.

You can use the TARGET parameter to change the dataset name used in the
generated code. By default it will create a work dataset with the same
member name as the input dataset.

For the FILE parameter you can use either a fileref or a quoted physical
filename.  Note that if you provide an unquoted value that is not a fileref
then the macro will assume you meant to use that as the physical name of the
file.  The macro uses the fileref of _CODE_ for the temporary file it uses
to generate the code into. So if you call it with FILE=_CODE_ it will leave
the generated program in that temporary file.

The data step will have INPUT, LENGTH, FORMAT, INFORMAT and LABEL statements
(when needed) in that order.

To insure that data transfers correctly in spite of the potential of variables
with mismatched FORMAT and INFORMAT in the source dataset the values will be
written using raw data format.  In the generated INPUT statement all
character variables will use $ informat (setting their length) and any numeric
format that uses an informat other the default informat will include :F.
informat in the INPUT statement.

A LENGTH statement will only be generated for numeric variables with length
less than 8. Numeric variables of length 2 (valid only on IBM Mainframes) will
be set to length 3 instead. The length of characters variables will be set by
the informat used in the INPUT statement.

There are some limits on its ability to replicate exactly the data you have,
mainly due to the use of delimited data.

- Leading spaces on character variables are not preserved.
- Embedded CR or LF in character variables will cause problems.
- There could be slight (E-14) rounding of floating point numbers

Also in-line data is not that suitable for really long data lines. In that
case you could get better results by copying the data lines to a separate
file and modifing the data step to read from that file instead of in-line
data.
------------------------------------------------------------------------------
Examples:
* Pull macro definition from GITHUB and dump code to the SAS log ;
filename ds2post url
  'https://raw.githubusercontent.com/sasutils/macros/master/ds2post.sas'
;
%include ds2post ;
%ds2post(sashelp.class)

* Dump code to the results window ;
%ds2post(sashelp.class,file=print)

* Dump complete dataset to an external file ;
%ds2post(mydata,obs=max,file="mydata.sas")

----------------------------------------------------------------------------*/
%local _error ll libname memname memlabel;
%*---------------------------------------------------------------------------
Set maximum line length to use for wrapping the generated SAS statements.
----------------------------------------------------------------------------;
%let ll=72 ;

%*---------------------------------------------------------------------------
Check user parameters.
----------------------------------------------------------------------------;
%let _error=0;
%if "%upcase(%qsubstr(&data.xx,1,2))" = "-H" %then %let _error=1;
%else %do;
  %if not %length(&data) %then %let data=&syslast;
  %if not (%sysfunc(exist(&data)) or %sysfunc(exist(&data,view))) %then %do;
    %let _error = 1;
    %put ERROR: "&data" is not a valid value for the DATA parameter.;
    %put ERROR: Unable to find the dataset. ;
  %end;
  %else %do;
    %let memname=%upcase(%scan(&data,-1,.));
    %let libname=%upcase(%scan(work.&data,-2,.));
  %end;
%end;
%if not %length(&file) %then %let file=log;
%else %if %sysfunc(indexc(&file,%str(%'%"))) or %length(&file)>8 %then
   %let file=%sysfunc(quote(%qsysfunc(dequote(&file)),%str(%')));
%else %if %sysfunc(indexw(LOG _CODE_ PRINT,%upcase(&file),%str( ))) %then ;
%else %if %sysfunc(fileref(&file))<=0 %then ;
%else %let file=%sysfunc(quote(&file,%str(%')));
%if not %length(&obs) %then %let obs=20;
%else %let obs=%upcase(&obs);
%if "&obs" ne "MAX" %then %if %sysfunc(verify(&obs,0123456789)) %then %do;
  %let _error = 1;
  %put ERROR: "&obs" is not a valid value for the OBS parameter.;
  %put ERROR: Valid values are MAX or non-negative integer. ;
%end;
%if not %length(&target) %then %let target=work.%qscan(&data,-1,.);

%if (&_error) %then %do;
*----------------------------------------------------------------------------;
* When there are parameter issues then write instructions to the log. ;
*----------------------------------------------------------------------------;
data _null_;
  put
  '%DS2POST' ' - SAS macro to copy data into a SAS Data Step in a '
  'form which you can post to on-line forums.'
//'Syntax:' ' %ds2post(data,file,obs,target)'
//' data   = Name of SAS dataset (or view) that you want to output.'
  ' Default is last created dataset.' ' Use data=-help to print instructions.'
//' file   = Fileref or quoted physical filename for code.'
  ' Default of file=log will print code to the SAS log.'
  ' file=print will print code to results.'
//' obs    = Number of observations to output. Default obs=20.'
  ' Use obs=MAX to copy complete dataset.'
//' target = Name to use for generated dataset.'
  ' Default is to make work dataset using the name of the input.'
//'For more information see source code available on github at '
 /'https://raw.githubusercontent.com/sasutils/macros/master/ds2post.sas'
  ;
run;
%end;
%else %do;
*----------------------------------------------------------------------------;
* Get member label in format of dataset option. ;
* Get dataset contents information in a format to facilitate code generation.;
* Column names reflect data statement that uses the value. ;
*----------------------------------------------------------------------------;
proc sql noprint;
  select cats('(label=',quote(trim(memlabel),"'"),')')
    into :memlabel trimmed
    from dictionary.tables
    where libname="&libname" and memname="&memname" and not missing(memlabel)
  ;
  create table _ds2post_ as
    select varnum
         , nliteral(name) as name length=66
         , substrn(informat,1,findc(informat,' .',-49,'kd')) as inf length=32
         , case when type='char' then cats(':$',length,'.')
                when not (lowcase(calculated inf) in ('best','f',' ')
                     and scan(informat,2,'.') = ' ') then ':F.'
           else ' ' end as input length=8
         , case when type='num' and length < 8 then cats(max(3,length))
           else ' ' end as length length=1
         , lowcase(format) as format length=49
         , lowcase(informat) as informat length=49
         , case when missing(label) then ' ' else quote(trim(label),"'")
           end as label length=300
    from dictionary.columns
    where libname="&libname" and memname="&memname"
    order by varnum
  ;
quit;
*----------------------------------------------------------------------------;
* Generate data step code ;
* - For each statement use value of variable named the same as the statement.;
* - Only variables that are required in that statement are generated. ;
* - For LABEL statement use = between name and value instead of space. ;
* - Wrap statements when lines get too long. ;
* - Eliminate statements when no variables required that statement. ;
*----------------------------------------------------------------------------;
filename _code_ temp;
data _null_;
  file _code_ column=cc ;
  set _ds2post_ (obs=1) ;
  put "data &target &memlabel;" ;
  put @3 "infile datalines dsd dlm='|' truncover;" ;
  length statement $32 string $351 ;
  do statement='input','length','format','informat','label';
    call missing(any,anysplit);
    put @3 statement @ ;
    do p=1 to nobs ;
      set _ds2post_ point=p nobs=nobs ;
      string=vvaluex(statement);
      if statement='input' or not missing(string) then do;
        any=1;
        string=catx(ifc(statement='label','=',' '),name,string);
        if &ll<(cc+length(string)) then do;
          anysplit=1;
          put / @5 @ ;
        end;
        put string @ ;
      end;
    end;
    if anysplit then put / @3 @ ;
    if not any then put @1 10*' ' @1 @ ;
    else put ';' ;
  end;
  put 'datalines4;' ;
run;
*----------------------------------------------------------------------------;
* Generate data lines ;
*----------------------------------------------------------------------------;
data _null_;
  file _code_ mod dsd dlm='|';
%if (&obs ne MAX) %then %do;
  if _n_ > &obs then stop;
%end;
  set &data ;
  format _numeric_ best32. _character_ ;
  put (_all_) (+0) ;
run;
data _null_;
  file _code_ mod ;
  put ';;;;';
run;
%if "%qupcase(&file)" ne "_CODE_" %then %do;
*----------------------------------------------------------------------------;
* Copy generated code to target file name and remove temporary file. ;
*----------------------------------------------------------------------------;
data _null_ ;
  infile _code_;
  file &file ;
  input;
  put _infile_;
run;
filename _code_ ;
%end;
*----------------------------------------------------------------------------;
* Remove generated metadata. ;
*----------------------------------------------------------------------------;
proc delete data=_ds2post_;
run;
%end;
%mend ds2post ;
