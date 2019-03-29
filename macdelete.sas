%macro macdelete(delete,keep);
/*----------------------------------------------------------------------------
Remove compiled macros using %SYSMACDELETE macro statement.

Use DELETE parameter to list macro names to delete.
Use KEEP parameter to list macro names to NOT delete.
Calling it with no values will delete all macros not currently running.
----------------------------------------------------------------------------*/
%local libname memname objname objtype fid i;
%do i=1 %to %sysmexecdepth;
  %let keep=%sysmexecname(&i) &keep;
%end;
%if %length(&delete) %then %let delete=and findw("&delete",objname,',','sit');
%let fid=%sysfunc(open( sashelp.vcatalg(keep=libname memname objname objtype
 where=(libname='WORK' and objtype='MACRO' and memname like 'SASMAC_'
   and not findw("&keep",objname,',','sit') &delete))));
%if (&fid) %then %do;
  %syscall set(fid);
  %do %while(0=%sysfunc(fetch(&fid)));
    %put %sysfunc(compbl(Removing &objname from &libname catalog &memname));
    %sysmacdelete &objname;
  %end;
  %let fid=%sysfunc(close(&fid));
%end;
%else %put %qsysfunc(sysmsg());
%mend macdelete;
