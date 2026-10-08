; ---------------------------------------------------------------------------
;
; DirectQB DATAFILE DECODING module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN LastError:BYTE
EXTRN PackActive:BYTE
EXTRN PackFile:WORD
EXTRN BMapActive:BYTE
EXTRN BMapSeg:WORD
EXTRN BMapFirst:BYTE
EXTRN BMapLast:BYTE
EXTRN SoundPage:WORD
EXTRN NumSounds:BYTE
EXTRN SoundLen:WORD
EXTRN EMSseg:WORD

EXTRN MapEMS:FAR
EXTRN GetLayerSeg:FAR


.DATA
BytePtr       DW  0               ; Byte stream pointer
ByteStream    DB  256 dup(?)      ; Byte stream buffer
ByteRep       DB  0               ; Byte repetitions
LastByte      DB  ?               ; Byte to repeat
Password      DB  9 dup(0)        ; Current datafile password
PasswordPtr   DW  -1              ; Password character pointer
PackOff       DD  ?               ; Packet info buffer
NumPackets    DB  ?               ; Number of packets into a datafile
DatafileID    DB  'DQBPaCk'       ; Datafile ID string
TempBuf       DB  8 dup(?)        ; Temporary buffer

.CODE

; ---------------------------------------------------------------------------
; GetStreamByte internal function
; purpose:
;   Reads a byte from the opened datafile bytes buffer
; ---------------------------------------------------------------------------
GetStreamByte PROC
  INC BytePtr
  CMP BytePtr,256
  JB @F
  PUSHA
  MOV BX,PackFile
  MOV AH,03Fh
  MOV CX,256
  MOV DX,OFFSET ByteStream
  INT 21h
  MOV BytePtr,0
  POPA
@@:
  MOV SI,BytePtr
  MOV AL,ByteStream[SI]
  RET
GetStreamByte ENDP

; ---------------------------------------------------------------------------
; ReadStreamBuffer internal function
; purpose:
;   Gets a byte from the opened datafile, decodes it and returns it into AL
; ---------------------------------------------------------------------------
ReadStreamByte PROC
  CMP ByteRep,0
  JE @F
  DEC ByteRep
  MOV AL,LastByte
  RET
@@:
  PUSH SI
  PUSH BX
  MOV BX,PackFile
  CALL GetStreamByte
  INC PasswordPtr
  MOV SI,PasswordPtr
  CMP Password[SI],0
  JNE @F
  MOV PasswordPtr,0
  XOR SI,SI
@@:
  SUB AL,Password[SI]
  CMP AL,0FFh
  JE @F
  POP BX
  POP SI
  RET
@@:
  CALL GetStreamByte
  INC PasswordPtr
  MOV SI,PasswordPtr
  CMP Password[SI],0
  JNE @F
  MOV PasswordPtr,0
  XOR SI,SI
@@:
  SUB AL,Password[SI]
  DEC AL
  MOV ByteRep,AL
  CALL GetStreamByte
  INC PasswordPtr
  MOV SI,PasswordPtr
  CMP Password[SI],0
  JNE @F
  MOV PasswordPtr,0
  XOR SI,SI
@@:
  SUB AL,Password[SI]
  MOV LastByte,AL
  POP BX
  POP SI
  RET
ReadStreamByte ENDP

; ---------------------------------------------------------------------------
; SeekPacket internal function
; purpose:
;   Seeks to the packet ID specified into AL; if packet is not found, carry
;   flag is set.
; ---------------------------------------------------------------------------
SeekPacket PROC
  MOV CL,NumPackets
  CMP AL,CL
  JLE @F
  STC
  RET
@@:
  CWDE
  MOV ECX,EAX
  SHL ECX,2
  ADD ECX,8
  MOV DX,CX
  SHR ECX,16
  MOV AX,04200h
  MOV BX,PackFile
  INT 21h
  MOV AH,03Fh
  MOV CX,4
  MOV DX,OFFSET PackOff
  INT 21h
  MOV ECX,PackOff
  MOV DX,CX
  SHR ECX,16
  MOV AX,04200h
  INT 21h
  MOV PasswordPtr,-1
  MOV ByteRep,0
  MOV BytePtr,255
  CLC
  RET
SeekPacket ENDP

