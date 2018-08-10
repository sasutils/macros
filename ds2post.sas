%macro ds2post
/*----------------------------------------------------------------------------
Generate data step to post content of dataset on SAS Communities
----------------------------------------------------------------------------*/
(data     /* Name of dataset to post *REQ*  */
,target=  /* Name to use in generated data step. (default is memname of &DATA) */
,obs=20   /* Number of observations to generate */
,file=log /* Fileref or quoted physical name of file to hold generated code */
,format=  /* Optional format list to use when generating data lines */
);
%local _error noformats;
%*---------------------------------------------------------------------------
Check user parameters.
----------------------------------------------------------------------------;
%let _error=0;
%if "%upcase(%qsubstr(&data,1,2))" = "-H" %then %let _error=1;
%else %if %length(&data) %then %do;
  %if not (%sysfunc(exist(%qscan(&data,1,())))
        or %sysfunc(exist(%qscan(&data,1,()),view))) %then %do;
    %let _error = 1;
    %put ERROR: "&data" is not a valid value for the DATA parameter.;
    %put ERROR: Unable to find the dataset. ;
  %end;
%end;
%else %do;
  %let _error = 1;
  %put ERROR: The DATA parameter is required.;
%end;
%if not %length(&target) %then %let target=%qscan(%qscan(&data,1,()),-1,.);
%if not %length(&obs) %then %let obs=20;
%else %let obs=%upcase(&obs);
%if "&obs" ne "MAX" %then %if %sysfunc(verify(&obs,0123456789)) %then %do;
  %let _error = 1;
  %put ERROR: "&obs" is not a valid value for the OBS parameter.;
  %put ERROR: Valid values are MAX or non-negative integer. ;
%end;
%if not %length(&file) %then %let file=log;

%if (&_error) %then %do;
*----------------------------------------------------------------------------;
* When there are parameter issues then write instructions to the log. ;
*----------------------------------------------------------------------------;
data _null_;
  put
  '%DS2POST'
//'SAS macro to copy data into a SAS Data Step in a '
  'form which you can post to on-line forums.'
//'Syntax:'
/ ' %ds2post(data=,target=,obs=,format=,file=)'
//' data   = Name of SAS dataset (or view) that you want to output.'
//' target = Name to use for generated dataset.'
  ' Default is to use name of the input.'
//' obs    = Number of observations to output. Use MAX to copy complete dataset.'
  ' Default is 20.'
//' file   = Fileref or quoted physical filename for code.'
  ' Default is the SAS log.'
//' format = Optional list of <var_list> <format spec> pairs to use when writing'
  ' data lines.' ' Setting format=_all_ will clear all formats so raw data'
  ' values are written.'
//'Note that this macro will NOT work well for really long data lines.'
 /'If your data has really long variables or a lot of variables then consider'
  ' splitting your dataset in order to post it.'
  ;
run;
%end;
%else %do;
*----------------------------------------------------------------------------;
* Get contents information and sort by VARNUM ;
*----------------------------------------------------------------------------;
proc contents noprint data=&data
  out=_contents_(keep=name varnum type length format: inform: memlabel label)
;
run;
proc sort data=_contents_ ;
  by varnum;
run;
*----------------------------------------------------------------------------;
* Generate top of data step ;
*----------------------------------------------------------------------------;
filename _code_ temp;
data _null_;
  length firstvar name $60 string $300 ;
  retain firstvar ;
  file _code_ column=cc ;
  set _contents_ end=eof ;
  if _n_=1 then do;
    put "data &target" @;
    if not missing(memlabel) then do;
      string=quote(trim(memlabel),"'");
      put '(label=' string ')' @;
    end;
    put ';';
  end;
  name=nliteral(name) ;
  if _n_=1 then firstvar=name;
  string=cats(ifc(type=2,'$',' '),length);
  put '  attrib ' name 'length=' string @;
  if formatl or not missing(format) then do;
     string=cats(format,ifc(formatl,cats(formatl),''),'.',ifc(formatd,cats(formatd),''));
     put 'format=' string @ ;
  end;
  if informl or not missing(informat) then do;
     string=cats(informat,ifc(informl,cats(informl),''),'.',ifc(informd,cats(informd),''));
     if cc+9+length(string)>80 then put / @4 @ ;
     put 'informat=' string @ ;
  end;
  if not missing(label) then do;
     string=quote(trim(label),"'");
     if cc+7>80 then put / @4 'label=' string @ ;
     else if cc+7+length(string)>80 then put 'label=' / @4 string @ ;
     else  put 'label=' string @;
  end;
  put ';' ;
  if eof then do;
     put "  infile datalines dsd dlm='|' truncover;" ;
     put '  input ' firstvar '-- ' name ';';
     put 'datalines4;' ;
  end;
run;
*----------------------------------------------------------------------------;
* Generate list of variables that do not have attached informats. ;
*----------------------------------------------------------------------------;
proc sql noprint;
  select name into :noformats separated by ' '
    from _contents_ where missing(informat)
  ;
quit;
*----------------------------------------------------------------------------;
* Generate data lines ;
*----------------------------------------------------------------------------;
data _null_;
  file _code_ mod dsd dlm='|';
%if (&obs ne MAX) %then %do;
  if _n_ > &obs then stop;
%end;
  set &data ;
%if %length(&noformats) %then %do;
  format &noformats ;
%end;
%if %length(&format) %then %do;
  format &format ;
%end;
  put (_all_) (+0) ;
run;
data _null_;
  file _code_ mod ;
  put ';;;;';
run;
  %if "%qupcase(&file)" ne "_CODE_" %then %do;
*----------------------------------------------------------------------------;
* Copy generated code to target file name ;
*----------------------------------------------------------------------------;
data _null_ ;
  infile _code_;
  file &file ;
  input;
  put _infile_;
run;
  %end;
%end;
%mend ds2post ;
