%macro maclist
/*----------------------------------------------------------------------
Generate list of compiled macros and their source directories
----------------------------------------------------------------------*/
(out=maclist   /* Name of dataset to generate */
,dlist=        /* Directory list to scan (default=SASAUTOS option) */
);
/*----------------------------------------------------------------------
Produce a summary dataset with the location of the source file for the
compiled macros currently in SASHELP.SASMACR catalog by scanning across
SASAUTOS search path to see if corresponding file exists.

When using SAS 9.2 or higher it will use to Q modifier on the SCAN()
function to allow pathnames to include parentheses when properly quoted.
----------------------------------------------------------------------*/

data &out ;
  attrib MACRO length=$32  label='Macro name';
  attrib FOUND length=3    label='Found? (0/1)';
  attrib FILE  length=$36  label='Filename';
  attrib DNAME length=$200 label='Directory name';
  keep macro found file dname;

  if _n_=1 then do;
*----------------------------------------------------------------------;
* Get SASAUTOS option into string variable and copy individual paths ;
* into DLIST, expanding any filerefs that are found (such as SASAUTOS).;
*----------------------------------------------------------------------;
    length dlist autos path $32767 ;
    retain dlist ;
%if %length(&dlist) %then %do;
    autos=%sysfunc(quote(&dlist));
%end;
%else %do;
    autos=getoption('sasautos');
%end;
    do i=1 by 1 until (path= ' ');
%if %sysevalf(9.2 <= &sysver) %then %do;
      path=scan(autos,i,'( )','q');
%end;
%else %do;
      path=scan(autos,i,'( )');
%end;
      if length(path) <= 8 then do;
        if 0=fileref(path) then path=pathname(path) ;
      end;
      dlist=left(trim(dlist)||' '||path);
    end;
  end;

  set sashelp.vcatalg;
  where libname='WORK' and memname='SASMACR'
    and memtype='CATALOG' and objtype='MACRO';
  macro=objname;
  file=lowcase(trim(macro))||'.sas';

*----------------------------------------------------------------------;
* Scan through the paths in DLIST until file found or end of list ;
*----------------------------------------------------------------------;
  found=0;
  done=0;
  do i=1 by 1 until (found or done);
%if %sysevalf(9.2 <= &sysver) %then %do;
    dname=dequote(scan(dlist,i,'( )','q'));
%end;
%else %do;
    dname=dequote(scan(dlist,i,'( )'));
%end;
    if dname=' ' then done=1;
    else if fileexist(trim(dname)||'/'||trim(file)) then found=1;
  end;
  if ^found then dname=' ';
run;

%mend maclist;
