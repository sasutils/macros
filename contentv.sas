%macro contentv
/*----------------------------------------------------------------------
Creates VIEW or DATASET containing the data file column attributes.
----------------------------------------------------------------------*/
(data              /* data set name */
,libname=          /* library reference */
,memname=          /* member name list to include */
,memnamex=         /* member name list to exclude */
,memtype=DATA VIEW /* member types */
,view=_CONTENT     /* output view name */
,out=              /* output table name  */
,genfmt=           /* Generate FORMAT when null? (default=yes) */
);

/*----------------------------------------------------------------------
Based on original macro created by Tom Hoffman.
-----------------------------------------------------------------------
Usage:

1)  %contentv;

    Creates view _CONTENT of the last created data file.

2)  %contentv(EVENTS)

    Creates view _CONTENT of the data file WORK.EVENTS.

4)  %contentv(DB.LABS)

    Creates view _CONTENT of the data file DB.LABS.

5)  %contentv(libname=SASUSER)

    Creates view _CONTENT containing variable attributes of all
    data files in the SASUSER library.

6)  %contentv(libname=SASUSER,memname=houses mydata)

    Creates view _CONTENT containing variable attributes of all
    two members in the SASUSER library.
------------------------------------------------------------------------
Notes:

Either the data parameter or the libname/memname parameter may be used.

Creates VIEW containing the data file contents. The view contains the
the following variables (from DICTIONARY.COLUMNS):

  LIBNAME  $8    Library Name
  MEMNAME  $32   Member Name - upcased
  MEMTYPE  $8    Member Type
  NAME     $32   Column Name - upcased
  TYPE     $4    Column Type  (char or num)
  LENGTH    8    Column Length
  NPOS      8    Column Position
  VARNUM    8    Column Number in Table
  LABEL    $40   Column Label
  FORMAT   $16   Column Format
  INFORMAT $16   Column Informat
  IDXUSAGE $9    Column Index Type

where if null the format variable has been set to BEST12. for numeric
variables and to the length for character variables.
-----------------------------------------------------------------------
History:

04OCT95 TRHoffman Creation
04FEB99 TRHoffman Added MEMNAMEX parameter.
27SEP00 TRHoffman Implemented changes required by V8
26FEB02 TRHoffman Added support for lower case table names.
16JUN07 abernt    Added support of long character variables
17FEB08 abernt    Added support for multiple libnames.
                  Added test for view/dataset conflict on output.
                  Made format generation when null optional.
----------------------------------------------------------------------*/
%*----------------------------------------------------------------------
Test if request to generate format when null. Support aliases.
-----------------------------------------------------------------------;
%if ^%length(&genfmt) %then %let genfmt=1;
%else %if %sysfunc(indexw(1 Y T ON YES TRUE,%qupcase(&genfmt)))
  %then %let genfmt=1;
%else %let genfmt=0;

%*----------------------------------------------------------------------
Parse data parameter for LIBNAME and MEMNAME. Support where clause.
Support MEMNAMEX for case when memname=_ALL_.
-----------------------------------------------------------------------;
%if ("&data" ^= "") %then %do;
  %let data = %upcase(&data);
  %let memname = %scan(&data,2,.);
  %if (&memname =) %then %do;
    %let libname = WORK;
    %let memname = %scan(&data,1,%str(%());
  %end;
  %else %do;
     %let libname = %scan(&data,1,.);
     %let memname = %scan(&memname,1,%str(%());
  %end;
  %let memnamex=%upcase(&memnamex);
%end;

%*----------------------------------------------------------------------
Assume last created data set.
-----------------------------------------------------------------------;
%else %if ^%length(&libname) %then %do;
  %let libname = %scan(&sysdsn,1);
  %let memname = %substr(&sysdsn,9);
  %let memnamex=;
%end;

%*----------------------------------------------------------------------
Use values of LIBNAME and MEMNAME
-----------------------------------------------------------------------;
%else %do;
  %let libname = %upcase(&libname);
  %let memname = %upcase(&memname);
  %let memnamex = %upcase(&memnamex);
%end;

%*----------------------------------------------------------------------
Create VIEW from DICTIONARY.COLUMNS. Note that this SQL view is about 25
times faster than the SASHELP vcolumn view.

Generate FORMAT when null.
-----------------------------------------------------------------------;
proc sql;
%if %length(&out) and %sysfunc(exist(&out,view)) %then %do;
     drop view &out;
%end;
%else %if %sysfunc(exist(&view,data)) %then %do;
     drop table &view;
%end;

%if %length(&out) %then
     create table &out as
;
%else
     create view &view as
;
     select libname  /* $8.         library name */
     ,      upcase(memname) as memname/* $32 member name */
     ,      memtype  /* $8          member type */
     ,      upcase(name) as name label='Column Name'
     ,      type     /* $4.         column type */
     ,      length   /* best12.     column length */
     ,      npos     /* best12.     column position */
     ,      varnum   /* best12.     column number in table */
     ,      label    /* $40.        column label */
     ,
%if (&genfmt) %then
            case when format is null then
                case (type)
                  when 'char' then compress('$'||put(length,5.)||'.')
                  else 'best12.'
                end
              else format
            end
;
%else       format
;
            as format label='Column Format'
     ,      informat /* $16.        column informat */
     ,      idxusage /* $9.         column index type */
     from dictionary.columns
     where libname in %qlist(&libname)
%if %length(&memtype) %then
      and  memtype in %qlist(%upcase(&memtype))
;
%if %length(&memname) & (&memname ^= _ALL_) %then
      and  upcase(memname) in %qlist(&memname)
;
%if %length(&memnamex) %then
      and  upcase(memname) ^in %qlist(&memnamex)
;
     ;
quit;
%mend contentv;
