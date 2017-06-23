%macro varexist
/*----------------------------------------------------------------------
Check for the existence of a specified variable.
----------------------------------------------------------------------*/
(ds        /* Data set name */
,var       /* Variable name */
,info      /* NUM = variable number */
           /* LEN = length of variable */
           /* FMT = format of variable */
           /* INFMT = informat of variable */
           /* LABEL = label of variable */
           /* TYPE  = type of variable (N or C) */
/* Default is to return the variable number  */
);

/*----------------------------------------------------------------------
This code was developed by HOFFMAN CONSULTING as part of a FREEWARE
macro tool set. Its use is restricted to current and former clients of
HOFFMAN CONSULTING as well as other professional colleagues. Questions
and suggestions may be sent to TRHoffman@sprynet.com.
-----------------------------------------------------------------------
Usage:

%if %varexist(&data,NAME)
 %then %put input data set contains variable NAME;

%put Variable &column in &data has type %varexist(&data,&column,type);
------------------------------------------------------------------------
Notes:

The macro calls resolves to 0 when either the data set does not exist
or the variable is not in the specified data set. Invalid values for
the INFO parameter returns a SAS ERROR message.
-----------------------------------------------------------------------
History:

12DEC98 TRHoffman Creation
28NOV99 TRHoffman Added info parameter (thanks Paulette Staum).
----------------------------------------------------------------------*/
%local dsid rc varnum;

%*----------------------------------------------------------------------
Use the SYSFUNC macro to execute the SCL OPEN, VARNUM,
other variable information and CLOSE functions.
-----------------------------------------------------------------------;
%let dsid = %sysfunc(open(&ds));

%if (&dsid) %then %do;
  %let varnum = %sysfunc(varnum(&dsid,&var));

  %if (&varnum) & %length(&info) %then
    %sysfunc(var&info(&dsid,&varnum))
  ;
  %else
    &varnum
  ;

  %let rc = %sysfunc(close(&dsid));
%end;

%else 0;

%mend varexist;
