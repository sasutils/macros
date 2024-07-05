%macro dslist
/*----------------------------------------------------------------------
Generate dataset list to summarize SAS datasets in libraries
----------------------------------------------------------------------*/
(librefs=WORK    /* Space delimited list of LIBREFS to include  */
,out=dslist      /* Output dataset. Default is WORK.dslist    */
,exclude=dslist  /* Space delimited list of members to exclude  */
,select=         /* Space delimited list of members to include  */
,usubjid=        /* Variables that uniquely identify a subject  */
,countobs=0      /* Count NOBS when missing? (0/1) */
);
/*----------------------------------------------------------------------
Generate dataset list with one record per dataset. Information derived 
will include the number of variables and observations and optionally the 
number of subjects.

The resulting dataset will have the following variables:

 # Variable  Type  Len Format    Informat   Label
 1 LIBNAME   Char    8                      Library reference
 2 MEMNAME   Char   32                      Dataset name
 3 MEMTYPE   Char    8                      Dataset type
 4 MODATE    Num     8 DATETIME. DATETIME.  Last mod datetime
 5 NOBS      Num     8                      Number of observations
 6 NSUBJECT  Num     8                      Number of subjects
 7 NVAR      Num     8                      Number of variables
 8 OBSLEN    Num     8                      Observation length
 9 MEMLABEL  Char  256                      Dataset label
10 PATH      Char 1024                      Directory of file

-----------------------------------------------------------------------
$Calls to: parmv.sas qlist.sas 
-----------------------------------------------------------------------
$Usage notes:
If USUBJID is supplied then number of subjects are counted and stored
into NSUBJECT variable in the output dataset for the datasets that have
the USUBJID variables. Otherwise the NSUBJECT variable will have missing
values.

Set COUNTOBS to generate an SQL query to count the number of
observations for each members where the value is not available in SAS
metadata DICTIONARY.TABLES.  This is usefull for views or when using
SAS/Access to external databases such as ORACLE or TERADATA.

Using the USUBJID or COUNTOBS options might take a long time for large
datasets.

The SELECT and EXCLUDE lists apply to only membername part of dataset name.

Examples:
* Get dslist for RAW and VA libraries, caclulate number of subjects ;
%dslist(librefs=raw va,usubjid=pid)

-----------------------------------------------------------------------
Modification History
-----------------------------------------------------------------------
2007/10/08 abernt Initial revision
2009/03/11 abernt Eliminate querying variable names from unused datasets
2011/02/28 abernt Remove view with same name as OUT dataset
2012/12/02 abernt Added option to count NOBS
2024/07/05 sasutils Post to Github.
----------------------------------------------------------------------*/
%local macro parmerr;
%local dslist nds nds2 i nsubjid csubjid nsubject nobs ;

%let macro=DSLIST;
%let parmerr=0;

%parmv(librefs,_req=1,_words=1)
%parmv(out,_def=dslist)
%parmv(usubjid,_words=1)
%parmv(exclude,_words=1)
%parmv(select,_words=1)
%if (&parmerr) %then %goto quit;

*----------------------------------------------------------------------;
* Create &out from dictionary.tables and dictionary.members ;
*----------------------------------------------------------------------;
proc sql noprint;
%if %sysfunc(exist(&out,view)) %then %do;
  drop view &out;
%end;
  create table &out as
  select
     t.LIBNAME as LIBNAME label='Library reference'
    ,upcase(t.memname) as MEMNAME label='Dataset name'
    ,t.MEMTYPE as MEMTYPE label='Dataset type'
    ,t.MODATE as MODATE label='Last mod datetime'
    ,t.nobs-t.delobs as NOBS label='Number of observations'
    ,. as NSUBJECT label='Number of subjects'
    ,t.NVAR as NVAR label='Number of variables'
    ,t.OBSLEN as OBSLEN label='Observation length'
    ,t.memlabel as MEMLABEL label='Dataset label'
    ,v.PATH as PATH label='Directory of file'
  from dictionary.tables t left join
   (select distinct libname,path from dictionary.members m
    where m.libname in %qlist(&librefs)
   ) v
  on t.libname = v.libname
  where t.libname in %qlist(&librefs)
%if %length(&select) %then
    and t.memname in %qlist(&select)
;
%if %length(&exclude) %then
    and t.memname ^in %qlist(&exclude)
;
  order by 1,2
  ;
  %let nds=&sqlobs;
quit;

%if (%length(&usubjid) and &nds) %then %do;
%*----------------------------------------------------------------------
Count number of variables and generate version with commas for SQL.
-----------------------------------------------------------------------;
  %let usubjid=%sysfunc(compbl(&usubjid));
  %let nsubjid=%sysfunc(countw(&usubjid,%str( )));
  %let csubjid=%sysfunc(tranwrd(&usubjid,%str( ),%str(,)));

*----------------------------------------------------------------------;
* Count number of subjects when dataset has all USUBJID variables. ;
*----------------------------------------------------------------------;
  proc sql noprint;
    select distinct trim(d.libname)||'.'||trim(d.memname)
      into :dslist separated by '/'
    from dictionary.columns c
       , &out d
    where c.libname in %qlist(&librefs)
      and c.libname = d.libname
      and c.memname = d.memname
      and upcase(c.name) in %qlist(&usubjid)
    group by d.libname,d.memname
    having count(*)=&nsubjid
    ;
  %let nds2=&sqlobs;
  %do i=1 %to &nds2;
    %let nsubject=0;
    select count(*) into :nsubject
      from (select distinct &csubjid from %scan(&dslist,&i,/)) ;
    update &out set nsubject = &nsubject
      where libname="%scan(%scan(&dslist,&i,/),1,.)"
        and memname="%scan(%scan(&dslist,&i,/),2,.)"
    ;
  %end;
  quit;
%end;

%if (&countobs and &nds) %then %do;
*----------------------------------------------------------------------;
* Count number of observations when NOBS is missing ;
*----------------------------------------------------------------------;
  proc sql noprint;
    select distinct trim(d.libname)||'.'||trim(d.memname)
      into :dslist separated by '/'
    from &out d
    where d.nobs is missing
    ;
  %let nds2=&sqlobs;
  %do i=1 %to &nds2;
    %let nobs=0;
    select count(*) into :nobs from %scan(&dslist,&i,/) ;
    update &out set nobs = &nobs
      where libname="%scan(%scan(&dslist,&i,/),1,.)"
        and memname="%scan(%scan(&dslist,&i,/),2,.)"
    ;
  %end;
  quit;
%end;

%quit:
%mend dslist;
