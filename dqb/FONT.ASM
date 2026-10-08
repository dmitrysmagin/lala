; ---------------------------------------------------------------------------
;
; DirectQB FONT HANDLING module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN ClipX1:WORD
EXTRN ClipX2:WORD
EXTRN ClipY1:WORD
EXTRN ClipY2:WORD
EXTRN FontBuffer:BYTE
EXTRN CharLen:BYTE
EXTRN BMapActive:BYTE
EXTRN BMapSeg:WORD
EXTRN BMapFirst:BYTE

EXTRN GetLayerSeg:FAR
EXTRN HookInt24:FAR
EXTRN UnhookInt24:FAR

.DATA
TextMode      DB  0               ; Text print mode
TextBackCol   DB  0               ; Background text color for solid text mode
CharSpacing   DW  0               ; Characters spacing
FontTexture   DB  64 dup(15)      ; Font texture pixels data
TextureX      DB  0               ; Current texture x coordinate
TextureY      DB  0               ; Current texture y coordinate
TextBMap      DW  1               ; Current text blender map
BMapOff       DB  ?               ; Offset in memory for internal bmap usage

.CODE

; ---------------------------------------------------------------------------
; DQBprint SUB
; purpose:
;   Prints a string onto specified layer, at the given coordinates and with
;   the given color, style and current font
; declaration:
;   DECLARE SUB xDQBprint(BYVAL Layer,BYVAL TextSeg,BYVAL TextOff,BYVAL x,
;                         BYVAL y,BYVAL Col,BYVAL Style)
;   DECLARE SUB DQBprint(Layer AS INTEGER,Text AS STRING,x AS INTEGER,y AS
;                         INTEGER,Col AS INTEGER)
;   DECLARE SUB DQBprints(Layer AS INTEGER,Text AS STRING,x AS INTEGER,y AS
;                         INTEGER,Col AS INTEGER,Style AS INTEGER)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBprint
xDQBprint PROC
  ; Stack layout:
  ;
  ; 18  Layer
  ; 16  TextSeg
  ; 14  TextOff
  ; 12  x
  ; 10  y
  ; 08  Col
  ; 06  Style
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  MOV BX,[BP+18]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+16]
  MOV FS,AX         ; FS holds the text segment
  MOV SI,TextBMap
  DEC SI
  MOV AL,BMapFirst[SI]
  MOV BMapOff,AL
  SHL SI,1
  MOV AX,BMapSeg[SI]
  MOV GS,AX         ; GS holds the blender map segment (if any)
  MOV SI,[BP+14]    ; SI holds the character offset
  MOV AX,[BP+6]
  MOV BL,TextMode
  PUSH BX
  CMP AL,0FFh
  JE OldStyle
  MOV TextMode,AL
OldStyle:
  XOR CX,CX
  XOR DH,DH
FindStringLen:
  MOV AL,FS:[SI]
  INC SI
  CMP AL,0
  JE EndFindStringLen
  MOV DI,AX
  MOV DL,CharLen[DI]
  TEST TextMode,2
  JZ @F
  INC CX
@@:
  ADD CX,DX
  CMP BYTE PTR FS:[SI],0
  JE @F
  ADD CX,CharSpacing
@@:
  JMP FindStringLen
EndFindStringLen:
  MOV BX,[BP+12]    ; BX holds the character x position
  CMP BX,08000h
  JNE NotCentered
  MOV BX,ClipX2
  SUB BX,ClipX1
  INC BX
  SUB BX,CX
  SHR BX,1
  ADD BX,ClipX1
NotCentered:
  TEST TextMode,4
  JZ @F
  MOV AL,CharLen[256]
  SHR AL,2
  ADD CX,AX
@@:
  MOV DI,[BP+10]
  MOV AX,DI
  MOV DX,AX
  SHL AX,6
  SHL DI,8
  ADD DI,AX
  ADD DI,BX
  MOV AH,CharLen[256]
yBackLoop:
  TEST TextMode,1
  JZ SkipBackLine
  CMP DX,ClipY1
  JL SkipBackLine
  CMP DX,ClipY2
  JG SkipBackLine
  PUSH CX
xBackLoop:
  CMP BX,ClipX1
  JL SkipBackPixel
  CMP BX,ClipX2
  JG SkipBackPixel
  TEST TextMode,16
  JNZ @F
  MOV AL,TextBackCol
  MOV ES:[DI],AL
  JMP SkipBackPixel
