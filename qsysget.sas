%macro qsysget
/*----------------------------------------------------------------------
Get macro quoted value of enviroment variable
----------------------------------------------------------------------*/
(name  /* Name of environment variable */
);
/*----------------------------------------------------------------------
Returns the macro quoted value of the named environment variable.

The macro function %SYSGET() does not mask macro triggers. This can 
cause issues when the value of the macro variable contains special 
characters like:  & % ; 

So this macro uses the %QSYSFUNC() macro function to call the regular
SAS function SYSGET() instead so that macro quoting is applied.

SYSRC global macro variable has status of whether the environment 
variable was found or not. 
  1 = Environment variable not found. 
  0 = Environment variable found.
----------------------------------------------------------------------*/
%let sysrc=0;
%if -1=%sysfunc(envlen(&name)) %then %let sysrc=1;
%else %qsysfunc(sysget(&name));
%mend qsysget;
