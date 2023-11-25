%macro sas2xport
/*----------------------------------------------------------------------
Generate SAS V5 or V9 Transport file from SAS datasets/views
----------------------------------------------------------------------*/
(data          /* Name of dataset to export  */
,file          /* Output Fileref or quoted physical file name */
,libref=       /* Source library reference */
,select=       /* Space delimited list of member names */
,exclude=      /* Space delimited list of member names */
,version=      /* XPORT format to generate V5|V9 (Default=V9) */
,append=       /* Append to existing file? (0/1) (Default=0) */
,out=_null_    /* Optional dataset to write contents information */
)/minoperator mindelimiter=' ';
/*----------------------------------------------------------------------
Generate SAS V5 or V9 Transport file from SAS datasets/views.

Either specify a single input dataset using the DATA parameter or use
the LIBREF parameter with optional SELECT and/or EXCLUDE parameters to
indicate the dataset(s) to export.

Allows alias of 5, 6, or V6 for V5 XPORT format.
Allows alias of 7, 8, 9, V7, or V8 for V9 XPORT format.

For specification of the structure of SAS V5 transport files see:
 SAS technical support notice TS-140
For specification on V9 format see:
 https://support.sas.com/kb/46/944.html

The XPORT engine will read V5 transport files with character variables
with storage length larger than 200. It also will read non-standard
variable names and does not convert names to uppercase.

This macro will take advantage of that to generate V5 transport files
for datasets that the XPORT engine cannot handle.

When forcing V5 XPORT generation long names will be truncated. Also digits
will be appended when necessary to create unique names. Long labels will be
truncated.  Some labels may be replaced by the original long variable name.
Long format/informat names will be truncated.

The original long variable name will be written (at location used by V9
xport format).  This is ignored by the XPORT engine and %xpt2loc() macro
but will be used by the %XPORT2SAS() macro.

Enhancements over the XPORT libname engine include:
- Support for creating the enhanced V9 XPORT file format.
- Character variables longer than 200 allowed in V5 XPORT file.
- Mixed case variable names preserved in V5 XPORT file.
- Dataset creation and modification time stamps preserved.
- Automatic rename of long variable names with name collision detection.

For long format and/or informat names it will just truncate the name.

------------------------------------------------------------------------
Usage Notes:
- &SYSRC will be set to 0 on success and 1 when there are problems.
- If FILE is not specified then it will generate a physical filename
  using the membername in DATA parameter or the LIBREF parameter.
- When names are truncated the original name is stored in the label.
- Truncation of member names, format names and informat names could
  cause them to become non-unique.
- Use LIBREF, SELECT and/or EXCLUDE options to export multiple datasets.
- Use APPEND=1 to add additional dataset(s) to an existing XPORT file.
- Macro calls itself recursively with APPEND=1 when multiple datasets
  are selected.

-----------------------------------------------------------------------
Examples:
* Single dataset to physical filename ;
%sas2xport(sashelp.class,file="class.xpt")

* Use automatic output filename ;
%sas2xport(sashelp.class)

* All datasets from a libref ;
libname sasdata ".";
filename export "sasdata.xpt";
%sas2xport(libref=sasdata,file=export)

* List of datasets to fileref ;
filename export "class.xpt";
%sas2xport(libref=sashelp,select=class cars,file=export)

----------------------------------------------------------------------*/
%local parmerr hdr1 hdr2 note warn err nobs did dslist nds i
       member selectp excludep fname rc fexist obslen
;
%let parmerr=0;
%let hdr1=HEADER RECORD*******;
%let hdr2=HEADER RECORD!!!!!!!;
%let note=putlog "NOTE: &sysmacroname: ";
%let warn=putlog 'WARN' "ING: &sysmacroname: ";
%let err=putlog 'ERR' "OR: &sysmacroname: ";
%let nobs=000000000000000;

