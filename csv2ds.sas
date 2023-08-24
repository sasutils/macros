%macro csv2ds
/*----------------------------------------------------------------------
Convert a delimited text file into a SAS dataset
----------------------------------------------------------------------*/
(filen        /* Input fileref or quoted physical filename  */
              /* Extra FILE statement options like LRECL allowed */
,out=fromcsv  /* Output dataset name */
,dlm=         /* Delimiter character. (Default=COMMA) */
              /* Special keywords : TAB PIPE COMMA SEMICOLON */
              /* Single character (Examples: dlm=| or dlm=^)  */
              /* Two digit HEX code (dlm=09 is same as dlm=TAB  */
,getnames=    /* File includes headerline? (0/1) def=YES */
,namerow=     /* Row to read for names (default=1) */
,datarow=     /* First line to read as data (def=NAMEROW+1) */
,obs=         /* Number of data lines to read */
,guessingrows=/* Number of rows used in guessing. (def=MAX) */
,percent=     /* Percent of rows sampled in guessing. (def=ALL) */
,replace=no   /* Automatically replace existing dataset? (0/1) */
,overrides=   /* Name of SAS datasets with metadata overides (optional) */
,maxchar=     /* Maximum length for character variables */
,missing=     /* Special missing values allowed in numeric fields */
,run=yes      /* Run the generated code? (0/1) */
);
/*----------------------------------------------------------------------
Convert a delimited text file into a SAS dataset

Calls to: parmv.sas
-----------------------------------------------------------------------
Usage notes:

Will create the following work datasets/views ;

NAME     TYPE DESCRIPTION
-------- ---- -------------------------------------------------------
_NAMES_  DATA List of names generated from header row
_VALUES_ VIEW View to create tall table of all non-null values
_TYPES_  DATA Variable metadata calculated and used to generate code

Will create the fileref _CODE_ to hold the generated data step code.

The delimiter (DLM) can be specified in one of three ways.
1) Special keywords TAB PIPE COMMA or SEMICOLON
2) Single character or quoted single character
3) Two digit hexadecimal number for the character.
When DLM is not specified then a comma is used as the delimiter.

The OVERRIDES dataset can be used to set metadata used to generate the
code. Only the VARNUM varaible is required and the dataset must be sorted
by VARNUM. The values of INFORMAT and FORMAT must include the period.
Since file is read using list mode input there is no need to include a
width on the INFORMAT.  Do not include decimal places on INFORMAT unless
you want INPUT to divide values without periods by that power of 10.

  NAME     LEN  Description
  -------- ---- -------------------------------------------------
  varnum   8    Column order (req)
  name     $32  Variable name
  length   $6   LENGTH as required for LENGTH statement
  informat $43  INFORMAT specification used to read from file
  format   $43  FORMAT to attach to variable in the dataset
  label    $256 LABEL to attach to variable

Differences from PROC IMPORT
- Supports header lines with more than 32,767 characters
- Supports ZIP and GZIP source files
- Generates unique variable names by adding numeric suffix
- Does not overestimate maxlength when longest value is quoted
- Does NOT force character type if all values are quoted
- Generates label when generated variable name is different than header
- Supports NAMEROW option
- Supports numeric fields with special missing values (MISSING statement)
- Does not attach unneeded informats or formats
- Allows overriding calculated metadata
- Allow using random sample of rows to guess metadata
- Generates more compact SAS code
- Generates analysis summary dataset and raw data view
- Saves generated SAS code to a file
- Forces DATE and DATETIME formats to show century
- Difference in generated V7 compatible variable names
  - Replaces adjacent non-valid characters with single underscore


$Examples:

* Convert CSV file to default dataset ;
%csv2ds("myfile.csv");

* Use FILEREF to reference the file, name output dataset ;
filename csv "myfile.csv";
%csv2ds(csv,out=test);

* Use larger LRECL for file  ;
%csv2ds("myfile.csv" lrecl=1000000);

* Convert ZIP compressed file ;
%csv2ds("myfiles.zip" zip member="myfile.csv")

* Convert GZIP compressed file ;
%csv2ds("myfile.csv.gz" zip gzip)

-----------------------------------------------------------------------
Modification History
-----------------------------------------------------------------------
Revision n.x  yyyy/mm/dd hh:mm:ss  username
Revision 1.1  2021/10/13 13:50:00  abernt   Initial revision

----------------------------------------------------------------------*/
%local macro parmerr dt file fileopt rc optsave misssave nameobs dataobs;
%let macro=CSV2DS;
%let dt=%sysfunc(datetime());

