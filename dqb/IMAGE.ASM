; ---------------------------------------------------------------------------
;
; DirectQB IMAGE SUPPORT module
;
; Part of the DirectQB Library version 1.61
; by Angelo Mottola, Enhanced Creations 1998-99
;
; ---------------------------------------------------------------------------

.MODEL medium,basic

.386

.STACK 100h

EXTRN Buffer:BYTE
EXTRN LastError:BYTE
EXTRN KeyActive:BYTE
EXTRN KeyStatus:BYTE
EXTRN FLIactive:BYTE
EXTRN FLIfile:WORD
EXTRN FLIbufSeg:WORD

EXTRN GetLayerSeg:FAR
EXTRN HookInt24:FAR
EXTRN UnhookInt24:FAR
EXTRN ReadBuffer:FAR
EXTRN WriteBuffer:FAR

FLIheaderType STRUC
  hSize       DD  ?
  hID         DW  ?
  Frames      DW  ?
  Xres        DW  ?
  Yres        DW  ?
  ColorBits   DW  ?
  Flags       DW  ?
  Speed       DW  ?
FLIheaderType ENDS

FLIframeChunkType STRUC
  fSize       DD  ?
  fID         DW  ?
  Chunks      DW  ?
  Reserved    DQ  ?
FLIframeChunkType ENDS

FLIdataChunkType STRUC
  cSize       DD  ?
  cID         DW  ?
FLIdataChunkType ENDS

BSVheaderType STRUC
  SourceSeg   DW  ?
  SourceOff   DW  ?
  BSVlen      DW  ?
  BSVxSize    DW  ?
  BSVySize    DW  ?
BSVheaderType ENDS

BMPheaderType STRUC
  BMPid       DB  ?
  BMPlen      DD  ?
  res         DD  ?
  DataOff     DD  ?
  headSize    DD  ?
  BMPxSize    DD  ?
  BMPySize    DD  ?
  BMPplanes   DW  ?
  BMPbpp      DW  ?
  comp        DD  ?
  iSize       DD  ?
  xpm         DD  ?
  ypm         DD  ?
  colus       DD  ?
  impcol      DD  ?
BMPheaderType ENDS

PCXheaderType STRUC
  ver         DB  ?
  encoding    DB  ?
  PCXbpp      DB  ?
  xmin        DW  ?
  ymin        DW  ?
  PCXxSize    DW  ?
  PCXySize    DW  ?
  hdpi        DW  ?
  vdpi        DW  ?
  colormap    DB  48 dup(?)
  unused      DB  64 dup(?)
PCXheaderType ENDS


.DATA
BSVheader     BSVheaderType <>             ; BSAVE file header
BMPheader     BMPheaderType <>             ; BMP file header
PCXheader     PCXheaderType <>             ; PCX file header

;BSVheader     DB  0FDh,000h,0A0h,000h      ; BSAVE file header (for a 320x200
;              DB  000h,000h,0FAh           ; pixels image) - 7 bytes
;BMPheader     DB  042h,04Dh,036h,0FEh,000h,000h,000h,000h   ; BMP file header
;              DB  000h,000h,036h,004h,000h,000h,028h,000h   ; (for a 320x200
;              DB  000h,000h,040h,001h,000h,000h,0C8h,000h   ; pixels image,
;              DB  000h,000h,001h,000h,008h,000h,000h,000h   ; uncompressed)
;              DB  000h,000h,000h,0FAh,000h,000h,0CEh,00Eh   ; - 54 bytes
;              DB  000h,000h,0C4h,00Eh,000h,000h,000h,000h
;              DB  000h,000h,000h,000h,000h,000h
;PCXheader     DB  00Ah,005h,001h,008h,000h,000h,000h,000h   ; PCX file header
;              DB  03Fh,001h,0C7h,000h,040h,001h,0C8h,000h   ; (for a 320x200
;              DB  000h,000h,000h,0D8h,098h,038h,078h,074h   ; pixels image,
;              DB  004h,070h,06Ch,004h,0ECh,0ACh,04Ch,0F8h   ; encoded using
;              DB  0C4h,080h,040h,024h,024h,024h,028h,014h   ; PCX version 3.0
;              DB  0F8h,0BCh,068h,0D4h,090h,09Ch,03Ch,024h   ; specifications)
;              DB  024h,074h,070h,008h,078h,074h,008h,07Ch   ; - 128 bytes
;              DB  078h,008h,034h,030h,004h,0F0h,0C4h,088h
;              DB  000h,001h,040h,001h,000h,000h,000h,000h
;              DB  000h,000h,000h,000h,000h,000h,000h,000h
;              DB  000h,000h,000h,000h,000h,000h,000h,000h
;              DB  000h,000h,000h,000h,000h,000h,000h,000h
;              DB  000h,000h,000h,000h,000h,000h,000h,000h
;              DB  000h,000h,000h,000h,000h,000h,000h,000h
;              DB  000h,000h,000h,000h,000h,000h,000h,000h
;              DB  000h,000h,000h,000h,000h,000h,000h,000h

FLIheader     FLIheaderType <>             ; FLI header
FLIframeChunk FLIframeChunkType <>         ; FLI frame chunk
FLIdataChunk  FLIdataChunkType <>          ; FLI data chunk
FLIframe      DW  ?                        ; Current FLI frame
FLIchunk      DW  ?                        ; Current FLI chunk
FramePos      DD  ?                        ; Frame file position
ChunkPos      DD  ?                        ; Chunk file position
Packets       DW  ?                        ; Number of packets in a FLI chunk
CurLine       DW  ?                        ; Line pointer (FLI player)