@@:
  PUSH BX
  MOV BH,TextBackCol
  SUB BH,BMapOff
  MOV BL,ES:[DI]
  MOV AL,GS:[BX]
  MOV ES:[DI],AL
  POP BX
SkipBackPixel:
  INC DI
  INC BX
  DEC CX
  JNZ xBackLoop
  POP CX
  SUB BX,CX
  SUB DI,CX
SkipBackLine:
  ADD DI,320
  INC DX
  DEC AH
  JNZ yBackLoop
NotSolid:
  TEST TextMode,8
  JZ NotUnderLined
  CMP DX,ClipY1
  JL NotUnderLined
  CMP DX,ClipY2
  JG NotUnderLined
  PUSH CX
xBackLoopUL:
  CMP BX,ClipX1
  JL SkipBackPixelUL
  CMP BX,ClipX2
  JG SkipBackPixelUL
  TEST TextMode,16
  JNZ @F
  MOV AL,BYTE PTR [BP+8]
  MOV ES:[DI],AL
  JMP SkipBackPixelUL
@@:
  PUSH BX
  MOV BH,BYTE PTR [BP+8]
  SUB BH,BMapOff
  MOV BL,ES:[DI]
  MOV AL,GS:[BX]
  MOV ES:[DI],AL
  POP BX
SkipBackPixelUL:
  INC DI
  INC BX
  DEC CX
  JNZ xBackLoopUL
  POP CX
  SUB BX,CX
NotUnderLined:
  MOV SI,[BP+14]
  TEST TextMode,4
  JZ GetChar
  MOV AL,CharLen[256]
  SHR AL,2
  ADD BX,AX
GetChar:
  MOV TextureX,0
  MOV TextureY,0
  XOR AH,AH
  MOV AL,FS:[SI]    ; Gets character
  CMP AL,0
  JE ExitPrint      ; If null character then exit
  PUSH SI
  SHL AX,3
  ADD AX,OFFSET FontBuffer
  MOV SI,AX         ; Now SI holds the character data offset
  MOV DX,[BP+10]    ; DX holds the y position
  XOR CH,CH
  MOV CL,CharLen[256]    ; Char line counter
DrawCharLine:
  CMP DX,ClipY2
  JG DrawNextChar
  PUSH CX
  CMP DX,ClipY1
  JL NextCharLine
  MOV AL,[SI]       ; AL holds the character line data
  MOV DI,DX
  MOV CX,DI
  SHL DI,8
  SHL CX,6
  ADD DI,CX
  ADD DI,BX
  PUSH BX
  PUSH DX
  XOR DX,DX
CharLineLoop:
  MOV CX,7
  SUB CX,DX
  MOV AH,1
  SHL AH,CL
  TEST AL,AH
  JZ SkipCharPixel
  CMP BX,ClipX1
  JL SkipCharPixel
  CMP BX,ClipX2
  JG SkipCharPixel
  TEST TextMode,32
  JNZ TexturedChar
  TEST TextMode,16
  JNZ BlendedChar
  PUSH AX
  MOV AX,[BP+8]
  MOV ES:[DI],AL
  POP AX
  TEST TextMode,2
  JNZ BoldEffect
  JMP SkipCharPixel
BlendedChar:
  PUSH AX
  PUSH BX
  MOV BX,[BP+8]
  MOV BH,BL
  SUB BH,BMapOff
  MOV BL,ES:[DI]
  MOV AL,GS:[BX]
  MOV ES:[DI],AL
  POP BX
  POP AX
  TEST TextMode,2
  JNZ BoldEffect
SkipCharPixel:
  INC TextureX
  INC DI
  INC BX
  INC DX
  CMP DX,8
  JL CharLineLoop
  POP DX
  POP BX
NextCharLine:
  INC TextureY
  MOV TextureX,0
  INC DX
  INC SI
  POP CX
  TEST TextMode,4
  JZ NoItalicFix
  PUSH AX
  MOV AX,CX
  DEC AX
  AND AX,3
  CMP AX,3
  JNE NoItalicFix1
  DEC BX
NoItalicFix1:
  POP AX
NoItalicFix:
  DEC CL
  JNZ DrawCharLine
