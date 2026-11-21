; =====================================================================
; File    : mario.asm
; Project : Super Mario Engine (EL2003 COAL Semester Project)
; Modules : 1 (skeleton) and 2 (video mode, PutPixel, FillRect)
; Build   : tools\nasm.exe -f bin src\mario.asm -o MARIO.COM
; =====================================================================

BITS 16                         ; 16-bit real mode code
ORG  100h                       ; .COM files load at offset 100h

; ---------------------------------------------------------------------
; CONSTANTS
; ---------------------------------------------------------------------
SCREEN_W        equ 320         ; screen width in pixels
SCREEN_H        equ 200         ; screen height in pixels
VIDEO_SEG       equ 0A000h      ; VGA Mode 13h video segment
TILE_SIZE       equ 16          ; tile / sprite size in pixels
LEVEL_COLS      equ 60          ; level width in tiles
LEVEL_ROWS      equ 12          ; level height in tiles
LEVEL_SIZE      equ LEVEL_COLS * LEVEL_ROWS     ; 720 bytes
START_LIVES     equ 3           ; lives at new game
LEVEL_TIME      equ 300         ; seconds per life

; --- Colours (default VGA palette indexes) ---
COL_BLACK       equ 0
COL_BLUE        equ 1
COL_GREEN       equ 2
COL_CYAN        equ 3
COL_RED         equ 4
COL_MAGENTA     equ 5
COL_BROWN       equ 6
COL_LGRAY       equ 7
COL_DGRAY       equ 8
COL_SKY         equ 9           ; light blue, used for sky
COL_LGREEN      equ 10
COL_LCYAN       equ 11
COL_LRED        equ 12
COL_PINK        equ 13
COL_YELLOW      equ 14
COL_WHITE       equ 15

; ---------------------------------------------------------------------
; CODE
; ---------------------------------------------------------------------
start:
        jmp  main               ; jump over to the main procedure

; Procedure : main
; Purpose   : Program entry. Sets Mode 13h, shows the colour test
;             screen, waits for a key, restores text mode, exits.
; Inputs    : none
; Outputs   : none
; Registers : all (program ends here)
main:
        call SetVideoMode13     ; switch to 320x200x256 graphics
        call ColourTestScreen   ; draw one box per colour
        call WaitForKey         ; keep the picture on screen
        call RestoreTextMode    ; back to text mode
        call ExitToDos          ; terminate program

; Procedure : WaitForKey
; Purpose   : Wait until the user presses any key (BIOS INT 16h).
; Inputs    : none
; Outputs   : none
; Registers : none changed (AX saved and restored)
WaitForKey:
        push ax
        xor  ax, ax             ; AH = 00h: wait for keystroke
        int  16h
        pop  ax
        ret

; Procedure : RestoreTextMode
; Purpose   : Switch the display to 80x25 text mode (mode 03h).
; Inputs    : none
; Outputs   : none
; Registers : none changed (AX saved and restored)
RestoreTextMode:
        push ax
        mov  ax, 0003h          ; AH=00h set mode, AL=03h text mode
        int  10h
        pop  ax
        ret

; Procedure : ExitToDos
; Purpose   : Terminate the program and return to DOS.
; Inputs    : none
; Outputs   : none (does not return)
; Registers : AX changed (program ends)
ExitToDos:
        mov  ax, 4C00h          ; AH=4Ch terminate, AL=00h return code
        int  21h

; Procedure : SetVideoMode13
; Purpose   : Switch to VGA Mode 13h (320x200, 256 colours).
; Inputs    : none
; Outputs   : none
; Registers : none changed (AX saved and restored)
SetVideoMode13:
        push ax
        mov  ax, 0013h          ; AH=00h set mode, AL=13h graphics
        int  10h
        pop  ax
        ret