.CODE


; ---------------------------------------------------------------------------
; DQBloadImage FUNCTION
; purpose:
;   Loads an image onto specified layer, at given coordinates. It supports
;   BSAVE, BMP and PCX image formats, and it automatically detects which one
;   is used by specified file. Image palette is stored at specified address.
;   When loading BSAVEd images, the palette is supposed to be appended at the
;   end of file; if it's not available, it is ignored.
; declaration:
;   DECLARE FUNCTION xDQBloadImage(BYVAL Layer,BYVAL x,BYVAL y,BYVAL FileSeg,
;                                 BYVAL FileOff,BYVAL PalSeg,BYVAL PalOff)
;   DECLARE FUNCTION DQBloadImage(Layer AS INTEGER,x AS INTEGER,y AS INTEGER,
;                                 FileName AS STRING,Pal AS STRING,imgWidth
;                                 AS INTEGER,imgHeight AS INTEGER)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBloadImage
xDQBloadImage PROC
  ; Stack layout:
  ;
  ; 24  Layer
  ; 22  x
  ; 20  y
  ; 18  FileSeg
  ; 16  FileOff
  ; 14  PalSeg
  ; 12  PalOff
  ; 10  imgWidth
  ; 08  imgHeight
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  CALL HookInt24
  MOV BX,[BP+24]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,[BP+18]
  MOV DS,AX
  MOV DX,[BP+16]
  MOV AX,3D00h
  INT 21h
  JC Error_Open
  MOV BX,AX
  MOV AX,@DATA
  MOV DS,AX
  MOV DI,[BP+20]
  MOV AX,DI
  SHL DI,8
  SHL AX,6
  ADD DI,AX
  ADD DI,[BP+22]
  CALL ReadBuffer
  JC Error_Read
  CMP Buffer,0FDh
  JNE CheckBMP
  MOV CX,10
  MOV AH,03Fh
  MOV DX,OFFSET BSVheader
  INT 21h
  JC Error_Read
  CMP BSVheader.SourceSeg,0A000h
  JNE SourceNotVideo
  MOV AX,320
  MOV SI,[BP+10]
  MOV [SI],AX
  MOV AX,200
  MOV SI,[BP+8]
  MOV [SI],AX
  MOV AX,BSVheader.BSVxSize
  MOV ES:[DI],AX
  MOV AX,BSVheader.BSVySize
  MOV ES:[DI+2],AX
  ADD DI,4
  MOV CX,BSVheader.BSVlen
  PUSH DS
  MOV AX,ES
  MOV DS,AX
  MOV AH,03Fh
  MOV DX,DI
  INT 21h
  POP DS
  JC Error_Read
  JMP CheckBSVpal
SourceNotVideo:
  SHR BSVheader.BSVxSize,3
  MOV AX,BSVheader.BSVxSize
  MOV SI,[BP+10]
  MOV [SI],AX
  MOV CX,BSVheader.BSVySize
  MOV SI,[BP+8]
  MOV [SI],CX
@@:
  PUSH DS
  PUSH CX
  MOV CX,BSVheader.BSVxSize
  MOV AX,ES
  MOV DS,AX
  MOV AH,03Fh
  MOV DX,DI
  INT 21h
  POP CX
  POP DS
  JC Error_Read
  ADD DI,320
  DEC CX
  JNZ @B
CheckBSVpal:
  MOV AX,04202h
  XOR CX,CX
  XOR DX,DX
  INT 21h
  JC Error_Read
  MOV DX,BSVheader.BSVlen
  ADD DX,7
  CMP AX,DX
  JE LoadCloseFile
  XOR CX,CX
  MOV AX,04200h
  INT 21h
  JC Error_Read
  MOV AX,[BP+14]
  MOV DS,AX
  MOV CX,768
  MOV DX,[BP+12]
  MOV AH,03Fh
  INT 21h
  JC Error_Read
  JMP LoadCloseFile
CheckBMP:
  CMP Buffer,'B'
  JNE CheckPCX
  MOV CX,SIZE BMPheader
  MOV DX,OFFSET BMPheader
  MOV AH,03Fh
  INT 21h
  JC Error_Read
  CMP BMPheader.BMPid,'M'
  JNE Error_BadFile
  CMP BMPheader.BMPplanes,1
  JNE Error_BadFile
  CMP BMPheader.BMPbpp,8
  JNE Error_BadFile
  CMP BMPheader.comp,0
  JNE Error_BadFile
  MOV EAX,BMPheader.BMPxSize
  MOV SI,[BP+10]
  MOV [SI],AX
  MOV EAX,BMPheader.BMPySize
  MOV SI,[BP+8]
  MOV [SI],AX
  MOV AX,[BP+14]
  MOV FS,AX
  MOV SI,[BP+12]
  MOV CX,256
@@:
  CALL ReadBuffer
  JC Error_Read
  MOV AL,Buffer
  SHR AL,2
  MOV FS:[SI+2],AL
  CALL ReadBuffer
  JC Error_Read
  MOV AL,Buffer
  SHR AL,2
  MOV FS:[SI+1],AL
  CALL ReadBuffer
  JC Error_Read
  MOV AL,Buffer
  SHR AL,2
  MOV FS:[SI],AL
  CALL ReadBuffer
  JC Error_Read
  ADD SI,3
  DEC CX
  JNZ @B
  MOV EAX,BMPheader.BMPySize
  DEC AX
  MOV DX,AX
  SHL DX,8
  SHL AX,6
  ADD AX,DX
  ADD DI,AX
  MOV ECX,BMPheader.BMPySize
