%macro compbl / parmbuff;
/*----------------------------------------------------------------------------
Compress multiple spaces into one, return value without macro quoting.

To avoid macro quoting issues use %QCOMPBL() to generate result with
macro quoting and pass it throug %UNQUOTE() to remove the macro quoting.
----------------------------------------------------------------------------*/
%unquote(%qcompbl&syspbuff)
%mend;