%*----------------------------------------------------------------------------
Validate parameters
-----------------------------------------------------------------------------;
%if 0=%length(&filen) %then %parmv(FILEN,_req=1);
%else %do;
  %let file=%qscan(&filen,1,%str( ),q);
  %let fileopt=%substr(&filen%str( ),%length(&file)+1);
  %let rc=1;
  %if %length(&file)<=8 %then %if %sysfunc(nvalid(&file)) %then %do;
    %let rc=%sysfunc(fileref(&file));
    %if &rc<=0 %then %let file=%upcase(&file);
    %if &rc<0 %then %parmv(FILEN,_msg=
       File pointed to by fileref &file not found)
    ;
  %end;
  %if &rc>0 %then %if %sysfunc(fileexist(&file)) %then
    %let file=%sysfunc(quote(%qsysfunc(dequote(&file)),%str(%')))
  ;
  %else %parmv(FILEN,_msg=File not found);
%end;
%parmv(OUT,_case=n)
%parmv(GETNAMES,_val=0 1,_def=1)
%parmv(namerow,_val=nonnegative)
%parmv(datarow,_val=nonnegative)
%if %qupcase("&guessingrows")="MAX" %then %let guessingrows=0;
%else %parmv(GUESSINGROWS,_val=nonnegative,_def=0);
%parmv(PERCENT,_val=positive)
%parmv(OBS,_val=positive)
%parmv(REPLACE,_val=0 1)
%parmv(OVERRIDES)
%parmv(MAXCHAR,_val=positive,_def=32767)
%parmv(RUN,_val=0 1,_def=1)
%parmv(MISSING)

%*----------------------------------------------------------------------------
Check DLM parameter and convert to string usable in INFILE statement.
-----------------------------------------------------------------------------;
%if %length(&dlm)=3 %then %let dlm=%qsysfunc(dequote(&dlm));
%if %length(&dlm)=0 %then %let dlm=',';
%else %if %length(&dlm)=1 %then %let dlm=%unquote(%bquote('&dlm'));
%else %if %length(&dlm)=2 and
  0=%sysfunc(verify(%upcase(&dlm),0123456789ABCDEF)) %then %do;
  %let dlm=%unquote(%bquote('&dlm'x));
%end;
%else %if (%qupcase(&dlm)=TAB) %then %let dlm='09'x;
%else %if (%qupcase(&dlm)=COMMA) %then %let dlm=',';
%else %if (%qupcase(&dlm)=PIPE) %then %let dlm='|';
%else %if (%qupcase(&dlm)=SEMICOLON) %then %let dlm=';';
%else %parmv(DLM,_msg=Valid values include: a single character%str(,)
 two digit hexcode%str(,)
 keyword: TAB COMMA PIPE or SEMICOLON)
;

%if (&parmerr) %then %goto quit;

%if %sysfunc(verify("&missing","_ABCDEFGHIJKLMNOPRSTUVWXYZ")) %then
  %parmv(MISSING,_msg=Only valid characters are _ABCDEFGHIJKLMNOPRSTUVWXYZ)
;
%if %length(&percent) %then %if 100<&percent %then
  %parmv(PERCENT,_msg=Value must be between 1 and 100)
;
%if %length(&overrides) %then %if not %sysfunc(exist(&overrides)) %then
  %parmv(OVERRIDES,_msg=Dataset not found)
;
%if %sysfunc(exist(&out)) and "&replace"="0" and "&run"="1" %then
  %parmv(_msg=Import cancelled.  Output dataset &out already exists.
 Specify REPLACE option to overwrite it. Or set RUN=no)
;
%if (&parmerr) %then %goto quit;

%*----------------------------------------------------------------------------
Default NAMEROW and DATAROW based on GETNAMES option
Create NAMEOBS and DATAOBS macro variables with FIRSTOBS= and OBS= values to
make code generation easier.
-----------------------------------------------------------------------------;
%if ^%length(&namerow) %then %let namerow=&getnames;
%if ^%length(&datarow) %then %let datarow=%eval(&namerow+1);
%let nameobs=firstobs=&namerow obs=&namerow;
%let dataobs=firstobs=&datarow;
%if %length(&obs) %then %let dataobs=&dataobs obs=%eval(&datarow+&obs);

*----------------------------------------------------------------------------;
* Save current MISSING statement settings and issue new MISSING statement ;
*----------------------------------------------------------------------------;
data _null_;
  missing='_ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  do i=1 to 27;
    if .=input(char(missing,i),??1.) then substr(missing,i,1)=' ';
  end;
  call symputx('misssave',compress(missing,' '));
run;
missing &missing;

*----------------------------------------------------------------------------;
* Read the header row of the delimited file as labels ;
*----------------------------------------------------------------------------;
data _names_;
  length varnum 8 name $32 label $256 ;
%if (&getnames) %then %do;
  infile &file &fileopt dsd dlm=&dlm &nameobs ;
  varnum+1;
  retain name ' ';
  input label @@ ;
%end;
%else %do;
  stop;
  call missing(of _all_);
%end;
run;

*----------------------------------------------------------------------------;
* Generate _VALUES_ view with row, varnum, length, and first 40 bytes ;
*----------------------------------------------------------------------------;
%if %sysfunc(exist(_values_)) %then %do;
  proc sql; drop table _values_; quit;
%end;
data _values_(keep=row varnum length short) / view=_values_;
  infile &file &fileopt dsd dlm=&dlm truncover length=ll column=cc &dataobs ;
  length row varnum length 8 short $40 value $&maxchar ;
  row+1;
  input @;
%if %length(&percent) %then %do;
  if rand('Uniform')<=%sysfunc(putn(&percent/100,4.2)) ;
%end;
  do varnum=1 by 1 while(cc<=ll);
    start=cc;
    input short @ ;
    length=cc-start-1;
    if 0=length then continue;
    if length<=40 then length=lengthn(short);
    else do;
       input @start value @ ;
       len2=lengthn(value);
       if len2 < %eval(&maxchar-1) then length=len2;
    end;
    if length then output;
  end;
%if (&guessingrows) %then %do;
  if row >= &guessingrows then stop;
%end;
run;

*----------------------------------------------------------------------------;
* Summarize values and determine best fit xtype and appropriate informats or ;
* formats to attach to the variables. ;
*----------------------------------------------------------------------------;
proc sql ;
create table _types_ as
  select coalesce(a.varnum,b.varnum) as varnum
       , a.name
       , case
          when (missing(b.nonmiss)) then 'empty'
          when (b.maxlength in (1:15) and b.nonmiss=b.integer) then 'integer'
          when (b.nonmiss=b.integer) then 'character'
          when (b.maxlength in (1:32) and b.nonmiss=b.numeric) then 'numeric'
          when (b.maxlength in (1:32) and b.nonmiss=b.comma) then 'comma'
          when (b.maxlength in (1:40) and b.nonmiss=b.datetime and b.time ne b.nonmiss) then 'datetime'
          when (b.maxlength in (1:32) and b.nonmiss=b.date) then 'date'
          when (b.maxlength in (1:10) and b.nonmiss=b.yymmdd) then 'yymmdd'
          when (b.maxlength in (1:10) and b.nonmiss=b.mmddyy) then 'mmddyy'
          when (b.maxlength in (1:10) and b.nonmiss=b.ddmmyy) then 'ddmmyy'
          when (b.maxlength in (1:35) and b.nonmiss=b.e8601dz) then 'e8601dz'
          when (b.maxlength in (1:40) and b.nonmiss=b.anydtdtm and b.nonmiss ne b.time) then 'anydtdtm'
          when (b.maxlength in (1:32) and b.nonmiss=b.time) then 'time'
          else 'character'
         end as xtype length=9
       , case when calculated xtype in ('empty' 'character') then 'char'
              else 'num'
         end as type length=4
       , case when calculated xtype='empty' then '$1'
              when calculated xtype ='character' then cats('$',max(1,b.maxlength))
              else '8'
         end as length length=6
       , case when calculated xtype in ('integer' 'numeric' 'character' 'empty') then ' '
              else cats(calculated xtype,'.')
         end as informat length=43
       , case
              when calculated xtype in ('character' 'empty') then ' '
              when calculated xtype='integer' then
                 case when b.maxlength>1 and char(b.min,1)='0' and b.maxlength=b.minlength
                           then cats('z',maxlength,'.')
                      when b.maxlength>12 then cats('f',maxlength,'.')
                      else ' '
                 end
              when calculated xtype='numeric' then
                 case when b.maxlength>12 then cats('best',maxlength,'.') else ' ' end
              when calculated xtype='datetime' then cats('datetime',max(b.maxlength,19),'.')
              when calculated xtype='date' then 'date9.'
              when calculated xtype in ('anydtdtm') then 'datetime19.'
              when calculated xtype in ('mmddyy','ddmmyy','yymmdd') then cats(calculated xtype,'10.')
              else cats(calculated xtype,b.maxlength,'.')
         end as format length=43
       , a.label length=256
       , b.minlength
       , b.maxlength
       , b.min
       , b.max
       , coalesce(b.nonmiss,0) as nonmiss
       , b.numeric
       , b.comma
       , b.integer
       , b.date
       , b.datetime
       , b.time
       , b.yymmdd
       , b.mmddyy
       , b.ddmmyy
       , b.e8601dz
       , b.anydtdtm
  from _names_ a full join
( select varnum
       , count(*) as nonmiss
       , min(length) as minlength
       , max(length) as maxlength
       , sum(case when length<=32 then (. ne input(short,?32.)) else 0 end)
          as numeric
       , sum(case when length<=32 then (. ne input(compress(short,'($,)'),?32.)) else 0 end)
          as comma
       , sum(case when length<=32 and not missing(input(short,?32.))
                  then int(input(short,?32.))= input(short,?32.)
                  else 0 end)
          as integer
       , sum(case when length<=32 then not missing(input(short,?date32.)) else 0 end)
          as date
       , sum(case when length<=40 then not missing(input(short,?datetime40.)) else 0 end)
          as datetime
       , sum(case when length<=32 and indexc(short,':') in (2 3) then not missing(input(short,?time32.)) else 0 end)
          as time
       , sum(case when length<=10 then not missing(input(short,?yymmdd10.)) else 0 end)
          as yymmdd
       , sum(case when length<=10 then not missing(input(short,?mmddyy10.)) else 0 end)
          as mmddyy
       , sum(case when length<=10 then not missing(input(short,?ddmmyy10.)) else 0 end)
          as ddmmyy
       , sum(case when length<=35 then not missing(input(short,?e8601dz35.)) else 0 end)
          as e8601dz
       , sum(case when length<=40 then not missing(input(short,?anydtdtm40.)) else 0 end)
          as anydtdtm
       , min(short) as min
       , max(short) as max
  from _values_
  group by varnum
) b
  on a.varnum = b.varnum
  order by 1
;
quit;

*----------------------------------------------------------------------------;
* Apply overrides to the generated metadata ;
* Generate unique names ;
*----------------------------------------------------------------------------;
data _types_;
%if %length(&overrides) %then %do;
  update _types_ &overrides;
%end;
%else %do;
  set _types_;
%end;
  by varnum;
  length upcase $32 suffix 8;
  if _n_=1 then do;
    declare hash h ();
    h.definekey('upcase','suffix');
    h.definedone();
  end;
  if last.varnum;
  upcase=cats('VAR',varnum);
%if %sysfunc(getoption(validvarname)) = ANY %then %do;
  name=coalescec(name,label,upcase);
%end;
%else %do;
  if nvalid(coalescec(name,label,upcase)) then name=coalescec(name,label,upcase);
  else do;
* Replace adjacent non-valid characters with single underscore ;
    name=translate(trim(prxchange('s/([^a-zA-Z0-9]+)/ /',-1,coalescec(name,label,upcase))),' _','_ ');
    name=prxchange('s/(^[0-9])/_$1/',1,name);
  end;
%end;
  upcase=upcase(name);
%if %sysfunc(getoption(validvarname)) eq UPCASE %then %do;
  name=upcase;
%end;
  do suffix=0 to 1E4 while( h.add()
     or (suffix and not h.check(key:substrn(catx('_',upcase,suffix),1,32),key:0)))
  ;
     upcase=substr(upcase,1,32-length(cats(suffix))-1);
  end;
  if suffix then name=cats(substr(upcase,1,32-length(cats(suffix))-1),'_',suffix);

  if name=label then label=' ';
  if maxlength > &maxchar and type='char' then do;
    length="$&maxchar";
    put 'WARNING: Column ' varnum +(-1) ', ' name :$quote. ', might be truncated. '
        'Setting length to ' length 'but longest value seen was '
        maxlength :comma20. 'bytes long.'
    ;
  end;
  drop upcase suffix ;
run;

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
  set _types_ (obs=1) ;
  retain input ' ';
  length statement $10 string $370 ;

  put "data &out;" ;
  put @3 'infile ' @ ;
  do string=%sysfunc(quote(&file &fileopt)),"dlm=&dlm",'dsd','truncover',"&dataobs";
    if 75 < cc+lengthn(string) then do;
      anysplit=1;
      put / @5 @;
    end;
    if lengthn(string) then put string @;
  end;
  if anysplit then put / @3 @;
  put ';';

  do statement='length','informat','format','label';
    call missing(any,anysplit);
    put @3 statement @ ;
    do p=1 to nobs ;
      set _types_ point=p nobs=nobs ;
      string=vvaluex(statement);
      if not missing(string) then do;
        any=1;
        if statement ne 'label' then string=catx(' ',nliteral(name),string);
        else string=catx('=',nliteral(name),quote(trim(string),"'"));
        if 75<(cc+length(string)) then do;
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
  p=1;
  set _types_ point=p ;
  string=nliteral(name);
  put @3 'input ' string '-- ' @;
  p=nobs;
  set _types_ point=p ;
  string=nliteral(name);
  put string ';' ;
  put 'run;' ;
run;

%if (&run) %then %do;
*----------------------------------------------------------------------------;
* Run the generated data step ;
*----------------------------------------------------------------------------;
  %let optsave=%sysfunc(getoption(mprint));
  options nomprint;
%include _code_ / source2 ;
  options &optsave;
%end;
%else %do;
*----------------------------------------------------------------------------;
* Show the generated data step code in the log ;
*----------------------------------------------------------------------------;
  data _null_;
    infile _code_;
    input;
    put _infile_;
  run;
%end;

*----------------------------------------------------------------------------;
* Reset MISSING statement settings;
*----------------------------------------------------------------------------;
missing &misssave;

%quit:
%*----------------------------------------------------------------------------
Report on time spent in macro
-----------------------------------------------------------------------------;
%let dt=%sysevalf(%sysfunc(datetime())-&dt);
%if &dt < 60 %then %let dt=&dt seconds;
%else %let dt=%sysfunc(putn(&dt,time14.3));
%put NOTE: &macro used (Total process time): &dt.;
%mend csv2ds;