BMPyLoop:
  PUSH DS
  PUSH CX
  MOV ECX,BMPheader.BMPxSize
  TEST CX,1
  JZ @F
  INC CX
@@:
  MOV AX,ES
  MOV DS,AX
  MOV AH,03Fh
  MOV DX,DI
  INT 21h
  POP CX
  POP DS
  JC Error_Read
  SUB DI,320
  DEC CX
  JNZ BMPyLoop
  JMP LoadCloseFile
CheckPCX:
  CMP Buffer,0Ah
  JNE Error_BadFile
  MOV CX,SIZE PCXheader
  MOV DX,OFFSET PCXheader
  MOV AH,03Fh
  INT 21h
  JC Error_Read
  CMP PCXheader.ver,5
  JNE Error_BadFile
  CMP PCXheader.encoding,1
  JNE Error_BadFile
  CMP PCXheader.PCXbpp,8
  JNE Error_BadFile
  MOV AX,PCXheader.xmin
  DEC AX
  SUB PCXheader.PCXxSize,AX
  MOV AX,PCXheader.ymin
  DEC AX
  SUB PCXheader.PCXySize,AX
  MOV AX,PCXheader.PCXxSize
  MOV SI,[BP+10]
  MOV [SI],AX
  MOV AX,PCXheader.PCXySize
  MOV SI,[BP+8]
  MOV [SI],AX
  XOR AX,AX
  XOR DX,DX
  MOV SI,PCXheader.PCXySize
  TEST PCXheader.PCXxSize,1
  JZ PCXloadLoop
  INC PCXheader.PCXxSize
PCXloadLoop:
  CALL ReadBuffer
  JC Error_Read
  MOV AL,Buffer
  PUSH AX
  AND AL,0C0h
  CMP AL,0C0h
  POP AX
  JE PCXdecodeRLE
  STOSB
  INC DX
  CMP DX,PCXheader.PCXxSize
  JL PCXnextChunk
  ADD DI,320
  SUB DI,DX
  XOR DX,DX
  DEC SI
  JMP PCXnextChunk
PCXdecodeRLE:
  SUB AL,0C0h
  PUSH AX
  CALL ReadBuffer
  JC Error_Read
  MOV AL,Buffer
  POP CX
PCXloopRLE:
  STOSB
  INC DX
  CMP DX,PCXheader.PCXxSize
  JL @F
  ADD DI,320
  SUB DI,DX
  XOR DX,DX
  DEC SI
@@:
  DEC CL
  JNZ PCXloopRLE
PCXnextChunk:
  OR SI,SI
  JNZ PCXloadLoop
  CALL ReadBuffer
  JC Error_Read
  MOV AX,[BP+14]
  MOV ES,AX
  MOV DI,[BP+12]
  MOV CX,768
@@:
  CALL ReadBuffer
  JC Error_Read
  MOV AL,Buffer
  SHR AL,2
  STOSB
  DEC CX
  JNZ @B
  JMP LoadCloseFile
Error_Open:
  MOV AX,1          ; Error 1: Cannot open file (does it exist?)
  MOV LastError,4
  JMP EndLoadLayer
Error_Read:
  MOV AH,3Eh
  INT 21h
  MOV AX,2          ; Error 2: Unable to read from file
  MOV LastError,5
  JMP EndLoadLayer
Error_BadFile:
  MOV AH,3Eh
  INT 21h
  MOV AX,3          ; Error 3: Bad file format
  MOV LastError,11
  JMP EndLoadLayer
LoadCloseFile:
  MOV AH,3Eh
  INT 21h
  XOR AX,AX
EndLoadLayer:
  CALL UnhookInt24
  POP BP
  POP DS
  RET 18
xDQBloadImage ENDP

