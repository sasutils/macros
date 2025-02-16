%macro symget
/*----------------------------------------------------------------------
Get value for macro variable that is hidden by local macro variable
----------------------------------------------------------------------*/
(mvar        /* Macro variable name */
,include=    /* Space delimited list of macro scopes to search */
,exclude=    /* Space delimited list of macro scopes to ignore */
,recurse=    /* Used internally by the macro  */
);
/*----------------------------------------------------------------------
Use SASHELP.VMACRO to pull value for a macro variable that is hidden by
local macro variables with the same name.
-----------------------------------------------------------------------
$Calls to: -none-
-----------------------------------------------------------------------
Usage:

%* Allow GMV to serve as default value ;
%if %bquote(&MVAR) = %then %let mvar=%symget(mvar);

%* Allow both GMV and parameter style macro calls ;
%macro aesumm(dsnin=,dsnut=,sev=);
  %local macro;
  %let macro=&sysmacroname;
  %if %bquote(&dsnin=) %then %let dsnin=%symget(dsnin,exclude=&macro);
  %if %bquote(&dsnut=) %then %let dsnut=%symget(dsnut,exclude=&macro);
  %if %bquote(&sev=) %then %let sev=%symget(sev,exclude=&macro);
   ....
%mend aesumm;

------------------------------------------------------------------------
Notes:
- Default to finding GLOBAL macro variable.
- Set SYSRC=1 when macro variable not found.
- Macro will call itself recursively to eliminate extra trailing blanks
  pulled from SASHELP.VMACRO.
-----------------------------------------------------------------------
History:

2011/04/05 abernt  Creation
----------------------------------------------------------------------*/
%local macro did rc where scope name value offset;
%let macro=&sysmacroname;

%if "&recurse"="0" %then %do;
%*----------------------------------------------------------------------
Open SASHELP.VMACRO and link dataset variables to macro variables.
If a match is found then expand VALUE as the result of the macro call.
Loop until all observations are read or OFFSET=0 indicates that the
start of another instance of the same variable has begun.
Close SASHELP.VMACRO.
-----------------------------------------------------------------------;
  %let where=%upcase(name="&mvar" and scope="&include");
  %let did=%sysfunc(open(sashelp.vmacro(where=(&where))));
  %syscall set(did);
  %if 0=%sysfunc(fetch(&did)) %then %do;
    %do %until(%sysfunc(fetch(&did)) or 0=&offset);&value.%end;
  %end;
  %let rc=%sysfunc(close(&did));
%end;
%else %if %bquote(&mvar)^= %then %do;
%*----------------------------------------------------------------------
Set scope to GLOBAL when no criteria specified. Exclude this macro.
Open the SASHELP.VMACRO and link dataset variables to macro variables.
Fetch first observation to get SCOPE and NAME. Close SASHELP.VMACRO.
-----------------------------------------------------------------------;
  %if %length(&include) %then %let where=findw("&include",scope,'','ir');
  %else %let where=not findw("&macro &exclude",scope,'','ir');
  %let where=name=%upcase("&mvar") and &where;
  %let did=%sysfunc(open(sashelp.vmacro(where=(&where))));
  %syscall set(did);
  %let rc=%sysfunc(fetch(&did));
  %let did=%sysfunc(close(&did));
  %if (0=&rc) %then %do;
%*----------------------------------------------------------------------
Found a variable so get value from recursive call to the macro.
Expand value as result of macro call.
-----------------------------------------------------------------------;
    %let value=%&macro(&name,include=&scope,recurse=0);
&value.
  %end;
%end;

%*----------------------------------------------------------------------
Set SYSRC=1 to indicate macro variable not found.
-----------------------------------------------------------------------;
%let sysrc=%eval(%bquote(&name)=);

%mend symget;