%*----------------------------------------------------------------------
Validate parameters.
-----------------------------------------------------------------------;
/*----------------------------------------------------------------------
Check DATA and LIBREF settings.  When neither is set use &SYSLAST.
----------------------------------------------------------------------*/
%if 0=%length(&data.&libref) %then %let data=&syslast;
/*----------------------------------------------------------------------
When DATA is set then ignore LIBREF.
----------------------------------------------------------------------*/
%else %if %length(&data) and %length(&libref) %then %do;
  %put NOTE: &sysmacroname: &=DATA was specified so ignoring &=LIBREF..;
  %let libref=;
%end;
/*----------------------------------------------------------------------
Make sure DATA can be found.
----------------------------------------------------------------------*/
%if %length(&data) %then %do;
  %let did=%sysfunc(open(&data));
  %if 0=&did %then %do;
    %put ERROR: &sysmacroname: Unable to open &=data..;
    %let parmerr=1;
  %end;
  %else %let did=%sysfunc(close(&did));
%end;
/*----------------------------------------------------------------------
When LIBREF is set then make sure LIBREF is valid. And standardize
values of SELECT and EXCLUDE for use in SQL query.
----------------------------------------------------------------------*/
%if %length(&libref) %then %do;
  %if %length(&libref)>8 or not %sysfunc(nvalid(&libref,v7)) %then %do;
    %put ERROR: &sysmacroname: &=libref is not a valid SAS name.;
    %let parmerr=1;
  %end;
  %else %if %sysfunc(libref(&libref)) %then %do;
    %put ERROR: &sysmacroname: &=libref is not defined.;
    %let parmerr=1;
  %end;
  %else %let libref=%upcase(&libref);
  %if (%qupcase(&select) = _ALL_) %then %let select=;
  %else %do i=1 %to %sysfunc(countw(&select,%str( ),q));
    %let member=%qscan(&select,&i,%str( ),q);
    %if %sysfunc(nvalid(&member,nliteral)) %then %do;
      %let selectp=&selectp|%qsysfunc(dequote(&member));
    %end;
    %else %do;
      %put ERROR: &sysmacroname: &=member is not valid name to SELECT.;
      %let parmerr=1;
    %end;
  %end;
  %do i=1 %to %sysfunc(countw(&exclude,%str( ),q));
    %let member=%qscan(&exclude,&i,%str( ),q);
    %if %sysfunc(nvalid(&member,nliteral)) and (%qupcase(&member) ne _ALL_)
      %then %let excludep=&excludep|%qsysfunc(dequote(&member))
    ;
    %else %do;
      %put ERROR: &sysmacroname: &=member is not valid name to EXCLUDE.;
      %let parmerr=1;
    %end;
  %end;
%end;

%*----------------------------------------------------------------------
Make sure DATA did not end up being _NULL_.
-----------------------------------------------------------------------;
%if (%qupcase(&data)=_NULL_) %then %do;
  %put ERROR: &sysmacroname: &=data is not valid. Cannot export the null dataset.;
  %let parmerr=1;
%end;

%*----------------------------------------------------------------------
Make sure APPEND is valid 0 1 boolean. Default to 0.
-----------------------------------------------------------------------;
%if 0=%length(&append) %then %let append=0;
%else %if %qupcase(&append) in Y YES T TRUE ON 1 %then %let append=1;
%else %if %qupcase(&append) in N NO F FALSE OFF 0 %then %let append=0;
%else %do;
  %put ERROR: &sysmacroname: &=append is not a valid value. Valid values are:
%quote(0 (or OFF NO N FALSE F) 1 (or ON YES Y TRUE T));
  %let parmerr=1;
%end;

%*----------------------------------------------------------------------
Make sure VERSION is valid and standardize to V5 or V9.
-----------------------------------------------------------------------;
%if 0=%length(&version) %then %let version=V9;
%else %if %qupcase(&version) in 7 8 9 V7 V8 V9 %then %let version=V9;
%else %if %qupcase(&version) in 5 6 V5 V6 %then %let version=V5;
%else %do;
  %put ERROR: &sysmacroname: &=version is not valid. Valid values are V5 or V9;
  %let parmerr=1;
%end;

%if (&parmerr) %then %goto quit;

