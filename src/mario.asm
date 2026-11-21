; =====================================================================
; File    : mario.asm
; Project : Super Mario Engine (EL2003 COAL Semester Project)
; Module  : 1 - Program Skeleton and Build Setup
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

; ---------------------------------------------------------------------
; CODE
; ---------------------------------------------------------------------
start:
        jmp  main               ; jump over to the main procedure

; Procedure : main
; Purpose   : Program entry. Prints a message, waits for a key,
;             restores text mode and exits to DOS.
; Inputs    : none
; Outputs   : none
; Registers : all (program ends here)
main:
        call ShowBanner         ; print the test message
        call WaitForKey         ; wait so message can be read
        call RestoreTextMode    ; back to 80x25 text mode
        call ExitToDos          ; terminate program

; Procedure : ShowBanner
; Purpose   : Print the '$'-terminated string banner_msg (DOS 09h).
; Inputs    : none
; Outputs   : none
; Registers : none changed (AX, DX saved and restored)
ShowBanner:
        push ax
        push dx
        mov  dx, banner_msg     ; DS:DX -> string
        mov  ah, 09h            ; DOS: print string ending in '$'
        int  21h
        pop  dx
        pop  ax
        ret

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

; ---------------------------------------------------------------------
; DATA
; ---------------------------------------------------------------------
banner_msg      db 'Super Mario Engine - skeleton OK. Press any key.$'

; --- Hero data (8.8 fixed point) ---
mario_x         dw 32 * 256     ; world x, start at pixel 32
mario_y         dw 0            ; world y
camera_x        dw 0            ; world x of left screen edge

; --- Keyboard state table: 1 = key held ---
key_table       times 128 db 0