DrawNextChar:
  POP SI
  XOR AH,AH
  MOV AL,FS:[SI]
  MOV DI,AX
  MOV AL,CharLen[DI]
  XOR AH,AH
  ADD AX,CharSpacing
  ADD BX,AX         ; Increases x position
  TEST TextMode,2
  JZ NoBoldFix
  INC BX
NoBoldFix:
  TEST TextMode,4
  JZ NoItalicFix2
  ADD BX,2
NoItalicFix2:
  INC SI
  JMP GetChar
ExitPrint:
  POP BX
  MOV TextMode,BL
  POP BP
  RET 14
BoldEffect:
  INC BX
  CMP BX,ClipX1
  JL SkipCharPixel
  CMP BX,ClipX2
  JG SkipCharPixel
  PUSH AX
  MOV AX,[BP+8]
  MOV ES:[DI+1],AL
  POP AX
  DEC BX
  JMP SkipCharPixel
TexturedChar:
  PUSH SI
  PUSH AX
  XOR CH,CH
  MOV CL,TextureY
  SHL CL,3
  ADD CL,TextureX
  MOV SI,CX
  MOV AL,FontTexture[SI]
  TEST TextMode,16
  JZ @F
  PUSH BX
  MOV BH,AL
  SUB BH,BMapOff
  MOV BL,ES:[DI]
  MOV AL,GS:[BX]
  MOV ES:[DI],AL
  POP BX
  TEST TextMode,2
  JZ EndTextured
  CMP BX,ClipX2
  JNL EndTextured
  PUSH BX
  MOV BH,AL
  SUB BH,BMapOff
  MOV BL,ES:[DI+1]
  MOV AL,GS:[BX]
  MOV ES:[DI+1],AL
  POP BX
  JMP EndTextured
@@:
  MOV ES:[DI],AL
  TEST TextMode,2
  JZ EndTextured
  CMP BX,ClipX2
  JNL EndTextured
  MOV ES:[DI+1],AL
EndTextured:
  POP AX
  POP SI
  JMP SkipCharPixel
xDQBprint ENDP


; ---------------------------------------------------------------------------
; DQBsetFontTexture SUB
; purpose:
;   Sets the 8x8 texture to be used when the textured print mode is selected
; declaration:
;   DECLARE SUB DQBsetFontTexture(BYVAL TextSeg,BYVAL TextOff)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetFontTexture
DQBsetFontTexture PROC
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV AX,@DATA
  MOV ES,AX
  MOV DI,OFFSET FontTexture
  MOV AX,[BP+10]
  MOV DS,AX
  MOV SI,[BP+8]
  ADD SI,4
  MOV CX,16
  REP MOVSD
  POP BP
  POP DS
  RET 4
DQBsetFontTexture ENDP


; ---------------------------------------------------------------------------
; DQBsetTextSpacing SUB
; purpose:
;   Sets characters extra spacing in pixels
; declaration:
;   DECLARE SUB DQBsetTextSpacing(BYVAL Spacing)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetTextSpacing
DQBsetTextSpacing PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+6]
  MOV CharSpacing,AX
  POP BP
  RET 2
DQBsetTextSpacing ENDP

; ---------------------------------------------------------------------------
; DQBlen FUNCTION
; purpose:
;   Restores the length of a string in pixels, by checking the current font
;   characters length table.
; declaration:
;   DECLARE FUNCTION xDQBlen(BYVAL TextSeg,BYVAL TextOff)
;   DECLARE FUNCTION DQBlen(Text AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBlen
xDQBlen PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+8]
  MOV ES,AX
  MOV SI,[BP+6]
  XOR CX,CX
  XOR AH,AH
  XOR DH,DH
  CMP ES:[SI],AH
  JE EndLen
  TEST TextMode,4
  JZ FindLen
  MOV AL,CharLen[256]
  SHR AL,2
  ADD CX,AX
FindLen:
  MOV AL,ES:[SI]
  INC SI
  CMP AL,0
  JE EndLen
  MOV DI,AX
  MOV DL,CharLen[DI]
  TEST TextMode,2
  JZ NoLenFix
  INC CX
NoLenFix:
  ADD CX,DX
  ADD CX,CharSpacing
  JMP FindLen
EndLen:
  MOV AX,CX
  POP BP
  RET 4
xDQBlen ENDP