; ---------------------------------------------------------------------------
; DQBsaveImage FUNCTION
; purpose:
;   Saves image found on specified layer and coordinates into a file, using
;   a particular format among BSV, PCX and BMP. If saving in BSV mode, the
;   palette is actually appended to the end of file.
; declaration:
;   DECLARE FUNCTION xDQBsaveImage(BYVAL Layer,BYVAL x1,BYVAL y1,BYVAL x2,
;                                 BYVAL y2,BYVAL FileSeg,BYVAL FileOff,
;                                 BYVAL PalSeg,BYVAL PalOff,BYVAL Format)
;   DECLARE FUNCTION DQBsaveImage(Layer AS INTEGER,x1 AS INTEGER,y1 AS
;                                 INTEGER,x2 AS INTEGER,y2 AS INTEGER,
;                                 FileName AS STRING,Pal AS STRING,Format
;                                 AS INTEGER)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBsaveImage
xDQBsaveImage PROC
  ; Stack layout:
  ;
  ; 26  Layer
  ; 24  x1
  ; 22  y1
  ; 20  x2
  ; 18  y2
  ; 16  FileSeg
  ; 14  FileOff
  ; 12  PalSeg
  ; 10  PalOff
  ; 08  Format
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  CALL HookInt24
  MOV BX,[BP+26]
  CALL GetLayerSeg
  MOV ES,CX
  MOV DX,[BP+14]    ; DS:DX points to the asciiz filename
  MOV AX,[BP+16]
  MOV DS,AX
  MOV AH,3Ch        ; Function 3Ch: create file
  MOV CX,20h        ; archive attribute
  INT 21h
  JC Error_Create
  MOV BX,AX
  MOV AX,[BP+8]
  CMP AX,0
  JE SaveBSV
  CMP AX,1
  JE SaveBMP
  MOV Buffer,0Ah
  CALL WriteBuffer
  JC Error_Write
  MOV PCXheader.ver,5
  MOV PCXheader.encoding,1
  MOV PCXheader.PCXbpp,8
  MOV AX,[BP+24]
  MOV PCXheader.xmin,AX
  MOV AX,[BP+22]
  MOV PCXheader.ymin,AX
  MOV AX,[BP+20]
  MOV PCXheader.PCXxSize,AX
  MOV AX,[BP+18]
  MOV PCXheader.PCXySize,AX
  MOV DX,OFFSET PCXheader
  MOV AX,@DATA
  MOV DS,AX
  MOV CX,127        ; Let's write the PCX header at the beginning of the file
  MOV AH,40h        ; Function 40h: write to file
  INT 21h
  JC Error_Write
  MOV DI,[BP+22]
  MOV AX,DI
  SHL AX,6
  SHL DI,8
  ADD DI,AX
  ADD DI,[BP+24]
  MOV AX,PCXheader.xmin
  SUB PCXheader.PCXxSize,AX
  INC PCXheader.PCXxSize
  MOV CX,PCXheader.PCXySize
  SUB CX,PCXheader.ymin
  INC CX            ; Number of lines to encode
SavePCXloop:
  XOR DX,DX         ; DX holds the pixel being processed
EncodeLine:
  XOR SI,SI         ; SI holds the number of consecutive equal pixels
  PUSH BX
FindEquals:
  MOV BX,DX
  ADD BX,SI
  CMP BX,PCXheader.PCXxSize     ; Have we reached the end of line?
  JGE @F            ; Yes: write data
  CMP SI,63         ; A maximum of 63 consecutive pixels is allowed
  JGE @F
  MOV BX,DI
  ADD BX,SI
  MOV AL,ES:[BX]
  CMP AL,ES:[BX+1]  ; Let's check if we have two equal consecutive pixels
  JNE @F            ; No: write a single pixel
  INC SI            ; Yes: increase the consecutive pixels counter (SI)
  JMP FindEquals
@@:
  CMP SI,0          ; Are there any consecutive equal pixels?
  JE @F             ; No: write a single pixel
  ADD DX,SI
  ADD DI,SI
  MOV BX,SI
  OR BL,0C0h
  MOV AH,BL
  POP BX
  MOV Buffer,AH
  CALL WriteBuffer
  JC Error_Write
  MOV Buffer,AL
  CALL WriteBuffer
  JC Error_Write
  JMP EncodeNext
@@:
  POP BX
  INC DX
  INC DI
  TEST AL,0C0h
  JZ SinglePixel
  MOV Buffer,0C1h
  CALL WriteBuffer
  JC Error_Write
  JMP SinglePixel
EncodeNext:
  CMP DX,PCXheader.PCXxSize
  JL EncodeLine
  ADD DI,320
  SUB DI,PCXheader.PCXxSize
  DEC CX
  JNZ SavePCXloop
  JMP SavePCXpal
SinglePixel:
  MOV Buffer,AL
  CALL WriteBuffer
  JC Error_Write
  JMP EncodeNext
SavePCXpal:
  MOV Buffer,12
  CALL WriteBuffer
  JC Error_Write
  MOV DX,[BP+12]
  MOV DS,DX
  MOV DX,@DATA
  MOV SI,[BP+10]
  MOV CX,768
@@:
  LODSB
  SHL AL,2
  PUSH DS
  MOV DS,DX
  MOV Buffer,AL
  CALL WriteBuffer
  JC Error_Write
  POP DS
  DEC CX
  JNZ @B
  JMP SaveCloseFile
SaveBMP:
  MOV Buffer,'B'
  CALL WriteBuffer
  JC Error_Write
  MOV BMPheader.BMPid,'M'
  XOR EAX,EAX
  MOV AX,[BP+20]
  SUB AX,[BP+24]
  INC AX
  MOV BMPheader.BMPxSize,EAX
  XOR ECX,ECX
  MOV CX,[BP+18]
  SUB CX,[BP+22]
  INC CX
  MOV BMPheader.BMPySize,ECX
  MUL CX
  SHL EDX,16
  MOV DX,AX
  MOV BMPheader.iSize,EDX
  ADD EDX,1078
  MOV BMPheader.BMPlen,EDX
  MOV BMPheader.res,0
  MOV BMPheader.dataoff,1078
  MOV BMPheader.headSize,40
  MOV BMPheader.BMPplanes,1
  MOV BMPheader.BMPbpp,8
  MOV BMPheader.comp,0
  MOV BMPheader.xpm,3790
  MOV BMPheader.ypm,3780
  MOV BMPheader.colus,0
  MOV BMPheader.impcol,0
  MOV CX,SIZE BMPheader
  MOV DX,OFFSET BMPheader
  MOV AX,@DATA
  MOV DS,AX
  MOV AH,40h        ; Saves the BMP header
  INT 21h
  JC Error_Write
  MOV SI,[BP+10]    ; FS:SI now points to the palette string
  MOV AX,[BP+12]
  MOV FS,AX
  MOV CX,256
