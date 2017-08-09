%macro syslput612(macvar,macval,remote=);
/*--------------------------------------------------------------
  *
  *                 SAS  TEST  LIBRARY
  *
  *      NAME: SYSLPUT
  *     TITLE: MACRO FOR CREATING REMOTE MACRO VARIABLES
  *     INPUT:
  *    OUTPUT:
  *  SPEC.REQ:
  *   SYSTEMS: ALL
  *   PRODUCT: SAS/CONNECT
  *      KEYS:
  *       REF:
  *  COMMENTS:
  *   SUPPORT: LANGSTON, B.
  *    UPDATE: 01mar95.
  *
  *--------------------------------------------------------------*/
 /****************************************************************/
 /*  SYSLPUT is the opposite of SYSRPUT.  SYSLPUT creates a macro*/
 /*   variable in the remote environment.  The user must specify */
 /*   the macro variable and its value.  Optionally, the user    */
 /*   may specify the remote session id; the default session is  */
 /*   the current session.                                       */
 /****************************************************************/
   options nosource nonotes;
   %let str=%str(rsubmit &remote;options nosource;)
    %nrstr(%let) %str(&macvar = &macval;options source;endrsubmit;);
   &str; options notes source;
 /*----------------------------------------------------------------*
    EXAMPLES:

 (1) Macro variable to current (default) remote session:

     %syslput(rc,&sysinfo)

 (2) Macro variable to specified remote session:

     %syslput(flag,1,remote=mvs)

  *----------------------------------------------------------------*/
  %mend syslput612;