%if %length(&libref) %then %do;
*----------------------------------------------------------------------;
* Calculate matching list of datasets from DICTIONARY.MEMBERS ;
*----------------------------------------------------------------------;
proc sql noprint ;
  select memname,catx('.',libname,nliteral(memname))
    into :dslist,:dslist separated by '|'
    from dictionary.members
    where memtype in ('DATA','VIEW') and libname="&libref"
  %if %length(&select) %then and findw("&selectp",memname,'|','iors') ;
  %if %length(&exclude) %then and 0=findw("&excludep",memname,'|','iors');
    order by 1
  ;
quit;
  %let nds=&sqlobs;
  %let data=%scan(&dslist,1,|);
%end;
%else %let nds=1;
%if (&nds<1) %then %do;
  %put ERROR: &sysmacroname: No datasets selected. &=libref &=select &=exclude;
  %let parmerr=1;
%end;

%if (&parmerr) %then %goto quit;

%*----------------------------------------------------------------------
Default value for FILE.
-----------------------------------------------------------------------;
%if 0=%length(&file) %then %do;
  %if %length(&libref) %then %let fname=&libref;
  %else %let fname=%scan(&data,-1,. .);
  %let fname="%sysfunc(lowcase(&fname)).xpt";
  %put NOTE: &sysmacroname: Since no file specified will use FILE=&fname..;
%end;
%else %let fname=&file;

%*----------------------------------------------------------------------
Test if FILE exists.
-----------------------------------------------------------------------;
%if %sysfunc(nvalid(&fname,v7)) and %length(&fname)<=8 %then %do;
  %let rc=%sysfunc(fileref(&fname));
  %if (&rc = 0) %then %let fexist=1;
  %else %if (&rc<0) %then %let fexist=0;