@@:
  MOV AL,FS:[SI+2]
  SHL AL,2
  MOV Buffer,AL
  CALL WriteBuffer
  JC Error_Write
  MOV AL,FS:[SI+1]
  SHL AL,2
  MOV Buffer,AL
  CALL WriteBuffer
  JC Error_Write
  MOV AL,FS:[SI]
  SHL AL,2
  MOV Buffer,AL
  CALL WriteBuffer
  JC Error_Write
  MOV Buffer,0
  CALL WriteBuffer
  JC Error_Write
  ADD SI,3
  DEC CX
  JNZ @B
  MOV ECX,BMPheader.BMPySize
SaveBMPloop:
  MOV DX,CX
  ADD DX,[BP+22]
  DEC DX
  MOV SI,DX
  SHL DX,8
  SHL SI,6
  ADD DX,SI
  ADD DX,[BP+24]
  PUSH CX
  PUSH DS
  MOV ECX,BMPheader.BMPxSize
  MOV AX,ES
  MOV DS,AX
  MOV AH,40h
  INT 21h
  POP DS
  POP CX
  JC Error_Write
  DEC CX
  JNZ SaveBMPloop
  JMP SaveCloseFile
SaveBSV:
  MOV Buffer,0FDh
  CALL WriteBuffer
  JC Error_Write
  MOV AX,[BP+20]
  SUB AX,[BP+24]
  INC AX
  MOV CX,[BP+18]
  SUB CX,[BP+22]
  INC CX
  CMP AX,320
  JNE @F
  CMP CX,200
  JNE @F
  MOV BSVheader.SourceSeg,0A000h
  MOV BSVheader.SourceOff,0
  MOV BSVheader.BSVlen,64000
  MOV CX,6
  MOV DX,OFFSET BSVheader
  MOV AX,@DATA
  MOV DS,AX
  MOV AH,040h
  INT 21h
  JC Error_Write
  MOV CX,64000
  XOR DX,DX
  MOV AX,ES
  MOV DS,AX
  MOV AH,040h
  INT 21h
  JC Error_Write
  JMP BSVsavePal
@@:
  MOV BSVheader.SourceSeg,'QD'
  MOV BSVheader.SourceOff,'þB'
  MOV BSVheader.BSVxSize,AX
  SHL BSVheader.BSVxSize,3
  MOV BSVheader.BSVySize,CX
  MUL CX
  ADD AX,4
  MOV BSVheader.BSVlen,AX
  MOV CX,10
  MOV DX,OFFSET BSVheader
  PUSH DS
  MOV AX,@DATA
  MOV DS,AX
  MOV AH,040h        ; Saves the BSAVE header
  INT 21h
  POP DS
  JC Error_Write
  SHR BSVheader.BSVxSize,3
  XOR CX,CX
@@:
  MOV DX,[BP+22]
  ADD DX,CX
  MOV AX,DX
  SHL AX,8
  SHL DX,6
  ADD DX,AX
  ADD DX,[BP+24]
  PUSH DS
  PUSH CX
  MOV CX,BSVheader.BSVxSize
  MOV AX,ES
  MOV DS,AX
  MOV AH,040h        ; Saves scanline
  INT 21h
  POP CX
  POP DS
  JC Error_Write
  INC CX
  CMP CX,BSVheader.BSVySize
  JL @B
BSVsavePal:
  MOV AX,[BP+12]
  MOV DS,AX
  MOV DX,[BP+10]
  MOV CX,768
  MOV AH,040h
  INT 21h
  JMP SaveCloseFile
Error_Create:
  MOV AX,1          ; Error 1: cannot create file
  MOV LastError,9
  JMP EndSaveLayer
Error_Write:
  MOV AH,3Eh
  INT 21h
  MOV AX,2          ; Error 2: cannot write to disk (disk full?)
  MOV LastError,10
  JMP EndSaveLayer
SaveCloseFile:
  MOV AH,3Eh        ; Function 3Eh: close file
  INT 21h
  XOR AX,AX
EndSaveLayer:
  CALL UnhookInt24
  POP BP
  POP DS
  RET 20
xDQBsaveImage ENDP

; ---------------------------------------------------------------------------
; Internal procedures for FLI animation handling
; ---------------------------------------------------------------------------
DecodeCOLOR PROC NEAR
  MOV AX,FS:[BX]
  ADD BX,2
  MOV Packets,AX
  XOR AH,AH         ; AH is the color index
COLORpacket:
  ADD AH,FS:[BX]
  INC BX
  MOV DX,03C8h
  MOV AL,AH
  OUT DX,AL
  XOR CH,CH
  MOV CL,FS:[BX]
  INC BX
  MOV DX,03C9h
  CMP CX,0
  JNE SetColor
  MOV CX,256
SetColor:
  MOV AL,FS:[BX]
  INC BX
  OUT DX,AL
  MOV AL,FS:[BX]
  INC BX
  OUT DX,AL
  MOV AL,FS:[BX]
  INC BX
  OUT DX,AL
  INC AH
  DEC CX
  JNZ SetColor
  DEC Packets
  JNZ COLORpacket
  RET
DecodeCOLOR ENDP


DecodeLC PROC NEAR
  MOV AX,FS:[BX]
  ADD BX,2
  MOV CurLine,AX        ; CurLine holds number of lines to skip
  MOV SI,FS:[BX]
  ADD BX,2
