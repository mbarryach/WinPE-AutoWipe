# SOKiller
# USB booteable WinPE para borrar el disco de portátiles de empresa

USB que, al arrancar un portátil, ejecuta automáticamente un script que borra la tabla de particiones del disco interno (Windows, usuarios y datos de antiguos empleados) y apaga el equipo. Pensado para dejar portátiles limpios antes de reasignarlos.

> **Aviso:** el script es destructivo y no tiene vuelta atrás. Pruébalo siempre primero en equipos sin datos.

## Cómo funciona

1. El equipo arranca desde el USB con una imagen WinPE (`boot.wim`).
2. WinPE ejecuta `startnet.cmd` (incluido dentro del WIM).
3. `startnet.cmd` busca `borrar_todo.cmd` en todas las unidades (la letra del USB cambia según el portátil) y lo ejecuta con `call`.
4. `borrar_todo.cmd` carga los drivers de almacenamiento de `\Drivers\Disk`, comprueba que el disco objetivo no es un USB y lo limpia con `diskpart` (`clean` + `convert gpt`).
5. `startnet.cmd` apaga el equipo con `wpeutil shutdown` (no reinicia, para que no vuelva a arrancar del USB y repita el borrado).

## Estructura

```
USB (FAT32)
├── borrar_todo.cmd        <- script de borrado (editable sin tocar el WIM)
├── Drivers\Disk\          <- drivers .inf de almacenamiento (NVMe, RAID, Intel VMD/RST...)
└── sources\boot.wim       <- WinPE con startnet.cmd dentro
```

`startnet.cmd` va dentro del WIM, en `Windows\System32\startnet.cmd`.

## Preparar la imagen

Exportar el índice 1 (WinPE puro, sin el instalador de Windows) **marcándolo como arrancable**:

```bat
dism /Export-Image /SourceImageFile:D:\sources\boot.wim /SourceIndex:1 /DestinationImageFile:C:\boot_nuevo.wim /Bootable
dism /Mount-Wim /WimFile:C:\boot_nuevo.wim /Index:1 /MountDir:C:\mount
copy startnet.cmd C:\mount\Windows\System32\startnet.cmd
dism /Unmount-Wim /MountDir:C:\mount /Commit
```

Después, copiar `boot_nuevo.wim` al USB como `sources\boot.wim` (guardando antes una copia del original).

Alternativa más limpia: crear el WinPE con el Windows ADK + complemento WinPE (`copype amd64` y `MakeWinPEMedia /UFD`, que formatea el USB).

## startnet.cmd

```bat
wpeinit
set "SCRIPT="
for %%D in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if exist "%%D:\borrar_todo.cmd" if not defined SCRIPT set "SCRIPT=%%D:\borrar_todo.cmd"
)
if defined SCRIPT (
    call "%SCRIPT%"
) else (
    echo [ERROR] No se encontro borrar_todo.cmd en ninguna unidad.
    pause
)
wpeutil shutdown
```

## borrar_todo.cmd

```bat
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
if "%DEBUG%"=="1" pause

echo.
echo === Listado actual de discos ===
(
    echo list disk
) | diskpart
if "%DEBUG%"=="1" pause

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
if "%DEBUG%"=="1" pause

:fin
endlocal
```

## Uso

1. Con `DEBUG=1`, probar en un portátil y revisar el `list disk` para confirmar que el disco objetivo es el correcto.
2. Cambiar a `DEBUG=0` en el `borrar_todo.cmd` del USB (no hace falta tocar el WIM).
3. Conectar el USB, arrancar (F12 / F9 / Esc según la marca) y esperar a que el equipo se apague solo.
4. **Quitar el USB** antes de volver a encender, para que no repita el borrado.

Al reiniciar sin sistema, el equipo mostrará `Start PXE over IPv4/IPv6`: es normal (no hay nada que arrancar). Se puede desactivar el arranque por red en la BIOS.

## Problemas encontrados y soluciones

| Problema | Causa | Solución |
|---|---|---|
| Hay que abrir Shift+F10 y lanzar el script a mano | `startnet.cmd` no se ejecutaba: la imagen arrancada no era la modificada o arrancaba Windows Setup | Exportar solo el índice 1 y usarlo como `boot.wim` |
| El equipo se reiniciaba antes de borrar | `start cmd /k` no espera a que termine el script | Usar `call` |
| El script no se encuentra | La letra de unidad del USB cambia entre equipos (y en WinPE el WIM es `X:`) | Buscar `borrar_todo.cmd` en todas las unidades |
| Error `winload.efi` al arrancar | Al exportar el índice 1 se perdió la marca de arrancable | Exportar con `/Bootable` |
| Vuelve a arrancar del USB y repite el borrado | `wpeutil reboot` con el USB puesto | Usar `wpeutil shutdown` |

## Compatibilidad

**Da igual el sistema que tuviera el portátil.** WinPE solo arranca desde el USB y `diskpart clean` elimina la tabla de particiones de cualquier disco, tenga Windows, Linux o varios sistemas. Los sistemas de archivos que Windows no entiende (ext4, btrfs...) no importan, porque el comando no los lee, y un disco cifrado con LUKS tampoco es problema.

Lo que limita es el hardware, no el sistema anterior:

| Equipo | ¿Sirve? |
|---|---|
| Portátiles x64 (Intel/AMD), cualquier marca | Sí |
| Mac con Apple Silicon (M1/M2/M3...) | No, no pueden arrancar WinPE. Se borran desde macOS (Utilidad de Discos o "Borrar contenidos y ajustes") |
| Mac Intel con chip T2 (aprox. 2018-2020) | Solo si se permite el arranque desde USB externo en el modo recuperación |
| Chromebooks y equipos ARM | No (los ARM necesitarían un WinPE arm64) |

Esta imagen solo ejecuta el script de borrado. Para instalar otro sistema (por ejemplo Linux) hace falta un USB distinto con su propio instalador o live.

## Limitaciones y mejoras pendientes

- Funciona en cualquier marca x64 (Dell, HP, Lenovo, Asus...). No sirve para equipos ARM (haría falta WinPE arm64).
- Algunos modelos necesitan drivers de almacenamiento (Intel VMD/RST, RAID) en `Drivers\Disk`.
- El disco objetivo está fijado a `TARGET_DISK=1`. Mejora pendiente: elegir automáticamente el disco interno más grande que no sea USB.
- Si no existe `Drivers\Disk`, el script aborta. Mejora pendiente: avisar y continuar sin drivers.
- `clean` solo elimina la tabla de particiones; los datos siguen en el disco. Para un borrado más completo: `clean all` (lento) o Secure Erase del fabricante en SSD/NVMe.
