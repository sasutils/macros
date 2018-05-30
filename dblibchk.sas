%macro dblibchk
/*----------------------------------------------------------------------
Return DBTYPE, DBHOST and DBNAME for an existing SAS/Access library
----------------------------------------------------------------------*/
(lib            /* LIBREF or LIBREF.MEMNAME format */
,mdbtype=dbtype /* Macro variable to return ENGINE name */
,mdbhost=dbhost /* Macro variable to return HOST name */
,mdbname=dbname /* Macro variable to return SCHEMA/DATABASE name */
) / minoperator mindelimiter=' ';
/*----------------------------------------------------------------------
Check SASHELP.VLIBNAM view to see if &LIB is defined using SAS/Access by
checking the existence of records where SYSNAME field represents
'Schema/User' or 'Schema/Owner'.

The values of the view variables engine, path and sysvalue are used to
populate the macro variables DBTYPE, DBHOST and DBNAME values,
respectively.

This will work for TERADATA, ORACLE and ODBC libname engines.
Not sure if it works for other external databases.

If return macro variables do not exist they will be made GLOBAL.

If libref does not exist or is not using SAS/ACCESS then return macro
variables will be blanked out and SYSRC will be set to 1.

User cannot use macro variable names that conflict with these macro
variables that are used by the macro inself.

  Parameters:  LIB MDBTYPE MDBHOST MDBNAME
  SASHELP.VLIBNAM variables:  LIBNAME ENGINE PATH SYSVALUE SYSNAME
  Local macro variables:   DID RC KEEP WHERE LOCALE SYSOWNER

Example usage:

%dblibchk(tdwork)
%put TDWORK uses engine &dbtype on server &dbhost to database &dbname..;

----------------------------------------------------------------------*/
%local did rc keep where locale sysowner;

%*----------------------------------------------------------------------
KEEP is a list of variables to be read from SASHELP.VLIBNAM. List will
be used in KEEP= dataset option and defined as local macro variables
to be automatically filled by FETCH() function call.
-----------------------------------------------------------------------;
%let keep=libname engine path sysvalue sysname ;
%local &keep ;

%*----------------------------------------------------------------------
Make sure macro variables exist so that values can be returned.
-----------------------------------------------------------------------;
%if not %symexist(&mdbtype) %then %global &mdbtype ;
%if not %symexist(&mdbhost) %then %global &mdbhost ;
%if not %symexist(&mdbname) %then %global &mdbname ;

%*----------------------------------------------------------------------
Clear values and set SYSRC=1 in case no libref is found.
-----------------------------------------------------------------------;
%let &mdbtype=;
%let &mdbhost=;
%let &mdbname=;
%let sysrc=1;

%*----------------------------------------------------------------------
A SAS LIBREF can only be 8 characters long.
-----------------------------------------------------------------------;
%let libname=%qupcase(%scan(&lib,1,.));
%if 1 <= %length(&libname) <= 8 %then %do;

%*----------------------------------------------------------------------
When using UTF-8 some LOCALE settings use different text for SYSNAME.
The ODBC engine uses Schema/Owner instead of Schema/User in metadata.
-----------------------------------------------------------------------;
  %let sysname='Schema/User';
  %let sysowner='Schema/Owner';
  %if "%sysfunc(getoption(encoding))"="UTF-8" %then %do;
    %let locale=%sysfunc(getoption(locale));
    %if &locale=JA_JP %then %do;
      %let sysname="E382B9E382ADE383BCE3839E2FE383A6E383BCE382B6E383BC"x;
      %let sysowner="E382B9E382ADE383BCE3839E2FE68980E69C89E88085"x;
    %end;
    %else %if (&locale in ZH_CN ZH_XX ZH_SG) %then %do;
      %let sysname="E6A8A1E5BC8F2FE794A8E688B7"x ;
      %let sysowner="E6A8A1E5BC8F2FE68980E69C89E88085"x;
    %end;
    %else %if (&locale in ZH_HK ZH_MO ZH_TW) %then %do;
      %let sysname="E7B590E6A78BE68F8FE8BFB02FE4BDBFE794A8E88085"x;
      %let sysowner="E7B590E6A78BE68F8FE8BFB02FE68980E69C89E88085"x;
    %end;
  %end;
%*----------------------------------------------------------------------
Open SASHELP.VLIBNAM with KEEP and WHERE dataset options. Use CALL SET()
to synch variable names to macro variables and fetch first matching
observation.
-----------------------------------------------------------------------;
  %let where=sysname in (&sysname,&sysowner) and libname="&libname";
  %let did=%sysfunc(open(sashelp.vlibnam(keep=&keep where=(&where))));
  %syscall set(did);
  %if not %sysfunc(fetch(&did)) %then %do;
%*----------------------------------------------------------------------
When record is found then set the return macro variables.
Note this assignment will also trim the trailing blanks that FETCH()
put into the local macro variables.

Set SYSRC=0 to indicate success.
-----------------------------------------------------------------------;
    %let &mdbtype=&engine;
    %let &mdbhost=&path ;
    %let &mdbname=&sysvalue;
    %let sysrc=0;
  %end;

%*----------------------------------------------------------------------
Close SYSHELP.VLIBNAM.
-----------------------------------------------------------------------;
  %let rc=%sysfunc(close(&did)) ;
%end;
%mend dblibchk ;