LCline:
  MOV DI,CurLine
  MOV AX,DI
  SHL DI,6
  SHL AX,8
  ADD DI,AX
  XOR AH,AH
  MOV AL,FS:[BX]
  INC BX
  MOV Packets,AX        ; Store number of packets of current compressed line
  OR AX,AX
  JZ NextLCline
LCpacket:
  XOR DH,DH
  MOV DL,FS:[BX]
  INC BX
  ADD DI,DX
  XOR CH,CH
  MOV CL,FS:[BX]
  INC BX
  OR CL,CL
  JS LCrep
  PUSH SI
  PUSH DS
  MOV SI,BX
  ADD BX,CX
  MOV AX,FS
  MOV DS,AX
  REP MOVSB
  POP DS
  POP SI
  JMP LCnextPacket
LCrep:
  NEG CL
  MOV AL,FS:[BX]
  INC BX
  REP STOSB
LCnextPacket:
  DEC Packets
  JNZ LCpacket
NextLCline:
  INC CurLine
  DEC SI
  JNZ LCline
  RET
DecodeLC ENDP


DecodeBRUN PROC NEAR
  MOV CurLine,0
BRUNline:
  XOR DI,DI
  ADD DI,CurLine
  XOR AH,AH
  MOV AL,FS:[BX]
  INC BX
  MOV Packets,AX
BRUNpacket:
  XOR CH,CH
  MOV CL,FS:[BX]
  INC BX
  OR CL,CL
  JS BRUNrep
  MOV AL,FS:[BX]
  INC BX
  REP STOSB
  JMP BRUNnextPacket
BRUNrep:
  NEG CL
  PUSH SI
  PUSH DS
  MOV SI,BX
  ADD BX,CX
  MOV AX,FS
  MOV DS,AX
  REP MOVSB
  POP DS
  POP SI
BRUNnextPacket:
  DEC Packets
  JNZ BRUNpacket
  ADD CurLine,320
  CMP CurLine,64000
  JNE BRUNline
  RET
DecodeBRUN ENDP


DecodeFrame PROC NEAR
  MOV BX,FLIfile
  MOV AH,03Fh
  MOV DX,OFFSET FLIframeChunk
  MOV CX,16
  INT 21h
  JC EndDecodeFrame
  CMP FLIframeChunk.fID,0F1FAh     ; If there's an unknown frame type, skip it
  JNE EndDecodeFrame
  MOV AX,FLIframeChunk.chunks
  MOV FLIchunk,AX
  MOV ChunkPos,0
DecodeChunk:
  MOV AH,03Fh
  MOV DX,OFFSET FLIdataChunk
  MOV CX,6
  MOV BX,FLIfile
  INT 21h
  JC EndDecodeFrame
  PUSH DS
  XOR DX,DX
  MOV ECX,FLIdataChunk.cSize
  SUB CX,6
  MOV AX,FLIbufSeg
  MOV DS,AX
  MOV AH,03Fh
  INT 21h
  POP DS
  JC EndDecodeFrame
  XOR BX,BX
  CMP FLIdataChunk.cID,11
  JNE NotCOLOR
  CALL DecodeCOLOR          ; COLOR chunk type
  JMP NextChunk
NotCOLOR:
  CMP FLIdataChunk.cID,12
  JNE NotLC
  CALL DecodeLC             ; LC chunk type
  JMP NextChunk
NotLC:
  CMP FLIdataChunk.cID,13
  JNE NotBLACK
  XOR DI,DI                 ; BLACK chunk type
  XOR EAX,EAX
  MOV CX,16000
  REP STOSD
  JMP NextChunk
NotBLACK:
  CMP FLIdataChunk.cID,15
  JNE NotBRUN
  CALL DecodeBRUN           ; BRUN chunk type
  JMP NextChunk
NotBRUN:
  CMP FLIdataChunk.cID,16
  JNE EndDecodeFrame
  PUSH DS                   ; COPY chunk type
  MOV AX,FLIbufSeg
  MOV DS,AX
  XOR SI,SI
  XOR DI,DI
  MOV CX,16000
  REP MOVSD
  POP DS
NextChunk:
  DEC FLIchunk
  JNZ DecodeChunk
  CLC
EndDecodeFrame:
  RET
DecodeFrame ENDP

; ---------------------------------------------------------------------------
; DQBplayFLI FUNCTION
; purpose:
;   Plays a FLI animation. Supports double-buffering, stop key and looping.
; declaration:
;   DECLARE FUNCTION xDQBplayFLI(BYVAL FileSeg,BYVAL FileOff,BYVAL BufLayer,
;                                BYVAL StopKey,BYVAL Looped)
;   DECLARE FUNCTION DQBplayFLI(FileName AS STRING,BufLayer AS INTEGER,
;                               StopKey AS INTEGER,Looped AS INTEGER)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBplayFLI
xDQBplayFLI PROC
  ; Stack layout:
  ;
  ; 16  FileSeg
  ; 14  FileOff
  ; 12  BufLayer
  ; 10  StopKey
  ; 08  Looped
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  CMP FLIactive,0
  JE fFileOk
  MOV AX,5
  MOV LastError,21
  POP BP
  POP DS
  RET 10
fFileOk:
  MOV AH,48h
  MOV BX,4096
  INT 21h
  JNC MemOk
  MOV AX,1          ; Error 1: Not enough free base memory
  MOV LastError,7
  POP BP
  POP DS
  RET 10
