#if 0
DECLARE SUB FMplayeffect (ind%)
DECLARE SUB FMload (fs$)
DECLARE SUB BeSilent ()
DECLARE SUB FMwrite (i%, d%)
DECLARE SUB FMnoteoff (chan%, ope%)
DECLARE SUB MPUwrite (b%)
DECLARE SUB FMplayrowfrom (pat$, ofs%, effnum%)
DECLARE SUB FMtouch (chan%, ope%, vol%, ins%)
DECLARE SUB FMupdate (chan%, ope%, Period%, ins%, vol%)
DECLARE SUB FMend ()
DECLARE SUB FMtimer ()
DECLARE FUNCTION FMinit% ()
DECLARE FUNCTION MPUDetect& ()
DECLARE FUNCTION MPUvol% (vol%, ins%)
DECLARE FUNCTION note2period% (note%, Oct%, ins%)
DECLARE FUNCTION VibVal% (ind%, mode%)

#endif