; ---------------------------------------------------------------------------
; DQBopenDataFile FUNCTION
; purpose:
;   Opens a specified datafile
; declaration:
;   DECLARE FUNCTION xDQBopenDataFile(BYVAL FileSeg,BYVAL FileOff,BYVAL
;                                     PasswordSeg,BYVAL PasswordOff)
;   DECLARE FUNCTION DQBopenDataFile(FileName AS STRING,Password AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBopenDataFile
xDQBopenDataFile PROC
  ; Stack layout
  ;
  ; 14  FileSeg
  ; 12  FileOff
  ; 10  PasswordSeg
  ; 08  PasswordOff
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  CMP PackActive,1
  JE Error_PackActive
  PUSH DS
  MOV AX,[BP+14]
  MOV DS,AX
  MOV DX,[BP+12]
  MOV AX,03D00h
  INT 21h
  POP DS
  JC Error_OpenData
  MOV BX,AX
  MOV PackFile,BX
  MOV AH,03Fh
  MOV CX,8
  MOV DX,OFFSET TempBuf
  INT 21h
  JC Error_ReadData
  MOV SI,OFFSET TempBuf
  MOV AX,@DATA
  MOV ES,AX
  MOV DI,OFFSET DatafileID
  MOV CX,7
  REPE CMPSB
  JNE Error_BadData
  MOV AL,TempBuf[7]
  INC AL
  MOV NumPackets,AL
  MOV AX,[BP+10]
  MOV ES,AX
  MOV DI,[BP+8]
  XOR SI,SI
StorePassword:
  MOV AL,ES:[DI]
  MOV Password[SI],AL
  INC DI
  INC SI
  CMP SI,8
  JNE @F
  XOR AL,AL
  MOV Password[SI],AL
@@:
  CMP AL,0
  JNE StorePassword
  MOV PackActive,1
  XOR AX,AX
  JMP EndOpenDataFile
Error_OpenData:
  MOV AX,1
  MOV LastError,4
  JMP EndOpenDataFile
Error_ReadData:
  MOV AH,03Eh
  MOV BX,PackFile
  INT 21h
  MOV AX,2
  MOV LastError,5
  JMP EndOpenDataFile
Error_BadData:
  MOV AH,03Eh
  MOV BX,PackFile
  INT 21h
  MOV AX,3
  MOV LastError,11
  JMP EndOpenDataFile
Error_PackActive:
  MOV AX,4
  MOV LastError,28
EndOpenDataFile:
  POP BP
  POP DS
  RET 8
xDQBopenDataFile ENDP

; ---------------------------------------------------------------------------
; DQBunpackFont FUNCTION
; purpose:
;   Decodes a specified font packet from the opened datafile
; declaration:
;   DECLARE FUNCTION xDQBunpackFont(BYVAL PackID,BYVAL FontSeg,BYVAL FontOff)
;   DECLARE FUNCTION DQBunpackFont(PackID AS INTEGER,Font AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBunpackFont
xDQBunpackFont PROC
  ; Stack layout
  ;
  ; 10  PackID
  ; 08  FontSeg
  ; 06  FontOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP PackActive,0
  JE Error_pFontPack
  MOV AX,[BP+10]
  CALL SeekPacket
  JC Error_pFontID
  MOV CX,4
@@:
  SHL EAX,8
  CALL ReadStreamByte
  LOOP @B
  CMP EAX,'FNTþ'
  JNE Error_pFontBad
  MOV AX,[BP+8]
  MOV ES,AX
  MOV DI,[BP+6]
  MOV CX,2305
@@:
  CALL ReadStreamByte
  STOSB
  DEC CX
  JNZ @B
  XOR AX,AX
  JMP EndUnpackFont
Error_pFontPack:
  MOV AX,1
  MOV LastError,25
  JMP EndUnpackFont
Error_pFontID:
  MOV AX,2
  MOV LastError,26
  JMP EndUnpackFont
Error_pFontBad:
  MOV AX,3
  MOV LastError,27  
EndUnpackFont:
  POP BP
  RET 6
xDQBunpackFont ENDP

; ---------------------------------------------------------------------------
; DQBunpackImage FUNCTION
; purpose:
;   Decodes a specified image packet from the opened datafile
; declaration:
;   DECLARE FUNCTION DQBunpackImage(BYVAL PackID,BYVAL Layer,BYVAL x,BYVAL y)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBunpackImage
DQBunpackImage PROC
  ; Stack layout
  ;
  ; 12  PackID
  ; 10  Layer
  ; 08  x
  ; 06  y
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP PackActive,0
  JE Error_pImagePack
  MOV AX,[BP+12]
  CALL SeekPacket
  JC Error_pImageID
  MOV CX,4
@@:
  SHL EAX,8
  CALL ReadStreamByte
  LOOP @B
  CMP EAX,'IMGþ'
  JNE Error_pImageBad
  MOV BX,[BP+10]
  CALL GetLayerSeg
  MOV ES,CX
  CALL ReadStreamByte
  MOV DL,AL
  CALL ReadStreamByte
  MOV DH,AL
  CALL ReadStreamByte
  MOV CL,AL
  CALL ReadStreamByte
  MOV CH,AL
  MOV DI,[BP+6]
  MOV AX,DI
  SHL AX,6
  SHL DI,8
  ADD DI,AX
  ADD DI,[BP+8]
yLoop:
  PUSH CX
  MOV CX,DX
xLoop:
  CALL ReadStreamByte
  STOSB
  LOOP xLoop
  ADD DI,320
  SUB DI,DX
  POP CX
  LOOP yLoop
  XOR AX,AX
  JMP EndUnpackImage
Error_pImagePack:
  MOV AX,1
  MOV LastError,25
  JMP EndUnpackImage
Error_pImageID:
  MOV AX,2
  MOV LastError,26
  JMP EndUnpackImage
Error_pImageBad:
  MOV AX,3
  MOV LastError,27  
EndUnpackImage:
  POP BP
  RET 8
DQBunpackImage ENDP

; ---------------------------------------------------------------------------
; DQBunpackSprite FUNCTION
; purpose:
;   Decodes a specified sprite packet from the opened datafile
; declaration:
;   DECLARE FUNCTION DQBunpackSprite(BYVAL PackID,BYVAL SpriteSeg,BYVAL
;                                    SpriteOff)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBunpackSprite
DQBunpackSprite PROC
  ; Stack layout
  ;
  ; 10  PackID
  ; 08  SpriteSeg
  ; 06  SpriteOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP PackActive,0
  JE Error_pSpritePack
  MOV AX,[BP+10]
  CALL SeekPacket
  JC Error_pSpriteID
  MOV CX,4
@@:
  SHL EAX,8
  CALL ReadStreamByte
  LOOP @B
  CMP EAX,'IMGþ'
  JNE Error_pSpriteBad
  MOV AX,[BP+8]
  MOV ES,AX
  MOV DI,[BP+6]
  CALL ReadStreamByte
  MOV DL,AL
  CALL ReadStreamByte
  MOV DH,AL
  SHL DX,3
  MOV ES:[DI],DX
  CALL ReadStreamByte
  MOV CL,AL
  CALL ReadStreamByte
  MOV CH,AL
  MOV ES:[DI+2],CX
  SHR DX,3
  MOV AX,CX
  MUL DX
  MOV CX,AX
  ADD DI,4
@@:
  CALL ReadStreamByte
  STOSB
  LOOP @B
  XOR AX,AX
  JMP EndUnpackSprite
Error_pSpritePack:
  MOV AX,1
  MOV LastError,25
  JMP EndUnpackSprite
Error_pSpriteID:
  MOV AX,2
  MOV LastError,26
  JMP EndUnpackSprite
Error_pSpriteBad:
  MOV AX,3
  MOV LastError,27  
EndUnpackSprite:
  POP BP
  RET 6
DQBunpackSprite ENDP

; ---------------------------------------------------------------------------
; DQBunpackSound FUNCTION
; purpose:
;   Decodes a specified sound packet from the opened datafile
; declaration:
;   DECLARE FUNCTION DQBunpackSound(BYVAL PackID,BYVAL SoundSlot)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBunpackSound
DQBunpackSound PROC
  ; Stack layout
  ;
  ; 08  PackID
  ; 06  SoundSlot
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP PackActive,0
  JE Error_pSoundPack
  MOV AX,[BP+8]
  CALL SeekPacket
  JC Error_pSoundID
  MOV CX,4
@@:
  SHL EAX,8
  CALL ReadStreamByte
  LOOP @B
  CMP EAX,'SNDþ'
  JNE Error_pSoundBad
  MOV AX,[BP+6]
  XOR BH,BH
  MOV BL,NumSounds
  CMP AX,BX
  JA Error_pBadSlot
  MOV CX,4
@@:
  SHL EAX,8
  CALL ReadStreamByte
  LOOP @B
  MOV SI,[BP+6]
  DEC SI
  SHL SI,1
  MOV SoundLen[SI],AX
  SHL SI,1
  ADD SI,SoundPage
  MOV DX,SI
  PUSH AX
  PUSH BX
  CALL MapEMS
  POP BX
  MOV AX,EMSseg
  MOV ES,AX
  XOR DI,DI
  MOV EAX,080808080h
  MOV CX,16384
  REP STOSD
  POP CX
  XOR DI,DI
@@:
  CALL ReadStreamByte
  STOSB
  LOOP @B
  XOR AX,AX
  JMP EndUnpackSound
Error_pSoundPack:
  MOV AX,1
  MOV LastError,25
  JMP EndUnpackSound
Error_pSoundID:
  MOV AX,2
  MOV LastError,26
  JMP EndUnpackSound
Error_pSoundBad:
  MOV AX,3
  MOV LastError,27
  JMP EndUnpackSound
Error_pBadSlot:
  MOV AX,4
  MOV LastError,19
EndUnpackSound:
  POP BP
  RET 4
DQBunpackSound ENDP

; ---------------------------------------------------------------------------
; DQBunpackPal FUNCTION
; purpose:
;   Decodes a specified palette packet from the opened datafile
; declaration:
;   DECLARE FUNCTION xDQBunpackPal(BYVAL PackID,BYVAL PalSeg,BYVAL PalOff)
;   DECLARE FUNCTION DQBunpackPal(PackID AS INTEGER,Pal AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBunpackPal
xDQBunpackPal PROC
  ; Stack layout
  ;
  ; 10  PackID
  ; 08  PalSeg
  ; 06  PalOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP PackActive,0
  JE Error_pPalPack
  MOV AX,[BP+10]
  CALL SeekPacket
  JC Error_pPalID
  MOV CX,4
@@:
  SHL EAX,8
  CALL ReadStreamByte
  LOOP @B
  CMP EAX,'PALþ'
  JNE Error_pPalBad
  MOV AX,[BP+8]
  MOV ES,AX
  MOV DI,[BP+6]
  MOV CX,768
@@:
  CALL ReadStreamByte
  STOSB
  LOOP @B
  XOR AX,AX
  JMP EndUnpackPal
Error_pPalPack:
  MOV AX,1
  MOV LastError,25
  JMP EndUnpackPal
Error_pPalID:
  MOV AX,2
  MOV LastError,26
  JMP EndUnpackPal
Error_pPalBad:
  MOV AX,3
  MOV LastError,27  
EndUnpackPal:
  POP BP
  RET 6
xDQBunpackPal ENDP

; ---------------------------------------------------------------------------
; DQBunpackBMap FUNCTION
; purpose:
;   Decodes a specified blender map packet from the opened datafile
; declaration:
;   DECLARE FUNCTION DQBunpackBMap(BYVAL PackID,BYVAL BMap)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBunpackBMap
DQBunpackBMap PROC
  ; Stack layout
  ;
  ; 08  PackID
  ; 06  BMap
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP PackActive,0
  JE Error_pBMapPack
  MOV AX,[BP+8]
  CALL SeekPacket
  JC Error_pBMapID
  MOV CX,4
@@:
  SHL EAX,8
  CALL ReadStreamByte
  LOOP @B
  CMP EAX,'BMAþ'
  JNE Error_pBMapBad
  MOV SI,[BP+6]
  DEC SI
  CMP BMapActive[SI],0
  JE Error_pBMapActive
  SHL SI,1
  MOV AX,BMapSeg[SI]
  MOV ES,AX
  SHR SI,1
  MOV DL,BMapLast[SI]
  SUB DL,BMapFirst[SI]
  INC DL
  CALL ReadStreamByte
  CMP AL,DL
  JNE Error_pBMapIncompatible
  MOV CH,AL
  XOR CL,CL
  XOR DI,DI
@@:
  CALL ReadStreamByte
  STOSB
  LOOP @B
  XOR AX,AX
  JMP EndUnpackBMap
Error_pBMapPack:
  MOV AX,1
  MOV LastError,25
  JMP EndUnpackBMap
Error_pBMapID:
  MOV AX,2
  MOV LastError,26
  JMP EndUnpackBMap
Error_pBMapBad:
  MOV AX,3
  MOV LastError,27
  JMP EndUnpackBMap
Error_pBMapActive:
  MOV AX,4
  MOV LastError,8
  JMP EndUnpackBMap
Error_pBMapIncompatible:
  MOV AX,5
  MOV LastError,22
EndUnpackBMap:
  POP BP
  RET 4
DQBunpackBMap ENDP

; ---------------------------------------------------------------------------
; DQBunpackCursor FUNCTION
; purpose:
;   Decodes a specified cursor packet from the opened datafile
; declaration:
;   DECLARE FUNCTION xDQBunpackCursor(BYVAL PackID,BYVAL CursorSeg,BYVAL
;                                     CursorOff)
;   DECLARE FUNCTION DQBunpackCursor(PackID AS INTEGER,Cursor AS STRING)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBunpackCursor
xDQBunpackCursor PROC
  ; Stack layout
  ;
  ; 10  PackID
  ; 08  CursorSeg
  ; 06  CursorOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP PackActive,0
  JE Error_pCursorPack
  MOV AX,[BP+10]
  CALL SeekPacket
  JC Error_pCursorID
  MOV CX,4
@@:
  SHL EAX,8
  CALL ReadStreamByte
  LOOP @B
  CMP EAX,'CURþ'
  JNE Error_pCursorBad
  MOV AX,[BP+8]
  MOV ES,AX
  MOV DI,[BP+6]
  MOV CX,64
@@:
  CALL ReadStreamByte
  STOSB
  DEC CX
  JNZ @B
  XOR AX,AX
  JMP EndUnpackCursor
Error_pCursorPack:
  MOV AX,1
  MOV LastError,25
  JMP EndUnpackCursor
Error_pCursorID:
  MOV AX,2
  MOV LastError,26
  JMP EndUnpackCursor
Error_pCursorBad:
  MOV AX,3
  MOV LastError,27  
EndUnpackCursor:
  POP BP
  RET 6
xDQBunpackCursor ENDP

; ---------------------------------------------------------------------------
; DQBunpackUser FUNCTION
; purpose:
;   Decodes a specified user-defined packet from the opened datafile
; declaration:
;   DECLARE FUNCTION DQBunpackUser(BYVAL PackID,BYVAL DataSeg,BYVAL DataOff)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBunpackUser
DQBunpackUser PROC
  ; Stack layout
  ;
  ; 10  PackID
  ; 08  DataSeg
  ; 06  DataOff
  ; 04  Basic return segment
  ; 02  Basic return offset
  ; 00  BP
  PUSH BP
  MOV BP,SP
  CMP PackActive,0
  JE Error_pUserPack
  MOV AX,[BP+10]
  CALL SeekPacket
  JC Error_pUserID
  MOV CX,4
@@:
  SHL EAX,8
  CALL ReadStreamByte
  LOOP @B
  CMP EAX,'USRþ'
  JNE Error_pUserBad
  MOV CX,4
@@:
  SHL EAX,8
  CALL ReadStreamByte
  LOOP @B
  MOV CX,AX
  MOV AX,[BP+8]
  MOV ES,AX
  MOV DI,[BP+6]
@@:
  CALL ReadStreamByte
  STOSB
  LOOP @B
  XOR AX,AX
  JMP EndUnpackUser
Error_pUserPack:
  MOV AX,1
  MOV LastError,25
  JMP EndUnpackUser
Error_pUserID:
  MOV AX,2
  MOV LastError,26
  JMP EndUnpackUser
Error_pUserBad:
  MOV AX,3
  MOV LastError,27
EndUnpackUser:
  POP BP
  RET 6
DQBunpackUser ENDP

; ---------------------------------------------------------------------------
; DQBcloseDataFile SUB
; purpose:
;   Closes an opened datafile; does nothing if no datafile has been opened
; declaration:
;   DECLARE SUB DQBcloseDataFile()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBcloseDataFile
DQBcloseDataFile PROC
  CMP PackActive,0
  JE @F
  MOV BX,PackFile
  MOV AH,03Eh
  INT 21h
  MOV PackActive,0
@@:
  RET
DQBcloseDataFile ENDP


END
