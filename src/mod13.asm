org 100h
jmp start

score_lo: dw 0
score_hi: dw 0
coins: db 0
lives: db 3
hp: db 1
time_left: dw 300
digit_buf: db 0,0,0,0,0,0,0,0
msg_score: db 'SCORE: $'
msg_coins: db ' COINS: $'
msg_lives: db ' LIVES: $'
msg_time: db ' TIME: $'
msg_hp: db ' HP: $'
msg_nl: db 13,10,'$'

start:
    mov word [score_lo], 0
    mov word [score_hi], 0
    mov ax, 100
    push ax
    call AddScore
    call PrintScore
    call PrintNewline

    mov word [score_lo], 4236h
    mov word [score_hi], 000Fh
    mov ax, 100
    push ax
    call AddScore
    call PrintScore
    call PrintNewline

    mov byte [coins], 99
    mov byte [lives], 3
    call AddCoin
    call PrintCoins
    call PrintLives
    call PrintNewline

    mov byte [coins], 99
    mov byte [lives], 99
    call AddCoin
    call PrintCoins
    call PrintLives
    call PrintNewline

    mov ax, 4C00h
    int 21h

AddScore:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx

    mov ax, [bp+4]
    add [score_lo], ax
    adc word [score_hi], 0

    mov ax, [score_hi]
    cmp ax, 0Fh
    ja .clamp
    jb .done
    mov ax, [score_lo]
    cmp ax, 423Fh
    jbe .done
.clamp:
    mov word [score_lo], 423Fh
    mov word [score_hi], 000Fh
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

AddCoin:
    push ax
    inc byte [coins]
    cmp byte [coins], 100
    jb .done
    mov byte [coins], 0
    cmp byte [lives], 99
    jae .done
    inc byte [lives]
.done:
    pop ax
    ret

AddLife:
    push ax
    cmp byte [lives], 99
    jae .done
    inc byte [lives]
.done:
    pop ax
    ret

SetHP:
    push bp
    mov bp, sp
    push ax
    mov al, [bp+4]
    cmp al, 1
    jb .invalid
    cmp al, 2
    ja .invalid
    mov [hp], al
.invalid:
    pop ax
    pop bp
    ret 2

DecrementTime:
    push ax
    cmp word [time_left], 0
    je .done
    dec word [time_left]
.done:
    pop ax
    ret

PrintScore:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov bx, [score_hi]
    mov cx, [score_lo]
    mov si, 0

    mov ax, bx
    or ax, cx
    jnz .div_loop
    mov si, 6
    jmp .print_zeros

.div_loop:
    mov ax, bx
    mov dx, 0
    mov di, 10
    div di
    mov bx, ax
    mov ax, cx
    div di
    mov cx, ax
    push dx
    inc si

    mov ax, bx
    or ax, cx
    jnz .div_loop

    cmp si, 6
    jae .print_digits
    mov ax, 6
    sub ax, si
    mov di, ax
.pad_loop:
    push 0
    inc si
    dec di
    jnz .pad_loop
    jmp .print_digits

.print_zeros:
    mov di, 6
.pz_loop:
    push 0
    dec di
    jnz .pz_loop

.print_digits:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    dec si
    jnz .print_digits

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

Print16Bit:
    push ax
    push bx
    push cx
    push dx

    mov cx, 0
    mov bx, 10
.div_loop:
    mov dx, 0
    div bx
    push dx
    inc cx
    cmp ax, 0
    jnz .div_loop

.print_loop:
    pop dx
    add dl, '0'
    mov ah, 02h
    int 21h
    loop .print_loop

    pop dx
    pop cx
    pop bx
    pop ax
    ret

PrintCoins:
    push ax
    push dx
    mov dx, msg_coins
    mov ah, 09h
    int 21h
    mov al, [coins]
    mov ah, 0
    call Print16Bit
    pop dx
    pop ax
    ret

PrintLives:
    push ax
    push dx
    mov dx, msg_lives
    mov ah, 09h
    int 21h
    mov al, [lives]
    mov ah, 0
    call Print16Bit
    pop dx
    pop ax
    ret

PrintTime:
    push ax
    push dx
    mov dx, msg_time
    mov ah, 09h
    int 21h
    mov ax, [time_left]
    call Print16Bit
    pop dx
    pop ax
    ret

PrintNewline:
    push ax
    push dx
    mov dx, msg_nl
    mov ah, 09h
    int 21h
    pop dx
    pop ax
    ret