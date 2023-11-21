%macro xport2sas
/*----------------------------------------------------------------------------
Convert SAS XPORT file to SAS dataset(s)
----------------------------------------------------------------------------*/
(filespec    /* Fileref or quoted physical name of XPORT file (REQ) */
,libref=     /* Target library. (Default=WORK) */
,memlist=    /* Space delimited member name list. (default=_ALL_) */
,out=        /* Name of dataset to store metadata. (Optional) */
,sascode=    /* Fileref or quoted physical name of generated SAS code file (OPT) */
,recfm=      /* F or N to use INFILE. (Default=N except on MVS/OS) */
);
/*----------------------------------------------------------------------------
XPORT2SAS is a cleaned up version of XPT2LOC autocall macro for converting
XPORT file(s) into SAS datasets.

Can handle V5 transport files written by the XPORT library engine or V8/9
versions written by the %LOC2XPT() macro from SAS. Can find long variable
names in V5 transport files created by the %SAS2XPORT() macro.

If the file is a CPORT file instead of an XPORT file then it will generate
PROC CIMPORT code instead.

Enhancements over XPT2LOC macro include:
- Detects and adapts to CPORT files.
- Handles zero variable and zero observation datasets.
- Handles extra LIBRARY records when reading multiple XPORT files together.
- Handles some file format errors generated by third party software.
  - Invalid format specifications in LABELV9 records.
  - Binary zeros in character fields.
- Allows forcing file to be read using RECFM=F.
  - Needed when RECFM=N does not work properly.
  - RECFM=N code will not conflict with any dataset variable names.
- Includes macro parameter validation.
- Allows saving metadata to a dataset.
- Allows saving generated code to a file.
- Uses system generated fileref names to avoid conflicts.
- Allows nliteral memnames in MEMLIST parameter.
- All code contained in single macro.

Usage Notes:
- Use OUT parameter to save the metadata about the XPORT file to a dataset.
- Use SASCODE parameter to save the SAS program created to a file.
- Use RECFM parameter to force use of RECFM=N or RECFM=F when reading
    the XPORT file.  When using RECFM=N the LRECL is set to the least
    common multiple of 320 and the observation length to avoid reading
    across input buffers. Uses 320 instead of just 80 to insure that LRECL
    is larger than 256.  In theory this might be too large a value for
    some datasets, in which case you should force it to use RECFM=F.
- The default RECFM for MVS is F because according to XPT2LOC macro code
    on MVS RECFM=N does not work properly (claim has not been tested).
- Use RECFM=F when reading multiple files, such as all members in a ZIP file.
- Creates the following series of local macro variables (one per dataset).
  first_recN   ...  Starting 80 byte record for member N
  first_byteN  ...  Starting location for member N
  nobsN        ...  Number of observations for member N
  obslenN      ...  Length of an observation for member N
  maxvarN      ...  Maximum variable length for member N
- Uses newer SAS features, so on older SAS versions might need to use XPT2LOC.

----------------------------------------------------------------------------*/
%local parmerr memfound mvs ftype qfilespec datastep inputstmt rc cport;
%local i member memlistn memlistp ;
%let parmerr=0;
%let memfound=0;
%let cport=0;
%let mvs=%eval("&sysscp"="OS");

%*----------------------------------------------------------------------------
Validate input parameters.
-----------------------------------------------------------------------------;

