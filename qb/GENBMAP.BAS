'$INCLUDE: 'DIRECTQB.BI'

i% = DQBinit(2, 2, 0)
IF i% THEN PRINT "1ERROR->"; DQBerror$: DQBclose: SYSTEM
DQBinitVGA

pal$ = SPACE$(768)
i% = DQBloadImage(1, 0, 0, "GFX\TITLE.PCX", pal$, w%, h%)
IF i% THEN DQBinitText: PRINT "2ERROR->"; DQBerror$: DQBclose: SYSTEM

DQBsetPal pal$

dummy& = SETMEM(-513)
i% = DQBcreateBMap(1, 254, 255)
IF i% THEN DQBinitText: PRINT "3ERROR->"; DQBerror$: DQBclose: SYSTEM

FOR fore% = 254 TO 255
	FOR back% = 0 TO 255
		cr1% = ASC(MID$(pal$, 1 + back% * 3, 1))
		cg1% = ASC(MID$(pal$, 2 + back% * 3, 1))
		cb1% = ASC(MID$(pal$, 3 + back% * 3, 1))
	   
		cr2% = ASC(MID$(pal$, 1 + fore% * 3, 1))
		cg2% = ASC(MID$(pal$, 2 + fore% * 3, 1))
		cb2% = ASC(MID$(pal$, 3 + fore% * 3, 1))
		
		cr% = (cr1% + cr2%) \ 2
		cg% = (cg1% + cg2%) \ 2
		cb% = (cb1% + cb2%) \ 2

		mix% = DQBfindCol(cr%, cg%, cb%)
		DQBsetBMap 1, fore%, back%, mix%
	NEXT back%
NEXT fore%

i% = DQBsaveBMap(1, "LALA.BMA")
IF i% THEN PRINT "4ERROR->"; DQBerror$: DQBclose: SYSTEM

DQBinitText
DQBclose

PRINT "DONE"

