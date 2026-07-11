/* Caller for %dquote() and %squote() from sasutils/macros
   (dquote.sas, squote.sas). Both are tiny function-style macros that
   quote a value with double or single quote characters respectively,
   handling embedded quote characters and SAS version differences
   (squote.sas branches on &sysver for pre-9.3 compatibility). This
   bundle drives both directly with plain values and values containing
   an embedded quote of their own kind, matching the doubling behavior
   SAS's QUOTE() function documents, then confirms the quoted text
   round-trips through DEQUOTE() back to the original raw value. */

%macro dquote(value);
%sysfunc(quote(%superq(value)))
%mend dquote;

%macro squote(value);
%if %sysevalf(&sysver < 9.3) %then
%unquote(%str(%')%qsysfunc(tranwrd(%superq(value),%str(%'),''))%str(%'))
;
%else %sysfunc(quote(%superq(value),%str(%'))) ;
%mend squote;

%put dquote-plain=%dquote(hello);
%put dquote-with-embedded-dquote=%dquote(say %str(%")hi%str(%"));
%put squote-plain=%squote(hello);
%put squote-with-embedded-squote=%squote(O%str(%')Brien);

data check;
  length raw $20 quoted $30 dequoted $20 matches 8;

  raw = 'hello';
  quoted = %dquote(hello);
  dequoted = dequote(quoted);
  matches = (dequoted = raw);
  output;

  raw = "O'Brien";
  quoted = %squote(O%str(%')Brien);
  dequoted = dequote(quoted);
  matches = (dequoted = raw);
  output;
run;

proc print data=check noobs;
  var raw quoted dequoted matches;
run;