; Procedure : PutPixel
; Purpose   : Draw one pixel on the screen (video memory).
; Inputs    : stack: x, y, colour (words), pushed in this order
; Outputs   : none
; Registers : none changed. Callee removes its 3 parameters (ret 6).
; Stack     : [bp+8]=x  [bp+6]=y  [bp+4]=colour
PutPixel:
        push bp
        mov  bp, sp
        push ax
        push bx
        push di
        push es

        mov  ax, VIDEO_SEG
        mov  es, ax             ; ES -> video memory

        mov  bx, [bp+6]         ; BX = y
        mov  ax, bx
        shl  ax, 8              ; AX = y * 256
        shl  bx, 6              ; BX = y * 64
        add  ax, bx             ; AX = y * 320
        add  ax, [bp+8]         ; AX = y * 320 + x
        mov  di, ax             ; DI = offset of the pixel

        mov  ax, [bp+4]         ; AL = colour
        mov  [es:di], al        ; write pixel to screen

        pop  es
        pop  di
        pop  bx
        pop  ax
        pop  bp
        ret  6

; Procedure : FillRect
; Purpose   : Fill a rectangle with one colour.
; Inputs    : stack: x, y, width, height, colour (all words), pushed
;             in this order
; Outputs   : none
; Registers : none changed. Callee removes 5 parameters (ret 10).
; Stack     : [bp+12]=x [bp+10]=y [bp+8]=width [bp+6]=height
;             [bp+4]=colour
FillRect:
        push bp
        mov  bp, sp
        push ax
        push bx
        push cx
        push dx
        push di
        push es

        mov  ax, VIDEO_SEG
        mov  es, ax             ; ES -> video memory

        mov  bx, [bp+10]        ; BX = y
        mov  ax, bx
        shl  ax, 8              ; y * 256
        shl  bx, 6              ; y * 64
        add  ax, bx             ; y * 320
        add  ax, [bp+12]        ; + x
        mov  di, ax             ; DI = start of the first row

        mov  al, [bp+4]         ; AL = colour
        mov  dx, [bp+6]         ; DX = rows left to draw

.row_loop:
        mov  cx, [bp+8]         ; CX = width (pixels in this row)
        push di                 ; remember start of this row
.pixel_loop:
        mov  [es:di], al        ; write one pixel
        inc  di                 ; next pixel to the right
        loop .pixel_loop        ; CX = CX - 1, repeat until 0
        pop  di                 ; back to start of the row
        add  di, SCREEN_W       ; move down one row (+320)
        dec  dx                 ; one row done
        jnz  .row_loop          ; more rows? repeat

        pop  es
        pop  di
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        pop  bp
        ret  10

; Procedure : ColourTestScreen
; Purpose   : Show 16 colour boxes (4 x 4 grid) so every game colour
;             can be checked. Also draws one pixel with PutPixel.
; Inputs    : none
; Outputs   : none
; Registers : none changed
; Layout    : box x = 20 + col*75, box y = 20 + row*45
;             (computed with additions, no MUL, so DX stays safe)
ColourTestScreen:
        push ax
        push bx
        push cx
        push dx

        xor  bx, bx             ; BX = colour number 0..15
.next_box:
        ; ---- box x = 20 + col * 75 ----
        mov  cx, bx
        and  cx, 3              ; CX = column (0..3)
        mov  dx, 20             ; DX = 20 (start x)
        jcxz .x_done            ; column 0: x stays 20
.x_loop:
        add  dx, 75             ; one more column: +75
        loop .x_loop
.x_done:                        ; DX = box x

        ; ---- box y = 20 + row * 45 ----
        mov  cx, bx
        shr  cx, 2              ; CX = row (0..3)
        mov  ax, 20             ; AX = 20 (start y)
        jcxz .y_done            ; row 0: y stays 20
.y_loop:
        add  ax, 45             ; one more row: +45
        loop .y_loop
.y_done:                        ; AX = box y

        push dx                 ; parameter 1: x
        push ax                 ; parameter 2: y
        push 60                 ; parameter 3: width
        push 40                 ; parameter 4: height
        push bx                 ; parameter 5: colour
        call FillRect

        inc  bx                 ; next colour
        cmp  bx, 16
        jb   .next_box          ; repeat for colours 0..15

        push 5                  ; PutPixel test: x = 5
        push 5                  ;                y = 5
        push COL_WHITE
        call PutPixel

        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret

; ---------------------------------------------------------------------
; DATA
; ---------------------------------------------------------------------
; --- Hero data (8.8 fixed point) ---
mario_x         dw 32 * 256     ; world x, start at pixel 32
mario_y         dw 0            ; world y
camera_x        dw 0            ; world x of left screen edge

; --- Keyboard state table: 1 = key held ---
key_table       times 128 db 0