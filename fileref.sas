%macro fileref
/*----------------------------------------------------------------------------
Verify whether a fileref has been assigned
----------------------------------------------------------------------------*/
(fileref  /* Fileref to test */
);
/*----------------------------------------------------------------------------
A value of zero indicates that the fileref and external file both exist.

A negative return code indicates that the fileref exists but the physical file
associated with the fileref does not exist.

A positive value indicates that the fileref is not assigned.

Note that a fileref must be valid SAS name of length 1 to 8. The macro will
return 1 when an invalid fileref parameter is supplied.
----------------------------------------------------------------------------*/

%*----------------------------------------------------------------------------
FILEREF empty or blank value.
-----------------------------------------------------------------------------;
%if %bquote(&fileref)= %then 1;

%*----------------------------------------------------------------------------
FILEREF too long.
-----------------------------------------------------------------------------;
%else %if %length(&fileref) > 8 %then 1;

%*----------------------------------------------------------------------------
FILEREF not a valid SAS name.
-----------------------------------------------------------------------------;
%else %if 0 = %sysfunc(nvalid(&fileref)) %then 1;

%*----------------------------------------------------------------------------
Return result of the FILEREF() function.
-----------------------------------------------------------------------------;
%else %sysfunc(fileref(&fileref)) ;

%mend fileref;
