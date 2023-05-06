%macro github_include
/*-----------------------------------------------------------------------------
Run SAS code from github repository
-----------------------------------------------------------------------------*/
(namelist  /* Space delimited list of filenames (without the .sas extension) */
,gituser=sasutils  /* GITHUB username */
,repository=macros  /* GITHUB repository */
,branch=master /* GITHUB repository branch */
,source2=      /* Override default setting of SOURCE2 option */
);
%local i url;

%* Adjust value of SOURCE2 parameter to valid syntax for %INCLUDE statement ;
%if %length(&source2) %then %do;
  %if %sysfunc(findw(n no 0 nosource nosource2,&source2,/,sit)) %then %do;
    %let source2=/nosource2;
  %end;
  %else %if %sysfunc(findw(y yes 1 source source2,&source2,/,sit)) %then %do;
    %let source2=/source2;
  %end;
  %else %do;
    %put WARNING: Value &=source2 not recognized.  Will be ignored. ;
    %let source2=;
  %end;
%end;

%do i=1 %to %sysfunc(countw(&namelist,%str( )));
  %let url=https://raw.githubusercontent.com/&gituser/&repository/&branch;
  %let url=%sysfunc(quote(&url/%qscan(&namelist,&i,%str( )).sas,%str(%')));
  filename _github_ url &url;
  %include _github_ &source2;
%end;
filename _github_ ;
%mend github_include;
