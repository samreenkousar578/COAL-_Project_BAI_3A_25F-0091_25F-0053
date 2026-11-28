; ============================================================
; FILE: src/enemies.asm
; Module 11: Enemies (Goombas & Koopas) AI & Background Restore
; ============================================================

; Initial enemy placements across the 960px level:
; Format: db type, dw start_x (pixels), dw start_y (pixels)
enemy_spawn_table:
    db ENEMY_GOOMBA
    dw 240, 160                 ; Goomba #1 before the first pipe
    db ENEMY_GOOMBA
    dw 380, 160                 ; Goomba #2 between the two pipes
    db ENEMY_KOOPA
    dw 520, 160                 ; Koopa #1 after the first pit
    db ENEMY_GOOMBA
    dw 620, 160                 ; Goomba #3 near the second pit
    db ENEMY_KOOPA
    dw 760, 160                 ; Koopa #2 before the final stairs
ENEMY_SPAWN_COUNT EQU 5

; ------------------------------------------------------------
; Name     : InitEnemies
; Purpose  : clears the enemy table and spawns all level enemies
;            in ENS_WALK state moving left
; ------------------------------------------------------------
InitEnemies:
    push ax
    push bx
    push cx
    push si
    push di

    ; Zero out all 8 enemy slots
    mov di, enemies
    mov cx, MAX_ENEMIES * EN_SIZE
    xor al, al
.clear_loop:
    mov [di], al
    inc di
    loop .clear_loop

    ; Populate initial enemies from enemy_spawn_table
    mov si, enemy_spawn_table
    mov di, enemies
    mov cx, ENEMY_SPAWN_COUNT
.spawn_loop:
    mov al, [si]                ; enemy type (ENEMY_GOOMBA or ENEMY_KOOPA)
    mov [di + EN_TYPE], al
    mov byte [di + EN_STATE], ENS_WALK
    mov ax, [si + 1]            ; start X (whole pixels)
    mov [di + EN_X], ax
    mov ax, [si + 3]            ; start Y (feet whole pixels)
    mov [di + EN_Y], ax

    ; Set walking speed based on enemy type
    cmp byte [di + EN_TYPE], ENEMY_KOOPA
    je .set_koopa_spd
    mov word [di + EN_SPEED], GOOMBA_SPEED
    jmp .dir_init
.set_koopa_spd:
    mov word [di + EN_SPEED], KOOPA_SPEED

.dir_init:
    mov byte [di + EN_DIR], 1   ; 1 = walk left toward Mario
    mov byte [di + EN_TIMER], 0 ; subpixel fraction accumulator
    mov word [di + EN_VY], 0

    add si, 5
    add di, EN_SIZE
    loop .spawn_loop

    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : UpdateEnemies
; Purpose  : moves active enemies sideways, turns them around at
;            walls or pit edges, and deactivates off-screen ones
; ------------------------------------------------------------
UpdateEnemies:
    push ax
    push bx
    push cx
    push dx
    push si

    cmp byte [game_state], STATE_PLAYING
    jne near .ue_done

    mov si, enemies
    mov cx, MAX_ENEMIES
.enemy_loop:
    cmp byte [si + EN_TYPE], ENEMY_NONE
    je near .next_enemy

    ; Only move enemies within 48px of the visible camera window
    mov ax, [si + EN_X]
    mov bx, [camera_x]
    sub bx, LEFT_BEHIND
    cmp ax, bx
    jl near .despawn_enemy      ; far behind camera -> remove enemy

    mov bx, [camera_x]
    add bx, SCREEN_W + 48
    cmp ax, bx
    jg near .next_enemy         ; not reached yet -> wait until Mario gets closer

    ; Add enemy speed (8.8) using EN_TIMER as subpixel accumulator
    mov ax, [si + EN_SPEED]
    add [si + EN_TIMER], al     ; add fractional byte
    mov al, ah
    xor ah, ah
    adc ax, 0                   ; whole-pixel step (0 or 1)
    cmp ax, 0
    je near .next_enemy

    ; Move left (EN_DIR = 1) or right (EN_DIR = 0)
    cmp byte [si + EN_DIR], 1
    jne .move_right

    ; --- Moving Left ---
    sub [si + EN_X], ax
    mov bx, [si + EN_X]
    cmp bx, 2
    jle .turn_right             ; hit left boundary of level -> turn right

    ; Check wall at front-left edge
    mov dx, [si + EN_Y]
    sub dx, 4
    call CheckPixelSolid
    jc .turn_right              ; hit pipe/wall -> turn around

    ; Check floor ahead under front-left foot so enemy doesn't walk into pits
    mov dx, [si + EN_Y]
    add dx, 2
    call CheckPixelSolid
    jnc .turn_right             ; pit edge ahead -> turn around
    jmp .next_enemy

.turn_right:
    mov byte [si + EN_DIR], 0
    jmp .next_enemy

