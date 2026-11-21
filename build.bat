@echo off
tools\nasm.exe -f bin src\mario.asm -o MARIO.COM
if errorlevel 1 (
    echo BUILD FAILED
) else (
    echo BUILD OK - MARIO.COM created
)
pause