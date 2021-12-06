%macro dirtree
/*---------------------------------------------------------------------------
Build dataset of files in directory tree(s)
----------------------------------------------------------------------------*/
(directory    /* Pipe delimited directory list (default=.) */
,out=dirtree  /* Output dataset name */
,maxdepth=120 /* Maximum tree depth */
);
/*---------------------------------------------------------------------------
Use SAS functions to gather list of files and directories

directory - Pipe delimited list of top level directories

out - Dataset to create
maxdepth - Maximum depth of subdirectories to query

Output dataset structure
--NAME-- Len  Format      Description
FILENAME $256             Name of file in directory
TYPE       $1             File or Directory? (F/D)
SIZE        8 COMMA20.    Filesize in bytes
DATE        4 YYMMDD10.   Date file last modified
TIME        4 TOD8.       Time of day file last modified
DEPTH       3             Tree depth
PATH     $256             Directory name

Size is not available for the directories.
LASTMOD timestamp is only available on Unix for directories.

Will not scan the subtree of a directory with a path that is
longer then 256 bytes. For such nodes TYPE will be set to L .

----------------------------------------------------------------------------*/
%local fileref ;
%let fileref=__FL__ ;
%if 0=%length(&directory) %then %let directory=. ;

* Setup dataset and seed with starting directory list ;
data &out;
  length filename $256 type $1 size 8 date time 4 depth 3 path $256 ;
  retain filename ' ' depth 0 type ' ' date . time . size . ;
  format size comma20. date yymmdd10. time tod8. ;
  do _n_=1 to countw(symget('directory'),'|');
    path=scan(symget('directory'),_n_,'|');
    output;
  end;
run;

%* Allow use of empty OUT= dataset parameter ;
%let out=&syslast;

data &out;
  modify &out;
  retain sep "%sysfunc(ifc(&sysscp=WIN,\,/))";
  retain maxdepth &maxdepth;
* Create FILEREF pointing to current file/directory ;
  rc1=filename("&fileref",catx('/',path,filename));
  if rc1 then do;
    length message $256;
    message=sysmsg();
    put 'ERROR: Unable to create fileref for ' path= filename= ;
    put 'ERROR- ' message ;
    stop;
  end;
* Try to open as a directory to determine type ;
  did=dopen("&fileref");
  type = ifc(did,'D','F');
  if type='D' then do;
* Make sure directory name is not too long to store. ;
    if length(catx('/',path,filename)) > vlength(path) then do;
      put 'NOTE: Directory name too long. ' path= filename= ;
      type='L';
      rc3=dclose(did);
    end;
    else do;
* Move filename into the PATH and if on Unix set lastmod ;
      path=catx(sep,path,filename);
      filename=' ';
      if sep='/' then do;
        lastmod = input(dinfo(did,doptname(did,5)),nldatm100.);
        date=datepart(lastmod);
        time=timepart(lastmod);
      end;
    end;
  end;
  else do;
* For a file try to open file and get file information ;
    fid=fopen("&fileref",'i',0,'b');
    if fid then do;
      lastmod = input(finfo(fid,foptname(fid, 5)), nldatm100.);
      date=datepart(lastmod);
      time=timepart(lastmod);
      size = input(finfo(fid,foptname(fid,ifn(sep='/',6,4))),32.);
      rc2 = fclose(fid);
    end;
  end;
* Update the observation in the dataset ;
  replace;
  if type='D' then do;
* When current file is a directory add directory members to dataset ;
    depth=depth+1;
    if depth > maxdepth then put 'NOTE: ' maxdepth= 'reached, not reading members of ' path= ;
    else do i=1 to dnum(did);
      filename=dread(did,i);
      output;
    end;
    rc3=dclose(did);
  end;
* Clear the fileref ;
  rc4=filename("&fileref");
run;

%mend dirtree;