.move_right:
    ; --- Moving Right ---
    add [si + EN_X], ax
    mov bx, [si + EN_X]
    add bx, 15                  ; front-right edge
    cmp bx, LEVEL_W_PX - 2
    jge .turn_left

    ; Check wall at front-right edge
    mov dx, [si + EN_Y]
    sub dx, 4
    call CheckPixelSolid
    jc .turn_left               ; hit pipe/wall -> turn around

    ; Check floor ahead under front-right foot
    mov dx, [si + EN_Y]
    add dx, 2
    call CheckPixelSolid
    jnc .turn_left              ; pit edge ahead -> turn around
    jmp .next_enemy

.turn_left:
    mov byte [si + EN_DIR], 1
    jmp .next_enemy

.despawn_enemy:
    mov byte [si + EN_TYPE], ENEMY_NONE

.next_enemy:
    add si, EN_SIZE
    dec cx
    jnz near .enemy_loop

.ue_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : EraseEnemies
; Purpose  : restores the 2x2 map tiles behind each visible
;            enemy before they move so they leave no trails
; ------------------------------------------------------------
EraseEnemies:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, enemies
    mov cx, MAX_ENEMIES
.ee_loop:
    cmp byte [si + EN_TYPE], ENEMY_NONE
    je near .ee_next

    ; Skip enemies outside visible camera
    mov ax, [si + EN_X]
    sub ax, [camera_x]
    cmp ax, -16
    jle near .ee_next
    cmp ax, SCREEN_W
    jge near .ee_next

    ; Redraw the 2x2 tiles around enemy's (EN_X, EN_Y - 16)
    push cx
    push si
    mov bx, [si + EN_X]
    shr bx, 4                   ; start col
    mov di, [si + EN_Y]
    sub di, 16
    shr di, 4                   ; start row
    cmp di, 1
    jge .ee_row_ok
    mov di, 1
.ee_row_ok:
    mov ch, 2                   ; 2 rows
.ee_r:
    cmp di, MAP_ROWS
    jge .ee_end_tile
    mov dx, di
    shl dx, 4                   ; screen Y

    push bx
    mov cl, 2                   ; 2 cols
.ee_c:
    cmp bx, MAP_COLS
    jge .ee_next_r

    ; tile index = row * 60 + col
    mov ax, di
    mov si, ax
    shl si, 6
    shl ax, 2
    sub si, ax
    add si, bx
    mov al, [map_working + si]

    push bx
    shl bx, 4
    sub bx, [prev_camera_x]     ; screen X using prev_camera_x
    call DrawTile
    pop bx

    inc bx
    dec cl
    jnz .ee_c
.ee_next_r:
    pop bx
    inc di
    dec ch
    jnz .ee_r

.ee_end_tile:
    pop si
    pop cx

.ee_next:
    add si, EN_SIZE
    dec cx
    jnz near .ee_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : DrawSimpleEnemies
; Purpose  : draws clean, outlined Goomba and Koopa sprites
;            using whole-pixel EN_X and EN_Y coordinates
; ------------------------------------------------------------
DrawSimpleEnemies:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov di, enemies
    mov cx, MAX_ENEMIES
.dse_loop:
    cmp byte [di + EN_TYPE], ENEMY_NONE
    je near .dse_next

    ; Compute screen X = EN_X - camera_x
    mov bx, [di + EN_X]
    sub bx, [camera_x]
    cmp bx, 0
    jl near .dse_next
    cmp bx, SCREEN_W - 16
    jg near .dse_next

    ; Compute screen top Y = EN_Y - 16
    mov dx, [di + EN_Y]
    sub dx, 16

    push cx
    cmp byte [di + EN_TYPE], ENEMY_KOOPA
    je .draw_koopa

    ; --- Outlined Goomba (brown mushroom cap + tan feet) ---
    add bx, 1
    add dx, 2
    mov cx, 14
    mov si, 14
    mov al, 0                   ; 1px black outline
    call DrawBox

    add bx, 1
    add dx, 1
    mov cx, 12
    mov si, 8
    mov al, COL_GROUND          ; brown head
    call DrawBox

    add dx, 8
    mov cx, 12
    mov si, 4
    mov al, 14                  ; yellow/tan feet
    call DrawBox
    jmp .dse_done_one

.draw_koopa:
    ; --- Outlined Koopa (green shell + yellow head/feet) ---
    add bx, 1
    add dx, 1
    mov cx, 14
    mov si, 15
    mov al, 0                   ; 1px black outline
    call DrawBox

    add bx, 1
    add dx, 1
    mov cx, 12
    mov si, 9
    mov al, COL_PIPE            ; green shell
    call DrawBox

    add dx, 9
    mov cx, 12
    mov si, 4
    mov al, 14                  ; yellow head & feet
    call DrawBox

.dse_done_one:
    pop cx

.dse_next:
    add di, EN_SIZE
    dec cx
    jnz near .dse_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret