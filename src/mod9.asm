org 0x0100
jmp start

ACCEL       equ 0020h
FRICTION    equ 0010h
MAX_WALK    equ 0180h
MAX_RUN     equ 0280h
GRAVITY     equ 0040h
JUMP_VEL    equ 0FA80h
JUMP_CUTOFF equ 0FE00h
MAX_FALL    equ 0400h

mario_x: dw 0
mario_y: dw 0
vel_x: dw 0
vel_y: dw 0
on_ground: db 1
facing: db 1
form: db 0
hp: db 1
invuln_timer: db 0
stomp_chain: db 0
pose: db 0

key_right: db 0
key_left: db 0
key_jump: db 0
key_shift: db 0

start:
    mov byte [key_right], 1
    call UpdatePhysics
    call UpdatePhysics

    mov byte [key_right], 0
    call UpdatePhysics

    mov byte [key_jump], 1
    call UpdatePhysics

    mov byte [key_jump], 0
    call UpdatePhysics

    mov byte [key_jump], 1
    call UpdatePhysics

    mov ax, 4C00h
    int 21h

UpdatePhysics:
    push ax
    push bx
    push cx
    push dx

    mov al, [key_right]
    sub al, [key_left]
    cmp al, 1
    je .move_right
    cmp al, -1
    je .move_left
    jmp .apply_friction

.move_right:
    mov ax, [vel_x]
    add ax, ACCEL
    mov [vel_x], ax
    mov byte [facing], 1
    jmp .clamp_speed

.move_left:
    mov ax, [vel_x]
    sub ax, ACCEL
    mov [vel_x], ax
    mov byte [facing], 0
    jmp .clamp_speed

.apply_friction:
    mov ax, [vel_x]
    cmp ax, 0
    je .clamp_speed
    jg .fric_pos
    add ax, FRICTION
    cmp ax, 0
    jle .save_fric
    mov ax, 0
    jmp .save_fric
.fric_pos:
    sub ax, FRICTION
    cmp ax, 0
    jge .save_fric
    mov ax, 0
.save_fric:
    mov [vel_x], ax

.clamp_speed:
    cmp byte [key_shift], 1
    je .run_limit
    mov bx, MAX_WALK
    jmp .do_clamp
.run_limit:
    mov bx, MAX_RUN
.do_clamp:
    mov ax, [vel_x]
    cmp ax, bx
    jle .check_neg_limit
    mov ax, bx
    jmp .save_clamp
.check_neg_limit:
    neg bx
    cmp ax, bx
    jge .save_clamp
    mov ax, bx
.save_clamp:
    mov [vel_x], ax

.check_jump:
    cmp byte [key_jump], 1
    jne .check_cutoff
    cmp byte [on_ground], 1
    jne .check_cutoff
    mov word [vel_y], JUMP_VEL
    mov byte [on_ground], 0

.check_cutoff:
    cmp byte [key_jump], 0
    jne .apply_gravity
    mov ax, [vel_y]
    cmp ax, 0
    jge .apply_gravity
    cmp ax, JUMP_CUTOFF
    jle .apply_gravity
    mov word [vel_y], JUMP_CUTOFF

.apply_gravity:
    mov ax, [vel_y]
    add ax, GRAVITY
    cmp ax, MAX_FALL
    jle .save_grav
    mov ax, MAX_FALL
.save_grav:
    mov [vel_y], ax

.update_pos:
    mov ax, [vel_x]
    add [mario_x], ax
    mov ax, [vel_y]
    add [mario_y], ax

.check_ground:
    mov ax, [mario_y]
    cmp ax, 1000h
    jl .no_ground
    mov word [mario_y], 1000h
    mov word [vel_y], 0
    mov byte [on_ground], 1
.no_ground:

.update_pose:
    cmp byte [on_ground], 0
    je .pose_jump
    mov ax, [vel_x]
    cmp ax, 0
    je .pose_stand
    mov byte [pose], 2
    jmp .end_physics
.pose_jump:
    mov byte [pose], 3
    jmp .end_physics
.pose_stand:
    mov byte [pose], 1

.end_physics:
    pop dx
    pop cx
    pop bx
    pop ax
    ret