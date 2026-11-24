@echo off
setlocal enabledelayedexpansion

rem 1 = muestra mensajes y pausas (pruebas) / 0 = desatendido
set "DEBUG=1"
set "TARGET_DISK=1"

echo === Buscando carpeta Drivers\Disk en unidades ===
set "DRIVER_ROOT="
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\Drivers\Disk" (
        echo [OK] Encontrada carpeta: %%D:\Drivers\Disk
        if not defined DRIVER_ROOT set "DRIVER_ROOT=%%D:\Drivers\Disk"
    )
)

if not defined DRIVER_ROOT (
    echo [ERROR] No se encontro ninguna carpeta \Drivers\Disk en ninguna unidad.
    pause
    goto :fin
)

echo.
echo === Cargando controladores desde %DRIVER_ROOT% ===
set /a COUNT_INF=0
for /r "%DRIVER_ROOT%" %%F in (*.inf) do (
    set /a COUNT_INF+=1
    echo [INF !COUNT_INF!] Cargando: "%%F"
    drvload "%%F"
    echo     -> Codigo de salida drvload: !errorlevel!
)
echo Total de archivos .inf procesados: !COUNT_INF!
if "%DEBUG%"=="0" pause

echo.
echo === Listado actual de discos ===
(
    echo list disk
) | diskpart
if "%DEBUG%"=="0" pause

rem --- Seguridad: abortar si el disco objetivo es un USB ---
(
    echo select disk %TARGET_DISK%
    echo detail disk
) > "%TEMP%\check.txt"
diskpart /s "%TEMP%\check.txt" > "%TEMP%\check_out.txt"
findstr /i "USB" "%TEMP%\check_out.txt" >nul
if !errorlevel! equ 0 (
    echo [ERROR] El disco %TARGET_DISK% parece ser un USB. Abortando.
    pause
    goto :fin
)

echo.
echo === Borrando disco %TARGET_DISK% ===
(
    echo select disk %TARGET_DISK%
    echo clean
    echo convert gpt
) > "%TEMP%\limpiar.txt"
diskpart /s "%TEMP%\limpiar.txt"
echo Codigo de salida diskpart: !errorlevel!
if "%DEBUG%"=="0" pause

:fin
endlocal