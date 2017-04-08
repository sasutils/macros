%macro csv_vnext
/* Generated delimited file with headers using single data step */
(dsn   /* Input dataset name. DSNoptions allowed */
,outfile=csv  /* Output fileref or quoted filename */
,dlm=',' /* Delimiter character as literal value */
,names=1  /* Write header row? */
,label=0  /* Use LABEL instead of NAME for header row? */
);
/* 
Write a delimited file in a single DATA step
using CALL VNEXT() method for adding the variable names.

Method posted originally by data_null_ in many places.
For example look at this thread on SAS Communities
https://communities.sas.com/t5/Base-SAS-Programming/Output-to-delimited-format/m-p/292767/highlight/true#M60829

To pass a physical name for a file enclose it in quotes.
  %csv_vnext(outfile="myfile.csv")

To pass a different delimiter use a string literal. You can use hex literal.
  %csv_vnext(outfile='myfile.txt',dlm='09'x)

To suppress header row use NAMES=0.
To use LABEL instead of NAME for column header use LABEL=1.

Examples:
    data one;
      set sashelp.shoes(obs=5);
    run;
    filename csv temp;
    %csv_vnext;
    %csv_vnext(dsn=sashelp.shoes(obs=5),outfile=log ls=132,label=1,dlm='^');
    %csv_vnext(outfile=log ls=132,names=0)

*/

data _null_;
  set &dsn;
  file &outfile dsd dlm=&dlm;
%if (&names) %then %do;
  if _n_ eq 1 then link names;
%end;
  put (_all_)(+0);
%if (&names) %then %do;
return;
names:
  length _name_ $255;
  do while(1);
    call vnext(_name_);
    if lowcase(_name_) = '_name_' then leave;
  %if (&label) %then %do;
    _name_ = vlabelx(_name_);
  %end;
    put _name_ @;
  end;
  put; 
%end;
run; 

%mend csv_vnext;