%end;
%if (&fexist=) %then %do;
  %let fname=%sysfunc(quote(%qsysfunc(dequote(&fname)),%str(%')));
  %let fexist=%sysfunc(fileexist(&fname));
%end;

%if not %sysfunc(cexist(work.formats.xprtflt.format)) %then %do;
*----------------------------------------------------------------------;
* Create XPRTFLT format to write numeric missing values properly. ;
*----------------------------------------------------------------------;
proc format;
  value xprtflt           .  ='2E00000000000000'x
  .A ='4100000000000000'x .B ='4200000000000000'x .C ='4300000000000000'x
  .D ='4400000000000000'x .E ='4500000000000000'x .F ='4600000000000000'x
  .G ='4700000000000000'x .H ='4800000000000000'x .I ='4900000000000000'x
  .J ='4A00000000000000'x .K ='4B00000000000000'x .L ='4C00000000000000'x
  .M ='4D00000000000000'x .N ='4E00000000000000'x .O ='4F00000000000000'x
  .P ='5000000000000000'x .Q ='5100000000000000'x .R ='5200000000000000'x
  .S ='5300000000000000'x .T ='5400000000000000'x .U ='5500000000000000'x
  .V ='5600000000000000'x .W ='5700000000000000'x .X ='5800000000000000'x
  .Y ='5900000000000000'x .Z ='5A00000000000000'x ._ ='5F00000000000000'x
  other=(|s370frb8.|)
  ;
run;
%end;

%*----------------------------------------------------------------------
If APPEND=0 or FILE does not exist then write LIBRARY header.
-----------------------------------------------------------------------;
%if (0=&append or 0=&fexist) %then %do;
data _null_;
  file &fname recfm=n;
  %if (&version = V5) %then %do;
  put "&hdr1.LIBRARY &hdr2." 30*'0' '  ';
  %end; %else %do;
  put "&hdr1.LIBV8   &hdr2." 30*'0' '  ';
  %end;
  date=datetime();
  sas='SAS';  saslib='SASLIB';  sysver="&sysver";  sysscp="&sysscp";
  put (sas sas saslib sysver sysscp) ($8.) 24*' ' date datetime16. ;
  put date datetime16. 64*' ';
run;
%end;

%*----------------------------------------------------------------------------
Use DATA step to gather dataset contents information.
Generate MEMBER, DSCRPTR, NAMESTR, LABEL and OBS records.
Use CALL EXECUTE() to generate CODE to write the data records.
-----------------------------------------------------------------------------;
data &out;
%*----------------------------------------------------------------------------
Use MODIFY statement when OUT exists and APPEND is requested.
-----------------------------------------------------------------------------;
%if &append and %sysfunc(exist(&out)) %then %do;
  modify &out;
%end;
%*----------------------------------------------------------------------------
Define variables.
-----------------------------------------------------------------------------;
  length
    LIBNAME $8 MEMNAME $32
    VARNUM 8 UNAME $8 NAME $32 LENGTH 8 TYPEN 8 TYPE $4 TYPEF $8
    FORMAT $49 INFORMAT $49
    FORMATN $32 FORMATL FORMATD 8
    INFORMN $32 INFORML INFORMD 8
    LABEL $256
    NVAR 8 NOBS 8 OBSLEN 8 CRDATE 8 MODATE 8
    TYPEMEM $8 MEMTYPE $8
    MEMLABEL $256
  ;
  keep libname -- memlabel;
  format crdate modate datetime19.;
  length firstvar suffix 8;

  dsid=open(symget('data'));
%*----------------------------------------------------------------------------
Create HASH() objects. U - unique name V - all variables ITER - hiter for V
-----------------------------------------------------------------------------;
  declare hash u();
  u.definekey('uname');
  u.definedata('firstvar');
  u.definedone();
  declare hash v(ordered:'Y');
  v.definekey('varnum');
  v.definedata('libname','memname','typemem'
              ,'varnum','uname','name','length','typen','type','typef'
              ,'format','formatn','formatl','formatd'
              ,'informat','informn','informl','informd'
              ,'label','nobs','nvar','crdate','modate','memlabel');
  v.definedone();
  declare hiter iter('v');

%*----------------------------------------------------------------------------
Read member information using ATTRN() and ATTRC() functions.
-----------------------------------------------------------------------------;
  nvar=attrn(dsid,'nvars');
  nobs=attrn(dsid,'nlobsf');
  crdate=attrn(dsid,'crdte');
  modate=attrn(dsid,'modte');
  libname=attrc(dsid,'lib');
  memname=attrc(dsid,'mem');
  memlabel=attrc(dsid,'label');
  typemem=attrc(dsid,'type');
  memtype=attrc(dsid,'mtype');
%*----------------------------------------------------------------------------
Find all variable names and info. Skip variables where VARNAME() is empty.
Empty VARNAME() is caused by DROP=/KEEP= dataset options.

Store variable informat into hash() objects V and U.
-----------------------------------------------------------------------------;
  suffix=0;
  do index=1 by 1 while (varnum<nvar);
    name=varname(dsid,index);
    if name=' ' then _error_=0;
    else do;
%*----------------------------------------------------------------------------
Read variable information using VARxxx functions.
-----------------------------------------------------------------------------;
      varnum+1;
      length=varlen(dsid,index);
      type=vartype(dsid,index);
      format=varfmt(dsid,index);
      informat=varinfmt(dsid,index);
      label=varlabel(dsid,index);
%*----------------------------------------------------------------------------
Derive TYPE variables. Split FORMAT and INFORMAT into parts. Get FMT Category.
-----------------------------------------------------------------------------;
      typen=1+(type='C');
      type=scan('num,char',typen);
      formatn=substrn(format,1,findc(format,'.','bsdk'));
      formatl=input(scan('0'||substrn(format,lengthn(formatn)+1),1),??32.);
      formatd=input('0'||substrn(format,findc(format,'.')+1),??32.);
      informn=substrn(informat,1,findc(informat,'.','bsdk'));
      informl=input(scan('0'||substrn(informat,lengthn(informn)+1),1),??32.);
      informd=input('0'||substrn(informat,findc(informat,'.')+1),??32.);
      typef=fmtinfo(coalescec(formatn,char('F$',typen)),'cat');
%*----------------------------------------------------------------------------
Store into hash() objects.
-----------------------------------------------------------------------------;
      uname=upcase(name);
      firstvar=varnum;
      if v.add() then do;
        &err 'Unable to add ' varnum= name= ;
        stop ;
      end;
      if u.add() then ndups+1;
%*----------------------------------------------------------------------------
Count inconsistencies with V5 xport file restrictions.
-----------------------------------------------------------------------------;
      l_name   + length(name) > 8;
      l_format + length(formatn) > 8;
      l_inform + length(informn) > 8;
      l_label  + length(label) > 40;
      nl_label + (length(formatn)>8 or length(informn)>8 or length(label)>40);
      l_length + length>200;
    end;
  end;
  dsid=close(dsid);
%if (&version = V5) %then %do;
%*----------------------------------------------------------------------------
Iterate over variables again so that can :
  - generate unique short names
  - fix case of uname to match case of name
-----------------------------------------------------------------------------;
  rc = iter.first();
  do while (rc = 0);
    u.find();
    if varnum ne firstvar then do;
      firstvar=varnum;
      do suffix=0 by 1 while(u.add());
        uname=cats(substr(uname,1,8-length(cats(suffix+1))),suffix+1);
      end;
    end;
    if suffix<1 then uname=substr(name,1,length(uname));
    else uname=cats(substr(name,1,length(uname)-length(cats(suffix))),suffix);
    if uname ne name then do;
      &note 'Name ' name :$quote. 'converted to ' uname :$quote. 'and ' @;
      if label ne ' ' then putlog 'label replaced with original name.';
      else putlog 'original name stored in label.';
      label=name;
    end;
    v.replace();
    rc = iter.next();
  end;
%end;
%else %do;
  uname=name;
%end;
*----------------------------------------------------------------------;
* Write Member Headers ;
*----------------------------------------------------------------------;
  file &fname recfm=n mod ;
  sas='SAS';
  sasdata='SASDATA';
  sasver="&sysver";
  osver="&sysscp";
  if missing(crdate) then crdate=datetime();
  if memtype='VIEW' then modate=datetime();
  if missing(modate) then modate=crdate;
  if length(memlabel)>40 then &note 'Truncating member label for '
    memname= 'to 40 characters: ' memlabel $40. ;
%if (&version = V5) %then %do;
  if length(memname)>8 then do;
    &note 'Member ' memname :$quote. 'saved as ' memname :$8.
      +(-1) '. Original name stored as member label.' @;
    if memlabel ne ' ' then putlog ' Original label was: ' memlabel :$quote.;
    else putlog;
    memlabel=memname;
  end;
  put "&hdr1.MEMBER  &hdr2." 17*'0' '1600000000140  ';
  put "&hdr1.DSCRPTR &hdr2." 30*'0' '  ';
  put (sas memname sasdata sasver osver) ($8.) 24*' ' crdate datetime16. ;
%end; %else %do;
  put "&hdr1.MEMBV8  &hdr2." 17*'0' '1600000000140  ';
  put "&hdr1.DSCPTV8 &hdr2." 30*'0' '  ';
  put sas $8. memname $32. (sasdata sasver osver) ($8.) crdate datetime16. ;
%end;
  put modate datetime16. 16*' ' memlabel $40. typemem $8. ;

*----------------------------------------------------------------------;
* Write Variable list ;
*----------------------------------------------------------------------;
%if (&version = V5) %then %do;
  put "&hdr1.NAMESTR &hdr2." nvar z10. 20*'0' '  ' ;
%end; %else %do;
  put "&hdr1.NAMSTV8 &hdr2." nvar z10. 20*'0' '  ' ;
%end;
  zero=0;
  rc = iter.first();
  do while (rc = 0);
    put (typen zero length varnum ) (s370fib2.) uname $8. label $40. ;
    put formatn $8. (formatl formatd zero zero) (s370fib2.) ;
    put informn $8. (informl informd) (s370fib2.) ;
    put obslen s370fib4.;
    labellen=lengthn(label);
    formatlen=lengthn(formatn);
    informlen=lengthn(informn);
    put name $32. (labellen formatlen informlen) (s370fib2.) 14*'00'x ;
    obslen+length;
    rc = iter.next();
  end;
  call symputx('obslen',obslen);
  do _n_=1 to 80*ceil(140*nvar/80)-140*nvar;
    put ' ';
  end;

*----------------------------------------------------------------------;
* Write LABELV9 records ;
*----------------------------------------------------------------------;
  if nl_label and ("&version"="V9") then do;
    put "&hdr1.LABELV9 &hdr2." nl_label 12.-L 18*'0' '  ' ;
    bytes=0;
    rc = iter.first();
    do while (rc = 0);
      if length(label)>40 or length(formatn)>8 or length(informn)>8 then do;
        lenname=length(name);
        lenlabel=length(label);
        lenform=length(format);
        leninf =length(informat);
        put (varnum lenname lenlabel lenform leninf) (s370fib2.)
          name $varying32. lenname label $varying256. lenlabel
          format $varying49. lenform informat $varying49. leninf
        ;
        bytes+10+lenname+lenlabel+lenform+leninf ;
      end;
      rc = iter.next();
    end;
    do _n_=1 to 80*ceil(bytes/80)-bytes; put ' '; end;
  end;

*----------------------------------------------------------------------;
* Write OBS record ;
*----------------------------------------------------------------------;
%if (&version = V5) %then %do;
    put "&hdr1.OBS     &hdr2." 30*'0' '  ';
%end; %else %do;
    put "&hdr1.OBSV8   &hdr2." nobs 15.-L 15*'0' '  ';
%end;

%*----------------------------------------------------------------------
Use CALL EXECUTE to generate and run DATA step to write the data.
-----------------------------------------------------------------------;
  call execute('data _null_;');
  call execute("if eof then call symputx('nobs',_n_-1,'L');");
  call execute('file '||symget('fname')||' recfm=n mod;');
  call execute('set '||catx('.',libname,nliteral(memname))||' end=eof;');
  call execute('put ');
  length fmtspec $12;
  rc = iter.first();
  do while (rc = 0);
    if typen=1 then fmtspec=cats('xprtflt',length,'.');
    else fmtspec=cats('$ascii',length,'.');
    call execute(catx(' ',nliteral(name),fmtspec));
    rc = iter.next();
  end;
  call execute(';run;');

%*----------------------------------------------------------------------------
Write note(s) to SAS log about member being written.
-----------------------------------------------------------------------------;
  &note "Writing " libname +(-1) '.' memname "to xport file.";
%if (&version=V5) %then %do;
  &note 'Member has ' l_name 'long variable names.';
  if ndups then &note 'Member has ' ndups 'long names that caused conflicts.';
  &note 'Member has ' l_format 'long format names.';
  &note 'Member has ' l_inform 'long informat names.';
  &note 'Member has ' l_label 'long variable labels.';
  &note 'Member has ' l_length 'long character variables.';
%end;
%*----------------------------------------------------------------------------
Save variable metadata to &OUT dataset.
-----------------------------------------------------------------------------;
  rc = iter.first();
  do while (rc = 0);
    output;
    rc = iter.next();
  end;
  stop;
run;

*----------------------------------------------------------------------;
* Pad with spaces to an even multiple of 80 bytes. ;
*----------------------------------------------------------------------;
data _null_;
  file &fname recfm=n mod;
  do _n_=1 to 80*ceil(&obslen*&nobs/80)-&obslen*&nobs;
    put ' ';
  end;
run;

%do i=2 %to &nds ;
*----------------------------------------------------------------------;
* Recursively call SAS2XPORT macro to append next dataset. ;
*----------------------------------------------------------------------;
  %sas2xport(%scan(&dslist,&i,|),file=&file,append=1,version=&version);
  %if &sysrc %then %goto quit;
%end;

%quit:
%let sysrc=%eval(&parmerr or &sysrc);
%mend sas2xport;
