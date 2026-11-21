; =====================================================================
; File    : mario.asm
; Project : Super Mario Engine (EL2003 COAL Semester Project)
; Modules : 1 (skeleton), 2 (video, PutPixel, FillRect),
;           3 (level map, GetTile, DrawTile, DrawMap, ResetMap)
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
VISIBLE_COLS    equ 20          ; tile columns visible on screen
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

; --- Tile codes ---
TILE_SKY        equ 0
TILE_GROUND     equ 1
TILE_BRICK      equ 2
TILE_Q_COIN     equ 3
TILE_Q_MUSH     equ 4
TILE_EMPTY      equ 5
TILE_PIPE_TL    equ 6
TILE_PIPE_TR    equ 7
TILE_PIPE_BL    equ 8
TILE_PIPE_BR    equ 9
TILE_STAIR      equ 10
TILE_COIN       equ 11
TILE_FLAG       equ 12

; ---------------------------------------------------------------------
; CODE
; ---------------------------------------------------------------------
start:
        jmp  main               ; jump over to the main procedure

; Procedure : main
; Purpose   : Program entry. Sets Mode 13h, loads the map, draws the
;             first 20 columns, waits for a key, then exits to DOS.
; Inputs    : none
; Outputs   : none
; Registers : all (program ends here)
main:
        call SetVideoMode13     ; switch to 320x200x256 graphics
        call ResetMap           ; working map = original map
        push 0                  ; camera_x = 0 for this test
        call DrawMap            ; draw visible part of the level
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
; Purpose   : Fill a rectangle with one colour. Pixels that fall
;             outside the screen are skipped (clipping).
; Inputs    : stack: x, y, width, height, colour (words), pushed
;             in this order. x may be negative (signed).
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
        push si
        push di
        push es

        mov  ax, VIDEO_SEG
        mov  es, ax             ; ES -> video memory

        mov  dx, [bp+6]         ; DX = rows left to draw
        mov  si, [bp+10]        ; SI = current y
.row_loop:
        cmp  si, SCREEN_H       ; y outside 0..199? (unsigned check
        jae  .skip_row          ; also catches negative y)

        ; BX = start offset of this row = y * 320
        mov  ax, si
        shl  ax, 8              ; y * 256
        mov  bx, si
        shl  bx, 6              ; y * 64
        add  bx, ax             ; y * 320

        mov  cx, [bp+8]         ; CX = width
        mov  di, [bp+12]        ; DI = current x
        mov  al, [bp+4]         ; AL = colour
.pixel_loop:
        cmp  di, SCREEN_W       ; x outside 0..319? skip this pixel
        jae  .skip_pixel
        push di
        add  di, bx             ; DI = y*320 + x
        mov  [es:di], al        ; write one pixel
        pop  di
.skip_pixel:
        inc  di                 ; next pixel to the right
        loop .pixel_loop
.skip_row:
        inc  si                 ; next row down
        dec  dx
        jnz  .row_loop

        pop  es
        pop  di
        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        pop  bp
        ret  10

; Procedure : ResetMap
; Purpose   : Copy the original map over the working map.
; Inputs    : none
; Outputs   : none (map_working = map_original)
; Registers : none changed
ResetMap:
        push cx
        push si
        push di
        push es
        push ds
        pop  es                 ; ES = DS (same segment in a .COM)
        cld                     ; copy forward
        mov  si, map_original   ; source
        mov  di, map_working    ; destination
        mov  cx, LEVEL_SIZE     ; 720 bytes
        rep  movsb              ; block copy
        pop  es
        pop  di
        pop  si
        pop  cx
        ret

; Procedure : GetTile
; Purpose   : Find the tile code at a pixel position of the level.
; Inputs    : stack: px, py (words), pushed in this order
; Outputs   : AL = tile code (0 if outside the level)
; Registers : AX changed (result); others unchanged. ret 4.
; Stack     : [bp+6]=px  [bp+4]=py
GetTile:
        push bp
        mov  bp, sp
        push bx
        push cx

        mov  bx, [bp+6]         ; BX = px
        shr  bx, 4              ; BX = column
        mov  cx, [bp+4]         ; CX = py
        shr  cx, 4              ; CX = row

        cmp  bx, LEVEL_COLS     ; column outside 0..59?
        jae  .outside
        cmp  cx, LEVEL_ROWS     ; row outside 0..11?
        jae  .outside

        ; index = row * 60 + column = row*64 - row*4 + column
        mov  ax, cx
        shl  ax, 6              ; row * 64
        shl  cx, 2              ; row * 4
        sub  ax, cx             ; row * 60
        add  ax, bx             ; + column
        mov  bx, ax
        mov  al, [map_working + bx]   ; read tile code
        jmp  .done
.outside:
        xor  al, al             ; outside the level = sky
.done:
        pop  cx
        pop  bx
        pop  bp
        ret  4