%*----------------------------------------------------------------------------
Make sure FILESPEC is either an existing FILEREF or an existing FILE.
-----------------------------------------------------------------------------;
%let ftype=;
%if %length(&filespec) %then %do;
  %if %length(&filespec)<=8 & %sysfunc(nvalid(&filespec,v7)) %then %do;
    %if 0=%sysfunc(fileref(&filespec)) %then %let ftype=fileref;
  %end;
  %if (&ftype=) and %sysfunc(fileexist(&filespec)) %then %do;
    %let ftype=file;
    %let filespec=%sysfunc(quote(%qsysfunc(dequote(&filespec)),%str(%')));
  %end;
%end;
%if 0=%length(&ftype) %then %do;
  %if 0=%length(&filespec) %then %put ERROR: FILESPEC is required.;
  %else %put ERROR: XPORT file not found. &=filespec ;
%end;
%if 0=%length(&ftype) %then %let parmerr=1;
%let qfilespec=%sysfunc(quote(&filespec,%str(%')));

%*----------------------------------------------------------------------------
Make sure SASCODE is either an existing FILEREF or valid as a filename.
When SASCODE is not specified then make a temporary file and remove it after.
-----------------------------------------------------------------------------;
%let ftype=;
%if %length(&sascode) %then %do;
  %if %length(&sascode)<=8 and %sysfunc(nvalid(&sascode,v7)) %then %do;
    %if %sysfunc(fileref(&sascode))<=0 %then %let ftype=fileref;
  %end;
  %if (&ftype=) %then %do;
    %if %sysfunc(filename(ftype,&sascode))<=0 %then %do;
       %let rc=%sysfunc(filename(ftype));
       %let ftype=file;
       %let sascode=%sysfunc(quote(%qsysfunc(dequote(&sascode)),%str(%')));
    %end;
  %end;
%end;
%else %do;
  %if 0=%sysfunc(filename(sascode,,temp)) %then %let ftype=temp;
  %else %put ERROR: Unable to create temporary file for SASCODE.;
%end;
%if 0=%length(&ftype) %then %let parmerr=1;

%*----------------------------------------------------------------------------
Make sure LIBREF is valid name and exists.
-----------------------------------------------------------------------------;
%if %length(&libref) %then %do;
  %let parmerr=1;
  %if %length(&libref)>8 or not %sysfunc(nvalid(&libref,v7)) %then %do;
    %put ERROR: &=libref is not a valid SAS name.;
  %end;
  %else %if %sysfunc(libref(&libref)) %then %put ERROR: &=libref is not defined.;
  %else %let parmerr=0;
%end;
%else %let libref=WORK;

%*----------------------------------------------------------------------------
Set default for RECFM based on whether or not running on MVS.
-----------------------------------------------------------------------------;
%if %length(&recfm) %then %do;
  %if %length(&recfm)>1 or %sysfunc(verify(%superq(recfm),FNfn)) %then %do;
    %put ERROR: &=recfm is invalid. Valid values are F or N. ;
    %let parmerr=1;
  %end;
  %else %let recfm=%upcase(&recfm);
%end;
%else %if &mvs %then %let recfm=F ;
%else %let recfm=N ;

%*----------------------------------------------------------------------------
Make sure OUT parameter at least looks like a dataset name.
-----------------------------------------------------------------------------;
%if 0=%length(&out) %then %let out=_null_;
%else %do;
  %if %sysfunc(countw(&out,.,q))>2 %then %do;
    %put ERROR: &=out invalid. Cannot have more than two levels.;
    %let parmerr=1;
  %end;
%end;

%*----------------------------------------------------------------------------
Create MEMLISTP from MEMLIST.
-----------------------------------------------------------------------------;
%if 0=%length(&memlist) %then %let memlist=_ALL_;
%do i=1 %to %sysfunc(countw(&memlist,%str( ),q));
  %let member=%qscan(&memlist,&i,%str( ),q);
  %if %sysfunc(nvalid(&member,nliteral)) %then %do;
    %let memlistp=&memlistp|%qsysfunc(dequote(%qupcase(&member)));
  %end;
  %else %do;
    %put ERROR: &sysmacroname: &member is not a valid member name.;
    %let parmerr=1;
  %end;
%end;

%if (&parmerr) %then %goto quit;

%*----------------------------------------------------------------------------
Create temporary files for writing the SAS code while reading metadata.
Use RECFM=F just in case any label strings contain end of line characters.
-----------------------------------------------------------------------------;
%if %sysfunc(filename(datastep,,temp,recfm=f lrecl=1024))
 or %sysfunc(filename(inputstmt,,temp,recfm=f lrecl=1024)) %then %do;
  %put ERROR: Unable to allocate temporary files for writing code. ;
  %let parmerr=1;
%end;

%if (&parmerr) %then %goto quit;

%if (&recfm=F) %then %do;
%*----------------------------------------------------------------------------
Local macro variables used to allow generatation of input code that uses only
temporary variables and arrays to avoid conflict with any dataset variables.
-----------------------------------------------------------------------------;
  %local len col loc part buffer record ;
  %let len=_numeric_(1);
  %let col=_numeric_(2);
  %let loc=_numeric_(3);
  %let part=_n_;
  %let buffer=_char_(1);
  %let record=_character_(1);
%end;

/*----------------------------------------------------------------------------
This DATA step will read through the entire transport file.
It will determine all the metadata for the SAS datasets defined therein, and
it will generate corresponding DATA step code to reproduce the data for the
requested datasets.

Writes the code into two separate files which will later be interleaved.
---------------------------------------------------------------------------*/
data &out;
  infile &filespec. recfm=f lrecl=80 eof=atend;
  length memnum skip 8 memname $32 typemem $8 varnum 8 name $32 typen 8 type $4
         length 8 format informat $49 label $256 nvar nobs obslen maxvar 8
         memlabel $40 sasver $8 osname $8 crdate modate 8
         rectype $8 formatn informn $32 nliteral $67
         record lastrec $80 buffer qstr $512
  ;
  keep memnum -- modate ;
  format crdate modate datetime19.;
  retain memname typemem memlabel nlabels lastrec sasver osname crdate modate;
  retain firstobs 0 extra_library 0;
  retain memnum 0 recnum 1 skip 0 col 1 nvar 0 nreclen 140 ;
  retain obslen 0 maxvar 0 nlabels 0 nobs .;

/*----------------------------------------------------------------------------
Check for header record and process based the record type.
----------------------------------------------------------------------------*/
  len=80; link read; buffer=input(buffer,$ascii80.);
  if _n_=1 then if buffer=:'**COMPRESSED** **COMPRESSED** **COMPRESSED** '
        ||'**COMPRESSED** **COMPRESSED********' then do;
    putlog "NOTE: &sysmacroname: File is a CPORT file not an XPORT file.";
    call symputx('cport','1');
    stop;
  end;
  if (substr(buffer, 1,20)='HEADER RECORD*******') and
     (substr(buffer,29,20)='HEADER RECORD!!!!!!!') then
    rectype=substr(buffer,21,8);
  select (rectype);
    when ('LIBRARY','LIBV8')   link process_library_record;
    when ('MEMBER','MEMBV8')   link process_member_record;
    when ('DSCRPTR','DSCPTV8') link process_desc_record;
    when ('NAMESTR','NAMSTV8') link process_name_records;
    when ('LABELV8','LABELV9') link process_label_records;
    when ('OBS','OBSV8')       link process_obs_record;
    otherwise lastrec=buffer;
  end;
return;

atend:;
/*----------------------------------------------------------------------------
INFILE statement EOF= option directs here when end of file is reached.
----------------------------------------------------------------------------*/
  recnum+1;
  call symputx('memfound',memfound,'L');

fobslobs:;
/*----------------------------------------------------------------------------
Hit either EOF or a new MEMBER record.

When NOBS is missing then calculate based on the number of 80 byte records.
Ignore any trailing records that are totally blank.

Store NOBS, FIRSTOBS, MAXVAR and FIRSTBYTE into macro variables.
----------------------------------------------------------------------------*/
  if nvar=0 then nobs=0;
  if nobs=. then do;
    nobs=max(0,floor((recnum-firstobs-1-extra_library)*80 / obslen));
    if obslen<80 and nobs>0 then do;
      j=mod(nobs*obslen,80);
      if j=0 then j=80;
      do j=j+1-obslen to 1 by -obslen;
        if substr(lastrec,j,obslen) ne ' ' then leave;
        else nobs=nobs-1;
      end;
    end;
  end;
  if nvar=0 then output;
  call symputx(cats('first_rec',memnum),firstobs,'L');
  call symputx(cats('first_byte',memnum),(firstobs-1)*80+1,'L');
  call symputx(cats('nobs',memnum),nobs,'L');
  call symputx(cats('obslen',memnum),obslen,'L');
  call symputx(cats('maxvar',memnum),maxvar,'L');
  firstobs=0;call missing(memname,nvar,obslen,maxvar,nobs);
return;

read:;
/*----------------------------------------------------------------------------
Read in LEN bytes using a custom buffer. This allows for reading values that
span the 80 byte boundary. It will also keep track of the number of records.
----------------------------------------------------------------------------*/
  buffer=' '; loc=1; len2=len;
  do while(len2>0);
    if col>80 then do;
      recnum+1;
      col=1;
    end;
    partl=max(0,min(80-col+1,len2));
    input record $varying80. partl @@;
    substr(buffer,loc,partl)=record;
    loc+partl; col+partl; len2=len2-partl;
  end;
return;

process_library_record:;
/*----------------------------------------------------------------------------
Read information about file creation.
----------------------------------------------------------------------------*/
  if _n_>1 then extra_library+3;
  len=160; link read; buffer=translate(input(buffer,$ascii160.),' ','00'x);
  sas1=substr(buffer,1,8);
  sas2=substr(buffer,9,8);
  sasver=substr(buffer,25,8);
  osname=substr(buffer,33,8);
  crdate=input(substr(buffer,65,16),??datetime16.);
  modate=input(substr(buffer,81,16),??datetime16.);
return;

process_member_record:;
/*----------------------------------------------------------------------------
Process the MEMBER record.
----------------------------------------------------------------------------*/
  if memnum>0 then link fobslobs;
  memnum+1; skip=0;
  nreclen=input(substr(buffer,76),4.);
  if nreclen not in (136 140) then do;
    putlog 'WARNING: Invalid name record length ' nreclen 'on ' rectype
           'record. Will use 140 bytes.';
    nreclen=140;
  end;
return;

process_desc_record:;
/*----------------------------------------------------------------------------
Read member descriptor record (160 bytes).
  MEMNAME is 8 bytes for V5 and 32 for V8.
  LABEL is 40 bytes (even for V8/9 XPORT file)

If MEMLIST is provided then test member name and set SKIP flag.

Start writing the SAS code to read the dataset.
----------------------------------------------------------------------------*/
  len=160; link read; buffer=translate(input(buffer,$ascii160.),' ','00'x);
  sas1=substr(buffer,1,8);
  if rectype='DSCRPTR' then pos=8;
  else pos=32;
  memname=substr(buffer,9,pos);
  nliteral=nliteral(memname);
  sasver=substr(buffer,17+pos,8);
  osname=substr(buffer,25+pos,8);
  crdate=input(substr(buffer,65,16),??datetime16.);
  modate=input(substr(buffer,81,16),??datetime16.);
  memlabel=substr(buffer,113,40);
  typemem=substr(buffer,153,8);
%if (%superq(memlist) ne _ALL_) %then %do;
  if not findw("&memlistp",memname,'|','iros') then do;
     putlog 'NOTE: Skipping member ' nliteral ;
     skip=1;
  end;
%end;
/*----------------------------------------------------------------------------
Write DATA statement for this member.
For RECFM=N set LRECL to least common multiple of 320 and the obs length.
----------------------------------------------------------------------------*/
  if not skip then do;
    memfound+1;
    file &datastep;
    put "data &libref.." nliteral @;
    if cmiss(typemem,memlabel)<2 then put '(' @;
    if typemem ne ' ' then put 'type=' typemem :$quote. @ ;
    if memlabel ne ' ' then do;
      qstr=quote(trim(memlabel),"'");
      put 'label=' qstr @;
    end;
    if cmiss(typemem,memlabel)<2 then put ')' @;
    put ';' / 'if _n_>&nobs' memnum +(-1) '. then stop;';
%if (&recfm=F) %then %do;
    put 'infile ' &qfilespec ' recfm=f lrecl=80 '
        'firstobs=&first_rec' memnum +(-1) '.;'
      / 'array &loc _temporary_ (1 1 1);'
      / 'array &buffer $&maxvar' memnum +(-1) '. _temporary_ ;'
      / 'array &record $80 _temporary_;'
    ;
%end;
%else %do;
    put 'infile ' &qfilespec ' unbuffered recfm=n lrecl='
        '%sysfunc(lcm(320,&obslen' memnum +(-1) '.));'
      / 'if _n_=1 then input @&first_byte' memnum +(-1) '. @;'
    ;
*----------------------------------------------------------------------------;
* Write start of INPUT statement ;
*----------------------------------------------------------------------------;
    file &inputstmt;
    put 'input';
%end;
  end;
return;

process_name_records:;
/*----------------------------------------------------------------------------
Read variable descriptors. They are streamed together. NRECLEN bytes for each.
The V8 namestr uses 32 bytes at the end to hold a long variable name.
Generate LENGTH and any FORMAT, INFORMAT or LABEL statements needed.
----------------------------------------------------------------------------*/
  obslen=0; maxvar=0;
  nvar=input(substr(buffer,53,6),6.);
  do varnum=1 to nvar;
    len=nreclen;link read;
    typen    = input(substr(buffer,  1, 2),s370fpib2.);
    length   = input(substr(buffer,  5, 2),s370fpib2.);
    name     = input(substr(buffer,  9, 8),$ascii8.  );
    label    = input(substr(buffer, 17,40),$ascii40.);
    formatn  = input(substr(buffer, 57, 8),$ascii8.);
    formatl  = input(substr(buffer, 65, 2),s370fpib2.);
    formatd  = input(substr(buffer, 67, 2),s370fpib2.);
    just     = input(substr(buffer, 69, 2),s370fpib2.);
    informn  = input(substr(buffer, 73, 8),$ascii8.);
    informl  = input(substr(buffer, 81, 2),s370fpib2.);
    informd  = input(substr(buffer, 83, 2),s370fpib2.);
    obslen+length;
/*----------------------------------------------------------------------------
Convert typen to type. Check for invalid values.
----------------------------------------------------------------------------*/
    if typen=1 then type='num'; else if typen=2 then type='char';
    else do;
      putlog 'WARNING: Invalid variable type= ' typen '. Will use CHAR.'
            memnum= varnum= name=:$quote. ;
      typen=2; type='char';
    end;
/*----------------------------------------------------------------------------
Replace any binary zeros in character fields with spaces.
----------------------------------------------------------------------------*/
    if index(name,'00'x) then do;
      name=translate(name,' ','00'x);
      putlog 'WARNING: Removed binary zeros from NAME. ' memnum= varnum=;
    end;
    if index(label,'00'x) then do;
      putlog 'WARNING: Removed binary zeros from LABEL. ' memnum= varnum=;
      label=translate(label,' ','00'x);
    end;
    if index(formatn,'00'x) then do;
      putlog 'WARNING: Removed binary zeros from FORMAT name. ' memnum= varnum=;
      formatn=translate(formatn,' ','00'x);
    end;
    if index(informn,'00'x) then do;
      putlog 'WARNING: Removed binary zeros from INFORMAT name. ' memnum= varnum=;
      informn=translate(informn,' ','00'x);
    end;
    label_len   = lengthn(label);
    formatn_len = lengthn(formatn);
    informn_len = lengthn(informn);
/*----------------------------------------------------------------------------
For V8/V9 read long name and actual lengths of LABEL, FORMAT and INFORMAT.
Also use when first 8 bytes of extended name match short name.
----------------------------------------------------------------------------*/
    if rectype='NAMSTV8' or not indexc(substr(buffer,89,40),'00'x) then do;
       name      =   input(substr(buffer, 89,32),$ascii32.);
       label_len =   input(substr(buffer,121, 2),s370fpib2.);
       formatn_len = input(substr(buffer,123, 2),s370fpib2.);
       informn_len = input(substr(buffer,125, 2),s370fpib2.);
    end;
    maxvar=max(maxvar,length);
    nliteral=nliteral(name);
/*----------------------------------------------------------------------------
Build FORMAT and INFORMAT from NAME, WIDTH and DECIMAL values.
----------------------------------------------------------------------------*/
    call missing(format,informat);
    if formatn_len<=8 then if formatn ne ' ' or formatl or formatd then
      format=cats(char(' $',typen),compress(formatn,'$')
          ,ifc(formatl,cats(formatl),' '),'.',ifc(formatd,cats(formatd),' '));
    if informn_len<=8 then if informn ne ' ' or informl or informd then
      informat=cats(char(' $',typen),compress(informn,'$')
          ,ifc(informl,cats(informl),' '),'.',ifc(informd,cats(informd),' '));
    output;
    if not skip then do;
*----------------------------------------------------------------------------;
* Write LENGTH and optionally FORMAT, INFORMAT and LABEL statements ;
*----------------------------------------------------------------------------;
      file &datastep;
      len2=length;
      if type='char' then c='$'; else c=' ';
      if type='num' and len2=2 and not &mvs then len2=3;
      put 'length ' nliteral c +(-1) len2 ';';
      if format ne ' ' then put 'format ' nliteral format ';';
      if informat ne ' ' then put 'informat ' nliteral informat ';';
      if label ne ' ' then do;
        qstr=quote(trim(label),"'");
        put 'label ' nliteral '= ' qstr ';';
      end;
*----------------------------------------------------------------------------;
* Write code to INPUT the variable ;
*----------------------------------------------------------------------------;
      file &inputstmt;
      if type='num' then qstr=cats('xprtflt',length,'.');
      else qstr=cats('$ascii',length,'.');
%if (&recfm=N) %then %do;
      put nliteral qstr ;
%end;
%else %do;
      put '&len=' length ';link read;' nliteral '=input(&buffer,' qstr ');';
%end;
    end;
  end;
  len=81-col; link read;
return;

process_label_records:;
/*----------------------------------------------------------------------------
Read in V8/V9 LABEL record
----------------------------------------------------------------------------*/
  nlabels=input(substr(buffer,49,12),12.);
  do i=1 to nlabels;
    call missing(name,type,label,format,informat,formatn,informn);
    len=6; link read;
    varnum=input(substr(buffer,1,2),s370fpib2.);
    name_len=input(substr(buffer,3,2),s370fpib2.);
    label_len=input(substr(buffer,5,2),s370fpib2.);
    if rectype='LABELV9' then do;
      len=4; link read;
      formatn_len=input(substr(buffer,1,2),s370fpib2.);
      informn_len=input(substr(buffer,3,2),s370fpib2.);
    end;
    len=name_len+label_len; link read;
    name=substrn(buffer,1,name_len);
    label=substrn(buffer,name_len+1,label_len);
    if indexc(cats(name,label),'00'x) then do;
       putlog 'WARNING: Removing binary zeros from NAME or LABEL.' memnum= varnum=;
       name=translate(name,' ','00'x);
       label=translate(label,' ','00'x);
    end;
    nliteral=nliteral(name);
    if rectype='LABELV9' then do;
      len=formatn_len+informn_len; link read;
      format=substrn(buffer,1,formatn_len);
      informat=substrn(buffer,formatn_len+1,informn_len);
      if indexc(format,'00'x) then do;
         putlog 'WARNING: Removing binary zeros from FORMAT for ' memnum= varnum= nliteral ;
         format=translate(format,' ','00'x);
      end;
      if indexc(informat,'00'x) then do;
         putlog 'WARNING: Removing binary zeros from INFORMAT for ' memnum= varnum= nliteral ;
         informat=translate(informat,' ','00'x);
      end;
      if format ne ' ' then do;
        if format in ('$.' '.') or 0=indexc(format,'.') then do;
          putlog 'WARNING: Removing invalid ' format=:$quote.
                 'from variable ' nliteral 'in ' memname
          ;
          format=' ';
        end;
      end;
      formatn=substrn(format,1,findc(format,'.','bsdk'));
      formatl=input(scan('0'||substrn(format,lengthn(formatn)+1),1),??32.);
      formatd=input('0'||substrn(format,findc(format,'.')+1),??32.);
      if informat ne ' ' then do;
        if informat in ('$.' '.') or 0=indexc(informat,'.') then do;
          putlog 'WARNING: Removing invalid ' informat=:$quote.
                 'from variable ' nliteral 'in ' memname
          ;
          informat=' ';
        end;
      end;
      informn=substrn(informat,1,findc(informat,'.','bsdk'));
      informl=input(scan('0'||substrn(informat,lengthn(informn)+1),1),??32.);
      informd=input('0'||substrn(informat,findc(informat,'.')+1),??32.);
    end;
    output;
*----------------------------------------------------------------------------;
* Write LABEL or FORMAT or INFORMAT statement ;
*----------------------------------------------------------------------------;
    if not skip then do;
      file &datastep;
      if label ne ' ' then do;
        qstr=quote(trim(label),"'");
        put 'label ' nliteral '= ' qstr ';';
      end;
      if format ne ' ' then put 'format ' nliteral format ';';
      if informat ne ' ' then put 'informat ' nliteral informat ';';
    end;
  end;
  len=81-col; link read;
return;

process_obs_record:;
/*----------------------------------------------------------------------------
Read NOBS from the OBS record.
Remember RECNUM+1 as the record number where the data starts for this dataset.
Write comment to INPUT program file to indicate the end of INPUT.
Write code that follows the input statement to the main program.
----------------------------------------------------------------------------*/
  if substr(buffer,49,15) ne '000000000000000' then do;
    nobs=input(substr(buffer,49,15),15.);
  end;
  else nobs=.;
  firstobs=recnum+1; extra_library=0;
  if not skip then do;
    file &inputstmt;
%if (&recfm=N) %then %do;
    put '@@;';
%end;
    put '/* INPUT STATEMENT END */';
    file &datastep;
    put '/* INPUT STATEMENT START */';
%if (&recfm=F) %then %do;
    if nvar then put 'return;'
       /'read:'
       /"  &buffer=' '; &loc=1;"
       /"  do while(&len>0);"
       /"    if &col>80 then &col=1;"
       /"    &part=max(0,min(80-&col+1,&len));"
       /"    input &record $varying80. &part @@;"
       /"    substr(&buffer,&loc,&part)=&record;"
       /"    &len+-&part;"
       /"    &col+&part;"
       /"    &loc+&part;"
       /"  end;"
       /"return;"
    ;
%end;
    put 'run;';
  end;
return;

/*----------------------------------------------------------------------------
End of data step that reads the xport file and generates the code to read the
requested members into datasets.
----------------------------------------------------------------------------*/
run;

%if (&cport) %then %do;
/*----------------------------------------------------------------------------
Found CPORT file instead of XPORT file so generate PROC CIMPORT code.
----------------------------------------------------------------------------*/
  proc cimport file=&filespec lib=&libref;
    select &memlist ;
  run;
  %goto quit;
%end;

%if (%qupcase(&out) ne _NULL_) %then %do;
/*----------------------------------------------------------------------------
Update the NAME metadata with LABEL metadata. Get member summary variables.
----------------------------------------------------------------------------*/
proc sort data=&out;
  by memnum varnum;
run;
data &out;
  update &out(obs=0) &out;
  by memnum varnum;
  nobs=symgetn(cats('nobs',memnum));
  obslen=symgetn(cats('obslen',memnum));
  maxvar=symgetn(cats('maxvar',memnum));
run;
%end;

%if (0=&memfound) %then %do;
  %put NOTE: No members in &=memlist were found.;
%end;
%else %do;
/*----------------------------------------------------------------------------
Read back in the two generated code files and combine them so that the input
statements are in the right place.
Include code to define the special numeric informat needed to read XPORT data.
Resolve any macro variable references and remove trailing spaces from lines.
Original files intentially written as fixed length to avoid any issues that
embedded line breaks might cause with the RESOLVE() function call.
----------------------------------------------------------------------------*/
data _null_;
  file &sascode recfm=v lrecl=1024;
  if _n_= 1 then put
 '%if not %sysfunc(cexist(work.formats.xprtflt.infmt)) %then %do;'
/'*------------------------------------------------------------------------;'
/'* Define the XPRTFLT informat to support reading missing numeric values. ;'
/'*------------------------------------------------------------------------;'
/'proc format;'
/'  invalue xprtflt'
/"    '2E00000000000000'x=."
/"    '4100000000000000'x=.A  '4200000000000000'x=.B  '4300000000000000'x=.C"
/"    '4400000000000000'x=.D  '4500000000000000'x=.E  '4600000000000000'x=.F"
/"    '4700000000000000'x=.G  '4800000000000000'x=.H  '4900000000000000'x=.I"
/"    '4A00000000000000'x=.J  '4B00000000000000'x=.K  '4C00000000000000'x=.L"
/"    '4D00000000000000'x=.M  '4E00000000000000'x=.N  '4F00000000000000'x=.O"
/"    '5000000000000000'x=.P  '5100000000000000'x=.Q  '5200000000000000'x=.R"
/"    '5300000000000000'x=.S  '5400000000000000'x=.T  '5500000000000000'x=.U"
/"    '5600000000000000'x=.V  '5700000000000000'x=.W  '5800000000000000'x=.X"
/"    '5900000000000000'x=.Y  '5A00000000000000'x=.Z  '5F00000000000000'x=._"
/"    other=(|s370frb8.|);"
/"run;"
/'%end;'
  ;
  retain frominput 0;
  if frominput then infile &inputstmt;
  else infile &datastep;
  input;
  if _infile_='/* INPUT STATEMENT START */' then frominput=1;
  else if _infile_='/* INPUT STATEMENT END */' then frominput=0;
  else _infile_=resolve(_infile_);
  len=lengthn(_infile_);
  put _infile_ $varying1024. len;
run;

*----------------------------------------------------------------------------;
* Run the generated SAS code ;
*----------------------------------------------------------------------------;
%include &sascode;
%end;

%quit:
/*----------------------------------------------------------------------------
Remove temporary files.
----------------------------------------------------------------------------*/
%if %length(&datastep ) %then %let rc=%sysfunc(filename(datastep));
%if %length(&inputstmt) %then %let rc=%sysfunc(filename(inputstmt));
%if (&ftype=temp) %then %let rc=%sysfunc(filename(sascode));

%mend xport2sas;
