; ============================================================
; FILE: src/collision.asm
; Module 10: Mario-Enemy Collisions, Stomp/Hit & Flagpole Win
; ============================================================

; ------------------------------------------------------------
; Name     : CheckMarioEnemyCollisions
; Purpose  : checks overlap between Mario and active enemies:
;            - Stomping from above defeats enemy & bounces Mario
;            - Side hit shrinks Super Mario or kills Small Mario
; ------------------------------------------------------------
CheckMarioEnemyCollisions:
    push ax
    push bx
    push cx
    push dx
    push si

    cmp byte [game_state], STATE_PLAYING
    jne near .cmec_done

    ; Count down post-hit invulnerability frames if active
    cmp word [invuln_timer], 0
    je .scan_enemies
    dec word [invuln_timer]

.scan_enemies:
    mov si, enemies
    mov cx, MAX_ENEMIES
.col_loop:
    cmp byte [si + EN_TYPE], ENEMY_NONE
    je near .next_col

    ; Horizontal AABB check: |mario_x - enemy_x| < 12
    mov ax, [mario_x]
    sub ax, [si + EN_X]
    cmp ax, 12
    jge near .next_col
    cmp ax, -12
    jle near .next_col

    ; Vertical overlap check (mario_y = feet, enemy_y = feet)
    mov dx, [mario_y]
    shr dx, 8                   ; Mario feet Y
    mov bx, [si + EN_Y]         ; Enemy feet Y

    ; Mario feet must be below enemy head (enemy_y - 14)
    mov ax, bx
    sub ax, 14
    cmp dx, ax
    jl near .next_col

    ; Mario head must be above enemy feet
    mov ax, dx
    sub ax, SMALL_H
    cmp byte [form], 0
    je .chk_head
    sub ax, TILE_SIZE
.chk_head:
    cmp ax, bx
    jg near .next_col

    ; --- OVERLAP CONFIRMED! Check if Mario is stomping from above ---
    cmp word [mario_vy], 0
    jle .hurt_mario             ; moving upward or flat -> not a stomp
    mov ax, bx
    sub ax, 6                   ; top 6 pixels of enemy = stomp zone
    cmp dx, ax
    jg .hurt_mario              ; Mario's feet are too low -> side hit

    ; Stomp successful! Defeat enemy, bounce Mario, and award points
    mov byte [si + EN_TYPE], ENEMY_NONE
    mov word [mario_vy], STOMP_BOUNCE
    mov byte [on_ground], 0
    mov byte [pose], 2
    push si
    mov si, sfx_stomp
    call PlaySound
    pop si

    ; Award combo stomp points from stomp_points table
    push bx
    mov bl, [stomp_chain]
    cmp bl, STOMP_MAX - 1
    jbe .stomp_idx_ok
    mov bl, STOMP_MAX - 1
.stomp_idx_ok:
    xor bh, bh
    shl bx, 1
    mov ax, [stomp_points + bx]
    xor dx, dx
    call AddScore
    inc byte [stomp_chain]
    pop bx
    jmp .next_col

.hurt_mario:
    ; Ignore damage if Mario still has invulnerability safety frames
    cmp word [invuln_timer], 0
    jne .next_col

    ; If Super Mario, shrink back to Small Mario with safety frames
    cmp byte [form], 0
    je .fatal_hit
    mov byte [form], 0
    mov byte [hp], 1
    mov word [invuln_timer], INVULN_FRAMES
    push si
    mov si, sfx_hurt
    call PlaySound
    pop si
    jmp .next_col

.fatal_hit:
    call KillMario
    jmp .cmec_done

.next_col:
    add si, EN_SIZE
    dec cx
    jnz near .col_loop

.cmec_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------
; Name     : CheckFlagpoleWin
; Purpose  : checks if Mario reached the flagpole (TILE_FLAG)
;            and sets game_state = STATE_WIN
; ------------------------------------------------------------
CheckFlagpoleWin:
    push ax
    push bx
    push dx
    push si

    cmp byte [game_state], STATE_PLAYING
    jne .cfw_done

    mov bx, [mario_x]
    add bx, 8                   ; Mario horizontal center
    mov dx, [mario_y]
    shr dx, 8
    sub dx, 8                   ; Mario vertical center

    shr bx, 4                   ; map col
    shr dx, 4                   ; map row
    cmp bx, MAP_COLS
    jge .cfw_done
    cmp dx, MAP_ROWS
    jge .cfw_done

    ; index = row * 60 + col
    mov ax, dx
    mov dl, MAP_COLS
    mul dl
    add ax, bx
    mov bx, ax

    cmp byte [map_working + bx], TILE_FLAG
    jne .cfw_done

    ; Mario touched the flagpole -> award win bonus, play fanfare & set STATE_WIN
    mov ax, 2000
    xor dx, dx
    call AddScore
    mov si, sfx_win
    call PlaySound
    call AddTimeBonus
    mov byte [game_state], STATE_WIN

.cfw_done:
    pop si
    pop dx
    pop bx
    pop ax
    ret