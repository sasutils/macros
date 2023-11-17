%macro varinfo
/*----------------------------------------------------------------------
Return information for a variable
----------------------------------------------------------------------*/
(ds        /* Dataset name */
,var       /* Variable name */
,info      /* Type of information to return (default=EXIST) */
 /*   EXIST  = Return 1 if the variable exists */
 /*   NUM    = Variable number */
 /*   TYPE   = Type of variable (N for numeric, C for character) */
 /*   LEN    = Length of variable */
 /*   FMT    = Format attached to variable */
 /*   INFMT  = Informat attached to variable */
 /*   LABEL  = Label attached to variable */
 /*   FMTCAT = Use FMTINFO() to find format category */
) / minoperator mindelimiter=' ';

/*----------------------------------------------------------------------
Based on the VAREXIST() macro created by Tom Hoffman in 1998/1999.

Changes from the original VAREXIST() macro are:
  - When INFO is not specified the result is just 0 or 1, not varnum.
  - LABEL is returned as quoted with single quotes.
  - Addition of NUM, EXIST and FMTCAT information options.
  - Better parameter testing of INFO parameter.

Usage examples:

  %if %varinfo(INDS,NAME) %then %put INDS contains variable NAME;
  %put Variable &column in &data has type %varinfo(&data,&column,type);
  %put Variable &NAME has format category %varinfo(&data,&name,cat);
  %put Variable &NAME has label %varinfo(&data,&name,label);
------------------------------------------------------------------------
Notes:

The macro calls resolves to 0 when either the dataset does not exist
or the variable is not in the specified dataset or an invalid INFO
is requested.

------------------------------------------------------------------------
Test cases:

%put |%varinfo(sashelp.stocks,date)|;        %* |1| ;
%put |%varinfo(sashelp.stocks,date,num)|;    %* |2| ;
%put |%varinfo(sashelp.stocks,date,type)|;   %* |N| ;
%put |%varinfo(sashelp.stocks,date,len)|;    %* |8| ;
%put |%varinfo(sashelp.stocks,date,fmt)|;    %* |DATE.| ;
%put |%varinfo(sashelp.stocks,date,fmtcat)|; %* |date| ;
%put |%varinfo(sashelp.stocks,stock,type)|;  %* |C| ;
%put |%varinfo(sashelp.stocks,stock,len)|;   %* |9| ;
%put |%varinfo(sashelp.stocks,stock,fmt)|;   %* || ;
%put |%varinfo(sashelp.stocks,open,fmt)|;    %* |DOLLARY8.2| ;
%put |%varinfo(sashelp.stocks,open,fmtcat)|; %* |curr| ;
%put |%varinfo(sashelp.stocks,open,infmt)|;  %* |BEST32.| ;
%put |%varinfo(sashelp.stocks,adjclose,label)|; %* |'Adjusted Close'| ;
%put |%varinfo(sashelp.stocks,date,label)|;  %* |' '| ;
%put |%varinfo(sashelp.stocks,date,junk)|;   %* |0| and error ;
%put |%varinfo(sashelp.stocks,no_such_var)|; %* |0| ;
%put |%varinfo(no_such_ds,var)|;             %* |0| ;
-----------------------------------------------------------------------
History:

2023-11-03 abernt Creation
----------------------------------------------------------------------*/
%local infos dsid varnum rc fmt return;
%let infos=EXIST NUM TYPE LEN FMT INFMT LABEL FMTCAT;
%let return=0;
%if 0=%length(&info) %then %let info=EXIST;
%else %if not (%qupcase(&info) in (&infos)) %then %do;
  %put ERROR: &sysmacroname: &info is not a valid value for the INFO
parameter.;
  %put ERROR: &sysmacroname: Valid values are: &infos..;
  %goto quit;
%end;
%else %let info=%upcase(&info);

%*----------------------------------------------------------------------
Open the dataset. Find the variable number. Then return requested info.
-----------------------------------------------------------------------;
%let dsid = %sysfunc(open(&ds));
%if (&dsid) %then %do;
  %let varnum = %sysfunc(varnum(&dsid,&var));
  %if (&varnum) %then %do;
    %if (&info=EXIST) %then %let return=1;
    %else %if (&info=NUM) %then %let return=&varnum;
    %else %if (&info=LABEL) %then %do;
      %let return=%qsysfunc(varlabel(&dsid,&varnum));
      %if 0=%length(&return) %then %let return=' ';
      %else %let return=%sysfunc(quote(&return,%str(%')));
    %end;
    %else %if (&info=FMTCAT) %then %do;
      %let fmt=%sysfunc(varfmt(&dsid,&varnum));
      %if %length(&fmt) %then %let fmt
        =%sysfunc(substrn(&fmt,1,%sysfunc(findc(&fmt,.,bsdk))));
      %if %length(&fmt) %then %let return=%sysfunc(fmtinfo(&fmt,cat));
      %else %if N=%sysfunc(vartype(&dsid,&varnum)) %then %let return=num;
      %else %let return=char;
    %end;
    %else %let return=%sysfunc(var&info(&dsid,&varnum));
  %end;
  %let rc = %sysfunc(close(&dsid));
%end;

%quit:
&return.
%mend varinfo;