MemOk:
  MOV FLIbufSeg,AX
  MOV FS,AX
  CALL HookInt24
  MOV BX,[BP+12]
  CALL GetLayerSeg
  MOV ES,CX
  XOR EAX,EAX
  XOR DI,DI
  MOV CX,16000
  REP STOSD  
  MOV AX,[BP+16]
  MOV DS,AX
  MOV DX,[BP+14]
  MOV AX,3D00h
  INT 21h
  JC Error_OpenFLI
  MOV BX,AX
  MOV AX,@DATA
  MOV DS,AX
  MOV FLIfile,BX
  MOV AH,03Fh
  MOV DX,OFFSET FLIheader
  MOV CX,18
  INT 21h
  JC Error_ReadFLI
  CMP FLIheader.hID,0AF11h  ; Check file format
  JNE Error_BadFLI
  CMP FLIheader.Xres,320
  JNE Error_BadFLI
  CMP FLIheader.Yres,200
  JNE Error_BadFLI
  CMP FLIheader.ColorBits,8
  JNE Error_BadFLI
  MOV CX,110
SkipReserved:
  CALL ReadBuffer
  JC Error_ReadFLI
  DEC CX
  JNZ SkipReserved
  MOV FLIframe,0
  MOV FramePos,128
PlayFLIframe:
  CALL DecodeFrame
  JC Error_ReadFLI
  MOV CX,FLIheader.Speed
  MOV DX,3DAh       ; Vertical retrace port
WaitFLI:
  IN AL,DX
  AND AL,8
  JNZ WaitFLI
@@:
  IN AL,DX
  AND AL,8
  JZ @B
  DEC CX
  JNZ WaitFLI
  MOV AX,[BP+12]
  OR AX,AX
  JZ SkipDoubleBuffering
  PUSH ES
  PUSH DS
  MOV BX,ES
  MOV AX,0A000h
  MOV DS,BX
  MOV ES,AX
  MOV CX,16000
  XOR DI,DI
  XOR SI,SI
  REP MOVSD
  POP DS
  POP ES
SkipDoubleBuffering:
  MOV EAX,FLIframeChunk.fSize
  ADD FramePos,EAX
  MOV ECX,FramePos
  MOV DX,CX
  SHR ECX,16
  MOV AX,04200h
  MOV BX,FLIfile
  INT 21h
  JC Error_ReadFLI
  CMP KeyActive,0
  JE CheckLoop
  MOV SI,[BP+10]
  OR SI,SI
  JZ CheckLoop
  CMP SI,0FFFFh
  JNE CheckKey
  XOR SI,SI
@@:
  CMP KeyStatus[SI],1
  JE StopFLI
  INC SI
  CMP SI,128
  JL @B
  JMP CheckLoop
CheckKey:
  CMP KeyStatus[SI],1
  JE StopFLI
CheckLoop:
  INC FLIframe
  MOV AX,FLIheader.frames
  CMP FLIframe,AX
  JL PlayFLIframe
  CMP KeyActive,0
  JE StopFLI
  MOV AX,[BP+10]
  OR AX,AX
  JZ StopFLI
  MOV AX,[BP+8]
  OR AX,AX
  JZ StopFLI
  MOV FLIframe,0
  MOV FramePos,128
  MOV ECX,FramePos
  MOV DX,CX
  SHR ECX,16
  MOV AX,04200h
  MOV BX,FLIfile
  INT 21h
  JC Error_ReadFLI
  JMP PlayFLIframe
StopFLI:
  MOV BX,FLIfile
  MOV AH,3Eh
  INT 21h
  MOV AH,49h
  MOV BX,FLIbufSeg
  MOV ES,BX
  INT 21h
  XOR AX,AX
  JMP EndPlayFLI
Error_OpenFLI:
  MOV AH,49h
  MOV BX,FLIbufSeg
  MOV ES,BX
  INT 21h
  MOV AX,2          ; Error 2: Cannot open file (does it exist?)
  MOV LastError,4
  JMP EndPlayFLI
Error_ReadFLI:
  MOV BX,@DATA
  MOV DS,BX
  MOV BX,FLIfile
  MOV AH,3Eh
  INT 21h
  MOV AH,49h
  MOV BX,FLIbufSeg
  MOV ES,BX
  INT 21h
  MOV AX,3          ; Error 3: Unable to read from file
  MOV LastError,5
  JMP EndPlayFLI
Error_BadFLI:
  MOV BX,FLIfile
  MOV AH,3Eh
  INT 21h
  MOV AH,49h
  MOV BX,FLIbufSeg
  MOV ES,BX
  INT 21h
  MOV AX,4          ; Error 4: Bad FLI file
  MOV LastError,11
EndPlayFLI:
  CALL UnhookInt24
  POP BP
  POP DS
  RET 10
xDQBplayFLI ENDP

