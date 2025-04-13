# macros
SAS Utility Macros

A collection of SAS macros of general utility that enhance or extend the SAS macro language.

Macros that return no code at all
 
[bench](bench.sas) [fread(mode=2)](fread.sas) [macdelete](macdelete.sas) [nobs(mvar=)](nobs.sas)
[parmv](parmv.sas) [syslput612](syslput612.sas)

Macros that return string

[catx](catx.sas) [compbl](compbl.sas) [curdir](curdir.sas) [dblibchk](dblibchk.sas)
[direxist](direxist.sas)  [dquote](dquote.sas) [fileref](fileref.sas)  [fread](fread.sas)
[lowcase](lowcase.sas) [missing](missing.sas)  [mvartest](mvartest.sas) [nobs](nobs.sas)
[nvalid](nvalid.sas)  [parsem](parsem.sas) [qcatx](qcatx.sas) [qcompbl](qcompbl.sas) 
[qlist](qlist.sas) [qlowcase](qlowcase.sas) [qsubtrn](qsubstrn.sas)  [qsysget](qsysget.sas)
[squote](squote.sas) [substrn](substrn.sas)  [symget](symget.sas) [tdexist](tdexist.sas)
[varexist](varexist.sas) [varinfo](varinfo.sas) [xpttype](xpttype.sas)

Macros that return SAS statements

Macros that return SAS steps

[cfmtgen](cfmtgen.sas) [contents](contents.sas) [contentv](contentv.sas) [csv2ds](csv2ds.sas)
[csvfile](csvfile.sas) [dbcon](dbcon.sas)  [dirtree](dirtree.sas) [ds2post](ds2post.sas)
[dslist](dslist.sas) [github_include](github_include.sas) [maclist](maclist.sas)
[replace_crlf](replace_crlf.sas) [safe_ds2csv](safe_ds2csv.sas)  [sas2xport](sas2xport.sas)
[subnet](subnet.sas) [xport2sas](xport2sas.sas)

Alphabetical List - With descriptions

* [bench](bench.sas) - Time interval between calls
* [catx](catx.sas) - Replicate the SAS function CATX() in macro code
* [cfmtgen](cfmtgen.sas) - Generate format library with code values included in decodes.
* [compbl](compbl.sas) - Replicate the SAS function COMPBL() in macro code
* [contents](contents.sas) - Use data step and function calls to gather contents information on a dataset
* [contentv](contentv.sas) - Creates VIEW or DATASET containing the data file column attributes
* [csv2ds](csv2ds.sas) - Convert a delimited text file into a SAS dataset
* [csvfile](csvfile.sas) - Write SAS dataset as CSV file
* [curdir](curdir.sas) - Returns (optionally changes) the current working directory physical name
* [dbcon](dbcon.sas) - Summarize the contents of a dataset
* [dblibchk](dblibchk.sas) - Return DBTYPE, DBHOST and DBNAME for an existing SAS/Access library
* [direxist](direxist.sas) - Test if directory exists
* [dirtree](dirtree.sas) - Build dataset of files in directory tree(s)
* [dquote](dquote.sas) - Quote string with double quote characters
* [ds2post](ds2post.sas) - Generate data step suitable for on-line posting to create an existing dataset
* [dslist](dslist.sas) - Generate dataset list to summarize SAS datasets in libraries
* [fileref](fileref.sas) - Verify whether a fileref has been assigned
* [fread](fread.sas) - Reads file using only macro code
* [github_include](github_include.sas) - Run SAS code from github repository
* [lowcase](lowcase.sas) - Replacement for SAS supplied LOWCASE macro that eliminates errors
* [macdelete](macdelete.sas) - Remove compiled macros using %SYSMACDELETE macro statement
* [maclist](maclist.sas) - Generate list of compiled macros and their source directories
* [missing](missing.sas) - Return current MISSING statement settings
* [mvartest](mvartest.sas) - Test for the existence of a macro variable with optional scope limitation
* [nobs](nobs.sas) - Return the number of observations in a dataset reference
* [nvalid](nvalid.sas) - A function style macro that extends the NVALID() SAS function
* [parmv](parmv.sas) - Parameter validation with standard error message generation
* [parsem](parsem.sas) - Macro tool for parsing a macro variable text string
* [qcatx](qcatx.sas) - Mimic CATX() function as a macro function. Return results with macro quoting
* [qcompbl](qcompbl.sas) - Compress multiple spaces into one, return value with macro quoting
* [qlist](qlist.sas) - Adds quotes to each word in a list
* [qlowcase](qlowcase.sas) - Convert to lowercase, return results macro quoted
* [qsubtrn](qsubstrn.sas) - Subset string (simulation of SUBSTRN function), return results macro quoted
* [qsysget](qsysget.sas) - Get macro quoted value of enviroment variable
* [replace_crlf](replace_crlf.sas) - Replace carriage return or linefeed characters that are inside quotes
* [safe_ds2csv](safe_ds2csv.sas) - Write SAS dataset as CSV file insuring proper quoting
* [sas2xport](sas2xport.sas) - Generate SAS V5 or V9 Transport file from SAS datasets/views
* [squote](squote.sas) - Quote string with single quote characters
* [subnet](subnet.sas) - Build connected subnets from pairs of nodes
* [substrn](substrn.sas) - Subset string (simulation of SUBSTRN function)
* [symget](symget.sas) - Get value for macro variable that is hidden by local macro variable
* [syslput612](syslput612.sas) - Copy of old SAS 6.12 autocall macro %SYSLPUT()
* [tdexist](tdexist.sas) - Return type of a teradata table or view to test if it exists
* [varexist](varexist.sas) - Check for the existence of a specified variable
* [varinfo](varinfo.sas) - Return information for a variable
* [xport2sas](xport2sas.sas) - Convert SAS XPORT file to SAS dataset(s)
* [xpttype](xpttype.sas) - Check file to see what type of transport file it is