; Procedure : DrawTile
; Purpose   : Draw one 16x16 tile as a coloured block (placeholder
;             art; real tile art can replace it later).
; Inputs    : stack: x, y (screen position, x may be negative),
;             tile code. Pushed in this order.
; Outputs   : none
; Registers : none changed. ret 6.
; Stack     : [bp+8]=x  [bp+6]=y  [bp+4]=tile code
DrawTile:
        push bp
        mov  bp, sp
        push ax
        push bx

        mov  bx, [bp+4]         ; BX = tile code
        mov  al, [tile_colours + bx]    ; AL = colour of this tile
        xor  ah, ah             ; AX = colour

        push word [bp+8]        ; x
        push word [bp+6]        ; y
        push TILE_SIZE          ; width
        push TILE_SIZE          ; height
        push ax                 ; colour
        call FillRect

        pop  bx
        pop  ax
        pop  bp
        ret  6

; Procedure : DrawMap
; Purpose   : Draw the visible part of the level (20 columns plus one
;             partial column) for a given camera position.
; Inputs    : stack: camera_x (word)
; Outputs   : none
; Registers : none changed. ret 2.
; Stack     : [bp+4]=camera_x
; Method    : first column = camera_x >> 4, pixel offset =
;             camera_x AND 15, so the picture scrolls pixel by pixel.
DrawMap:
        push bp
        mov  bp, sp
        push ax
        push bx
        push cx
        push dx
        push si

        mov  ax, [bp+4]         ; AX = camera_x
        mov  si, ax
        shr  si, 4              ; SI = first column to draw
        and  ax, 15             ; AX = pixel offset (0..15)
        mov  dx, ax             ; DX = offset (kept)

        xor  cx, cx             ; CX = row (0..11)
.row_loop:
        xor  bx, bx             ; BX = screen column (0..20)
.col_loop:
        ; tile column in the level = SI + BX
        push bx
        mov  ax, si
        add  ax, bx             ; AX = level column
        cmp  ax, LEVEL_COLS
        jae  .skip_tile         ; past the end of the level

        ; tile index = row*60 + column
        push ax                 ; save column
        mov  ax, cx
        shl  ax, 6              ; row * 64
        mov  bx, cx
        shl  bx, 2              ; row * 4
        sub  ax, bx             ; row * 60
        pop  bx                 ; BX = column
        add  bx, ax             ; BX = index
        mov  al, [map_working + bx]
        xor  ah, ah             ; AX = tile code
        pop  bx                 ; BX = screen column again
        push bx

        ; screen x = BX*16 - offset ; screen y = row*16
        push ax                 ; keep tile code
        mov  ax, bx
        shl  ax, 4              ; BX * 16
        sub  ax, dx             ; minus pixel offset
        push ax                 ; parameter 1: x
        mov  ax, cx
        shl  ax, 4
        push ax                 ; parameter 2: y
        mov  bx, sp
        mov  ax, [bx+4]         ; AX = saved tile code
        push ax                 ; parameter 3: tile code
        call DrawTile
        pop  ax                 ; drop the saved tile code
.skip_tile:
        pop  bx                 ; BX = screen column
        inc  bx
        cmp  bx, VISIBLE_COLS + 1
        jb   .col_loop

        inc  cx
        cmp  cx, LEVEL_ROWS
        jb   .row_loop

        pop  si
        pop  dx
        pop  cx
        pop  bx
        pop  ax
        pop  bp
        ret  2

; ---------------------------------------------------------------------
; DATA
; ---------------------------------------------------------------------
; --- Hero data (8.8 fixed point) ---
mario_x         dw 32 * 256     ; world x, start at pixel 32
mario_y         dw 0            ; world y
camera_x        dw 0            ; world x of left screen edge

; --- Keyboard state table: 1 = key held ---
key_table       times 128 db 0

; --- Colour of each tile code (placeholder art) ---
tile_colours:
        db COL_SKY              ; 0  sky
        db COL_BROWN            ; 1  ground
        db COL_RED              ; 2  brick
        db COL_YELLOW           ; 3  ? block (coin)
        db COL_YELLOW           ; 4  ? block (mushroom)
        db COL_DGRAY            ; 5  empty block
        db COL_GREEN            ; 6  pipe top-left
        db COL_GREEN            ; 7  pipe top-right
        db COL_LGREEN           ; 8  pipe body-left
        db COL_LGREEN           ; 9  pipe body-right
        db COL_LGRAY            ; 10 stair block
        db COL_WHITE            ; 11 coin
        db COL_BLACK            ; 12 flag pole

; --- Level map: 60 columns x 12 rows, one byte per tile ---
; (small test map: sky, a few blocks, ground. Real level comes next)
map_original:
        times 60 db 0                           ; row 0  (HUD row)
        times 60 db 0                           ; row 1
        times 60 db 0                           ; row 2
        times 60 db 0                           ; row 3
        times 60 db 0                           ; row 4
        times 60 db 0                           ; row 5
        times 60 db 0                           ; row 6
        db 0,0,0,0,0,0,0,0,0,0,3,2,3,2,0,0,0,0,0,0
        times 40 db 0                           ; row 7
        db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        times 40 db 0                           ; row 8
        times 60 db 0                           ; row 9
        times 60 db 1                           ; row 10 (ground)
        times 60 db 1                           ; row 11 (ground)

map_working     times LEVEL_SIZE db 0           ; changes during the game