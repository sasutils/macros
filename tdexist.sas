%macro tdexist
/*----------------------------------------------------------------------------
Return type of a teradata table or view to test if it exists
----------------------------------------------------------------------------*/
(name           /* Name of object to find (REQ) */
,mvar=tdexist   /* Name of macro variable to retrieve results. */
,connection=td  /* Name of existing PROC SQL database connection */
);
/*----------------------------------------------------------------------------
Return type of a teradata table or view to test if it exists

If PROC SQL is running it will assume that the connection already exists and
fail if it does not. Otherwise it will use %TDCONNECT(PROC_SQL) to start
PROC SQL and make connection to Teradata as TD. Check that macro for
information on how to create a Teradata connecton inside of PROC SQL.

MVAR will be set to one of :
  VIEW
  TABLE
  VOLATILE TABLE
  NONE

------------------------------------------------------------------------------
Calls to: parmv.sas squote.sas tdconnect.sas
------------------------------------------------------------------------------
$Modification History

----------------------------------------------------------------------------*/
%local parmerr macro tddb userid table db result exists optsave ;
%let macro=&sysmacroname;

%*----------------------------------------------------------------------------
Set RESULT to NONE to indicate failure.
-----------------------------------------------------------------------------;
%let result=NONE;

%*----------------------------------------------------------------------------
Check user parameters.
-----------------------------------------------------------------------------;
%parmv(name,_req=1)
%parmv(connection,_def=td)
%parmv(mvar,_def=&macro)
%if (&parmerr) %then %goto quit;

%*----------------------------------------------------------------------------
Check that MVAR is not one of the macro variables local to TDEXIST macro.
-----------------------------------------------------------------------------;
%if %sysfunc(indexw(PARMERR MACRO TDDB USERID TABLE DB RESULT EXISTS
 NAME MVAR CONNECTION,&mvar)) %then
   %parmv(mvar,_msg=Macro variable already in use by &macro)
;
%*----------------------------------------------------------------------------
Check that NAME has proper number of levels.
-----------------------------------------------------------------------------;
%if 1 < %sysfunc(countc(&name,.)) %then
  %parmv(NAME,_msg=Only one or two level names allowed)
;
%if (&parmerr) %then %goto quit;

%*----------------------------------------------------------------------------
Make sure the target macro variable exists.
-----------------------------------------------------------------------------;
%if %length(&mvar) %then %if not %symexist(&mvar) %then %global &mvar;

%*----------------------------------------------------------------------------
If PROC SQL is not running then start it by calling %TDCONNECT.
-----------------------------------------------------------------------------;
%if not (&sysprocname=SQL) %then %do;
   %tdconnect(proc_sql);
   %if (&sysrc) %then %goto quit;
   %let connection=TD;
%end;

%*----------------------------------------------------------------------------
Turn off SASTRACE settings to reduce LOG messages.
-----------------------------------------------------------------------------;
%let optsave=%sysfunc(getoption(notes));
%let optsave=&optsave sastrace="%sysfunc(getoption(sastrace))";
options nonotes sastrace=none;

%*----------------------------------------------------------------------------
Check if connection is working and get the current db and username .
-----------------------------------------------------------------------------;
select db,userid into :tddb trimmed,:userid trimmed
  from connection to &connection (select user as userid, database as db)
;
%if (^&sqlobs) %then %do;
  %parmv(_msg=Unable to query Teradata);
  %goto quit;
%end;

%*----------------------------------------------------------------------------
Split NAME into DB and TABLE.
-----------------------------------------------------------------------------;
%let table=%sysfunc(dequote(%scan(&name,-1,.)));
%if %index(&name,.) %then %let db=%sysfunc(dequote(%scan(&name,-2,.)));
%else %let db=&tddb;

*----------------------------------------------------------------------------;
* Check if table or view exists ;
*----------------------------------------------------------------------------;
select obj into :result trimmed from connection to &connection
  (select case when (tablekind in ('T','O')) then 'TABLE'
          else 'VIEW' end as obj
    from dbc.tablesv
    where databasename = %squote(&db) and tablename= %squote(&table)
      and tablekind in ('V','T','O')
  )
;
%let exists=&sqlobs;

%if (^&exists and &db=&userid) %then %do;
*----------------------------------------------------------------------------;
* Check for any Volatile tables ;
*----------------------------------------------------------------------------;
  select 1 into :exists from connection to &connection (help volatile table) ;

  %if (&exists) %then %do;
*----------------------------------------------------------------------------;
* Check if this Volatile table exists ;
*----------------------------------------------------------------------------;
    select 'VOLATILE TABLE' into :result
      from connection to &connection (help volatile table)
%*----------------------------------------------------------------------------
Set VARNAME based on VALIDVARNAME setting.
-----------------------------------------------------------------------------;
%if %sysfunc(getoption(validvarname))=ANY %then
      where upcase('table name'n) = "&table"
;%else
      where upcase(table_name) = "&table"
;
    ;
    %let exists=&sqlobs;
  %end;
%end;

%quit:
options &optsave;
%let &mvar=&result;
%mend tdexist;