; ---------------------------------------------------------------------------
; DQBopenFLI FUNCTION
; purpose:
;   Opens a FLI file and resets internal variables. Also returns number of
;   frames and speed
; declaration:
;   DECLARE FUNCTION xDQBopenFLI(BYVAL FileSeg,BYVAL FileOff,Frames,Speed)
;   DECLARE FUNCTION DQBopenFLI(FileName AS STRING,Frames AS INTEGER,
;                               Speed AS INTEGER)
; ---------------------------------------------------------------------------
EVEN
PUBLIC xDQBopenFLI
xDQBopenFLI PROC
  ; Stack layout:
  ;
  ; 14  FileSeg
  ; 12  FileOff
  ; 10  Frames
  ; 08  Speed
  ; 06  Basic return segment
  ; 04  Basic return offset
  ; 02  DS
  ; 00  BP
  PUSH DS
  PUSH BP
  MOV BP,SP
  CMP FLIactive,0
  JNE Error_AlreadyOpened
  MOV AH,48h
  MOV BX,4096
  INT 21h
  JC Error_NotEnoughMem
  MOV FLIbufSeg,AX
  MOV FS,AX
  CALL HookInt24
  MOV AX,[BP+14]
  MOV DS,AX
  MOV DX,[BP+12]
  MOV AX,3D00h
  INT 21h
  JC Error_OpenOpenFLI
  MOV BX,AX
  MOV AX,@DATA
  MOV DS,AX
  MOV FLIfile,BX
  MOV AH,03Fh
  MOV DX,OFFSET FLIheader
  MOV CX,18
  INT 21h
  JC Error_OpenReadFLI
  CMP FLIheader.hID,0AF11h  ; Check file format
  JNE Error_OpenBadFLI
  CMP FLIheader.Xres,320
  JNE Error_OpenBadFLI
  CMP FLIheader.Yres,200
  JNE Error_OpenBadFLI
  CMP FLIheader.ColorBits,8
  JNE Error_OpenBadFLI
  MOV CX,110
@@:
  CALL ReadBuffer
  JC Error_OpenReadFLI
  DEC CX
  JNZ @B
  MOV FLIframe,0
  MOV FramePos,128
  MOV SI,[BP+10]
  MOV AX,FLIheader.Frames
  MOV [SI],AX
  MOV SI,[BP+8]
  MOV AX,FLIheader.Speed
  MOV [SI],AX
  MOV FLIactive,1
  XOR AX,AX
  JMP EndOpenFLI
Error_NotEnoughMem:
  MOV AX,1          ; Error 1: Not enough free base memory
  MOV LastError,7
  POP BP
  POP DS
  RET 8
Error_OpenOpenFLI:
  MOV AH,49h
  MOV BX,FLIbufSeg
  MOV ES,BX
  INT 21h
  MOV AX,2          ; Error 2: Cannot open file (does it exist?)
  MOV LastError,4
  JMP EndOpenFLI
Error_OpenReadFLI:
  MOV BX,@DATA
  MOV DS,BX
  MOV BX,FLIfile
  MOV AH,3Eh
  INT 21h
  MOV AH,49h
  MOV BX,FLIbufSeg
  MOV ES,BX
  INT 21h
  MOV AX,3          ; Error 3: Unable to read from file
  MOV LastError,5
  JMP EndOpenFLI
Error_OpenBadFLI:
  MOV BX,FLIfile
  MOV AH,3Eh
  INT 21h
  MOV AH,49h
  MOV BX,FLIbufSeg
  MOV ES,BX
  INT 21h
  MOV AX,4          ; Error 4: Bad FLI file
  MOV LastError,11
  JMP EndOpenFLI
Error_AlreadyOpened:
  MOV AX,5          ; Error 5: A FLI file has already been opened
  MOV LastError,21
  POP BP
  POP DS
  RET 8
EndOpenFLI:
  CALL UnhookInt24
  POP BP
  POP DS
  RET 8
xDQBopenFLI ENDP

; ---------------------------------------------------------------------------
; DQBcloseFLI SUB
; purpose:
;   Closes an opened FLI file
; declaration:
;   DECLARE SUB DQBcloseFLI()
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBcloseFLI
DQBcloseFLI PROC
  CMP FLIactive,0
  JE EndCloseFLI
  MOV BX,FLIfile
  MOV AH,3Eh
  INT 21h
  MOV AH,49h
  MOV BX,FLIbufSeg
  MOV ES,BX
  INT 21h
  MOV FLIactive,0
EndCloseFLI:
  RET
DQBcloseFLI ENDP

; ---------------------------------------------------------------------------
; DQBplayFLIstep SUB
; purpose:
;   Decodes the next frame of an opened FLI file into a specified layer. If
;   there are no more frames left, the animation automatically restarts from
;   the first one. On errors, this function does nothing.
; declaration:
;   DECLARE SUB DQBplayFLIstep(BYVAL Layer)
; ---------------------------------------------------------------------------
EVEN
PUBLIC DQBplayFLIstep
DQBplayFLIstep PROC
  PUSH DS
  PUSH BP
  MOV BP,SP
  CALL HookInt24
  CMP FLIactive,0
  JE EndPlayFLIstep
  MOV BX,[BP+8]
  CALL GetLayerSeg
  MOV ES,CX
  MOV AX,FLIbufSeg
  MOV FS,AX
  CALL DecodeFrame
  JC EndPlayFLIstep
  MOV EAX,FLIframeChunk.fSize
  ADD FramePos,EAX
  MOV ECX,FramePos
  MOV DX,CX
  SHR ECX,16
  MOV AX,04200h
  MOV BX,FLIfile
  INT 21h
  JC EndPlayFLIstep
  INC FLIframe
  MOV AX,FLIheader.frames
  CMP FLIframe,AX
  JL EndPlayFLIstep
  MOV FLIframe,0
  MOV FramePos,128
  MOV ECX,FramePos
  MOV DX,CX
  SHR ECX,16
  MOV AX,04200h
  MOV BX,FLIfile
  INT 21h
EndPlayFLIstep:
  CALL UnHookInt24
  POP BP
  POP DS
  RET 2
DQBplayFLIstep ENDP

END
