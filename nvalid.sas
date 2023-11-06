%macro nvalid
/*----------------------------------------------------------------------
A function style macro that extends the NVALID() SAS function.
----------------------------------------------------------------------*/
(string     /* String to test whether it is a valid name */
,type       /* Type of name test to perform */
/* Variable names: V6 V7 ANY NLITERAL UPCASE */
/* Member name: MEMNAME COMPAT COMPATIBLE EXTEND */
/* Other names: FILEREF LIBREF FORMAT INFORMAT */
/* Default type taken from VALIDVARNAME option: V7 UPCASE ANY */
/* MEMNAME means use value of VALIDMEMNAME: COMPAT COMPATIBLE EXTEND */
) /minoperator mindelimiter=' ';

/*----------------------------------------------------------------------
A function style macro that extends the NVALID() SAS function.

In addition to the name types supported by NVALID() it adds support for
  - V6 names (length <=8)
  - FORMAT/INFORMAT names
  - MEMBER names.

Meaning of TYPE value choice:
ANY - Any string from 1 to 32 characters long.
V7 - Only contains Letters, digits or _ and does not start with digit.
UPCASE - Same as V7 but lowercase letters not allowed.
V6 - Same as V7 but max length is 8 instead of 32.
NLITERAL - A name that is not V7 valid must be in NLITERAL form.
FILEREF - Same as V6 with additional test if FILEREF is defined
LIBREF  - Same as V6 with additional test if LIBREF is defined
FORMAT  - Same as V7 but allow $ prefix and exclude terminal digit
INFORMAT  - Same as V7 but allow $ prefix and exclude terminal digit
MEMNAME - Valid membername based on VALIDMEMNAME setting.
COMPAT - an alias for COMPATIBLE.
COMPATIBLE - Same as V7 but used for member name.
EXTEND - Same as NLITERAL except there are extra excluded characters.

-----------------------------------------------------------------------
Usage:

%if ^%nvalid(&name) %then %put &name is not a valid SAS name.;
%if ^%nvalid(&name,format) %then %put &name is not a valid format name.;
%if ^%nvalid(&name,fileref) %then %put FILEREF &name is not defined.

-----------------------------------------------------------------------
History:

28OCT2023 abernt Modeled after SASNAME macro from TRHoffman
----------------------------------------------------------------------*/
%local macro types return len maxl dollar;
%let macro=&sysmacroname;
%let types=V6 V7 ANY NLITERAL UPCASE FILEREF LIBREF FORMAT INFORMAT;
%let types=&types MEMNAME COMPAT COMPATIBLE EXTEND;
%let return=0;
%let len=%length(&string);

%*----------------------------------------------------------------------
Check that TYPE value is valid. Set default to VALIDVARNAME setting.
-----------------------------------------------------------------------;
%if 0=%length(&type) %then %let type=%sysfunc(getoption(validvarname));
%if not (%qupcase(&type) in &types) %then %do;
  %put ERROR: &macro: &type. is not a valid value for the TYPE parameter.;
  %put ERROR: &macro: Valid values are: &types ;
  %goto quit;
%end;
%else %let type=%qupcase(&type);

%if &type = MEMNAME %then %do;
%*----------------------------------------------------------------------
Use value of VALIDMEMNAME option as TYPE.
-----------------------------------------------------------------------;
  %let type=%sysfunc(getoption(validmemname));
%end;

%*----------------------------------------------------------------------
Set maximum length based on TYPE selected.
-----------------------------------------------------------------------;
%if &type in (V6 LIBREF FILEREF) %then %let maxl=8;
%else %if &type in (EXTEND NLITERAL) %then %let maxl=67;
%else %let maxl=32;

%*----------------------------------------------------------------------
Fail when string is empty or too long.
-----------------------------------------------------------------------;
%if 0=&len or (&len>&maxl) %then %goto quit;

%if &type in (V7 ANY NLITERAL UPCASE) %then %do;
%*----------------------------------------------------------------------
For types supported by NVALID() just call it directly.
-----------------------------------------------------------------------;
  %let return=%sysfunc(nvalid(&string,&type));
%end;
%else %if &type in (FORMAT INFORMAT) %then %do;
%*----------------------------------------------------------------------
FORMAT|INFORMAT - Last character cannot be a digit. Ignore leading $.
-----------------------------------------------------------------------;
  %let dollar=%eval(%qsubstr(&string|,1,1)=$);
  %if &string = $ %then %let return=1;
  %else %if %sysfunc(notdigit(&string,&len)) %then
    %let return=%sysfunc(nvalid(%qsubstr(&string,1+&dollar),v7));
%end;
%else %if &type = FILEREF %then %do;
%*----------------------------------------------------------------------
FILEREF - Test if function of same name returns non positive value.
-----------------------------------------------------------------------;
  %let return=%eval(%sysfunc(fileref(&string))<=0);
%end;
%else %if &type = LIBREF %then %do;
%*----------------------------------------------------------------------
LIBREF - Test if function of same name returns zero.
-----------------------------------------------------------------------;
  %let return=%eval(0=%sysfunc(libref(&string)));
%end;
%else %if &type in (V6 COMPAT COMPATIBLE) %then %do;
%*----------------------------------------------------------------------
V6 - Same as V7 since length already checked.
COMPAT or COMPATIBLE - Same as V7.
-----------------------------------------------------------------------;
  %let return=%sysfunc(nvalid(&string,v7));
%end;
%else %if &type = EXTEND %then %do;
%*----------------------------------------------------------------------
EXTEND memname - Same as NLITERAL but some characters cannot be used.
  Cannot start with space or period.
  If it is V7 then valid. Then if NLITERAL then check if name without
  quotes and N has any of the extra characters.  Otherwise if ANY
  check if the value itself has any of the extra characters.
-----------------------------------------------------------------------;
  %if %sysfunc(nvalid(&string,v7)) %then %let return=1;
  %else %if %sysfunc(nvalid(&string,nliteral)) %then %do;
    %if ^%index(%str( .),%qsubstr(&string,2,1)) %then %let return
      =%eval(0=%sysfunc(indexc(%qsysfunc(dequote(&string)),"/\*?<>|:-")));
  %end;
  %else %if ^%index(%str( .),%qsubstr(&string,1,1)) and
        %sysfunc(nvalid(&string,any)) %then %let return
       =%eval(0=%sysfunc(indexc(&string,"/\*?<>|:-")))
  ;
%end;

%quit:
&return.
%mend nvalid;
