/* Caller for %varexist() from sasutils/macros (varexist.sas).
   %varexist checks whether a named variable exists in a dataset,
   returning its variable number (or 0 when the variable or dataset
   doesn't exist) via OPEN()/VARNUM()/CLOSE(). This bundle exercises
   the default no-INFO usage from the macro's own header example:
   testing for the presence of a variable that exists and one that
   doesn't, against a small inline patient table. */

%macro varexist
(ds
,var
,info
);
%local dsid rc varnum;

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

data patients;
  length id 8 sex $1 age 8;
  input id sex $ age;
  datalines;
101 M 34
102 F 29
103 M 51
;
run;

/* Documented usage from the macro's own header:
   %if %varexist(&data,NAME) %then %put input data set contains variable NAME; */
%if %varexist(patients,sex) %then %put case1: patients contains SEX (varnum=%varexist(patients,sex));
%else %put case1: SEX not found (unexpected);

%if %varexist(patients,nosuchvar) %then %put case2: unexpectedly found NOSUCHVAR;
%else %put case2: NOSUCHVAR correctly not found;

%if %varexist(nosuchdataset,sex) %then %put case3: unexpectedly opened NOSUCHDATASET;
%else %put case3: NOSUCHDATASET correctly failed to open;

data check;
  length variable $20 varnum 8 present 8;
  variable='SEX';    varnum=%varexist(patients,sex);        present=(varnum>0); output;
  variable='AGE';    varnum=%varexist(patients,age);        present=(varnum>0); output;
  variable='ID';     varnum=%varexist(patients,id);         present=(varnum>0); output;
  variable='BOGUS';  varnum=%varexist(patients,bogus);      present=(varnum>0); output;
run;

proc print data=check noobs;
run;