; ---------------------------------------------------------------------------
; DQBsetBIOSfont SUB
; purpose:
;   Restores the old VGA BIOS font as the actual font
; declaration:
;   DECLARE SUB DQBsetBIOSfont()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetBIOSfont
DQBsetBIOSfont PROC
  PUSH DS
  MOV AX,SEG FontBuffer
  MOV ES,AX
  MOV DI,OFFSET FontBuffer
  XOR AX,AX
  MOV DS,AX
  MOV SI,DS:[07Ch]
  MOV AX,DS:[07Eh]
  SUB SI,1024
  MOV DS,AX
  MOV CX,512
  REP MOVSD
  MOV EAX,08080808h
  MOV DI,OFFSET CharLen
  STOSB
  MOV CX,64
  REP STOSD
  POP DS
  MOV TextMode,0
  RET
DQBsetBIOSfont ENDP

; ---------------------------------------------------------------------------
; DQBsetFont SUB
; purpose:
;   Sets the actual font to a new one stored in memory
; declaration:
;   DECLARE SUB xDQBsetFont(BYVAL FontSeg,BYVAL FontOff)
;   DECLARE SUB DQBsetFont(Font AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBsetFont
xDQBsetFont PROC
  ; Stack layout:
  ;
  ; 10  FontSeg
  ; 08  FontOff
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  MOV AX,SEG FontBuffer
  MOV ES,AX
  MOV DI,OFFSET FontBuffer
  MOV AX,[BP+10]
  MOV DS,AX
  MOV SI,[BP+8]
  MOV CX,512
  REP MOVSD
  MOV DI,OFFSET CharLen
  MOVSB
  MOV CX,64
  REP MOVSD
  POP BP
  POP DS
  RET 4
xDQBsetFont ENDP

; ---------------------------------------------------------------------------
; DQBloadFont SUB
; purpose:
;   Loads and sets font from specified file
; declaration:
;   DECLARE SUB xDQBloadFont(BYVAL FileSeg,BYVAL FileOff)
;   DECLARE SUB DQBloadFont(FontFile AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBloadFont
xDQBloadFont PROC
  ; Stack layout:
  ;
  ; 10  FileSeg
  ; 08  FileOff
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  CALL HookInt24
  MOV AX,[BP+10]
  MOV DS,AX
  MOV DX,[BP+8]
  MOV AX,03D00h
  INT 021h
  JC Error_OpenFont
  MOV BX,AX
  MOV AX,SEG FontBuffer
  MOV DS,AX
  MOV DX,OFFSET FontBuffer
  MOV AH,03Fh
  MOV CX,2048
  INT 021h
  JC Error_ReadFont
  MOV AH,03Fh
  MOV CX,257
  MOV DX,OFFSET CharLen
  INT 021h
  JC Error_ReadFont
  MOV AX,03E00h
  INT 021h
  XOR AX,AX
  JMP EndLoadFont
Error_OpenFont:
  MOV AX,1
  MOV LastError,4
  JMP EndLoadFont
Error_ReadFont:
  MOV AX,03E00h
  INT 021h
  MOV LastError,5
  MOV AX,2
EndLoadFont:
  CALL UnhookInt24
  POP BP
  POP DS
  RET 4
xDQBloadFont ENDP

; ---------------------------------------------------------------------------
; DQBsetTextBackCol SUB
; purpose:
;   Sets the color used to fill the background of text print in solid mode
; declaration:
;   DECLARE SUB DQBsetTextBackCol(BYVAL Col)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetTextBackCol
DQBsetTextBackCol PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+6]
  MOV TextBackCol,AL
  POP BP
  RET 2
DQBsetTextBackCol ENDP

; ---------------------------------------------------------------------------
; DQBsetTextBMap SUB
; purpose:
;   Sets the blender map to be used for blended text style
; declaration:
;   DECLARE SUB DQBsetTextBMap(BYVAL BMap)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetTextBMap
DQBsetTextBMap PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+6]
  MOV TextBMap,AX
  POP BP
  RET 2
DQBsetTextBMap ENDP

; ---------------------------------------------------------------------------
; DQBsetTextStyle SUB
; purpose:
;   Sets the current text style for the DQBprint function
; declaration:
;   DECLARE SUB DQBsetTextStyle(BYVAL Style)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBsetTextStyle
DQBsetTextStyle PROC
  PUSH BP
  MOV BP,SP
  MOV AX,[BP+6]
  MOV TextMode,AL
  POP BP
  RET 2
DQBsetTextStyle ENDP


END
