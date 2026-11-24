# SOKiller

USB booteable (WinPE) que borra de forma desatendida la tabla de particiones del disco interno de un portátil y lo apaga. Pensado para dejar equipos de empresa limpios (sin Windows, usuarios ni datos de antiguos empleados) antes de reasignarlos.

> ## ⚠️ Aviso
> **Este script borra datos de forma irreversible.** Úsalo bajo tu propia responsabilidad y pruébalo siempre primero en equipos sin datos importantes. El autor no se hace responsable de pérdidas de datos, de borrar el disco equivocado ni de cualquier otro daño derivado de su uso.

## Cómo funciona

1. El equipo arranca desde el USB con una imagen WinPE (`boot.wim`).
2. WinPE ejecuta `startnet.cmd`, que está dentro del WIM.
3. `startnet.cmd` busca `borrar_todo.cmd` en todas las unidades (la letra del USB cambia según el equipo) y lo ejecuta con `call`.
4. `borrar_todo.cmd` carga los drivers de almacenamiento de `\Drivers\Disk`, comprueba que el disco objetivo no es un USB y lo limpia con `diskpart` (`clean` + `convert gpt`).
5. `startnet.cmd` apaga el equipo con `wpeutil shutdown`. No reinicia, para que no vuelva a arrancar del USB y repita el borrado.

## Contenido del repositorio

```
.
├── startnet.cmd          # Va DENTRO del boot.wim (Windows\System32\startnet.cmd)
├── borrar_todo.cmd       # Va en la raíz del USB
├── Drivers/Disk/         # Drivers .inf de almacenamiento (no incluidos)
├── .gitignore
├── .gitattributes
├── LICENSE
└── README.md
```

Estructura del USB una vez preparado:

```
USB (FAT32)
├── borrar_todo.cmd
├── Drivers\Disk\         <- drivers .inf (NVMe, RAID, Intel VMD/RST...)
└── sources\boot.wim      <- WinPE con startnet.cmd dentro
```

El repositorio **no incluye** el `boot.wim`, ISOs de Windows ni drivers: son de terceros y no se pueden redistribuir. Hay que generarlos o descargarlos (ver más abajo).

## Requisitos

- Un PC con Windows para preparar el USB.
- ISO oficial de Windows 10/11 (de ahí sale el `boot.wim`) o el Windows ADK con el complemento WinPE.
- [Rufus](https://rufus.ie) para crear el USB.
- Portátiles x64 (Intel/AMD).

## Preparar el USB

### 1. Crear el USB con Rufus

1. Abre Rufus y selecciona el USB y la ISO oficial de Windows.
2. Esquema de partición **GPT**, sistema de destino **UEFI** y sistema de archivos **FAT32**.
3. Crea el USB.

### 2. Preparar un boot.wim con startnet.cmd

Exporta el índice 1 (WinPE puro, sin el instalador de Windows) **marcándolo como arrancable**:

```bat
dism /Export-Image /SourceImageFile:D:\sources\boot.wim /SourceIndex:1 /DestinationImageFile:C:\boot_nuevo.wim /Bootable
dism /Mount-Wim /WimFile:C:\boot_nuevo.wim /Index:1 /MountDir:C:\mount
copy startnet.cmd C:\mount\Windows\System32\startnet.cmd
dism /Unmount-Wim /MountDir:C:\mount /Commit
```

(`D:` es el USB creado con Rufus y `C:\mount` una carpeta vacía.)

Copia `C:\boot_nuevo.wim` al USB como `sources\boot.wim`, sobrescribiendo el original (guarda antes una copia).

> Alternativa sin Rufus: crear el WinPE con el Windows ADK (`copype amd64` y `MakeWinPEMedia /UFD`, que formatea el USB). Después copia `startnet.cmd` al WIM como en el paso anterior.

### 3. Copiar los scripts y drivers

- Copia `borrar_todo.cmd` a la raíz del USB.
- Copia los drivers de almacenamiento (.inf) en `Drivers\Disk\` del USB. Los fabricantes los ofrecen en el pack de Intel RST/VMD, controladores NVMe, etc.

## Configuración

Al inicio de `borrar_todo.cmd`:

| Variable | Valor | Descripción |
|---|---|---|
| `DEBUG` | `1` | Muestra mensajes y pausas (para pruebas) |
| `DEBUG` | `0` | Modo desatendido, sin pausas |
| `TARGET_DISK` | `1` | Número del disco que se borrará |

Los `pause` de los mensajes de error se mantienen siempre, para ver el problema antes de que el equipo se apague.

## Uso

1. Con `DEBUG=1`, prueba en un portátil y revisa el `list disk` para confirmar que `TARGET_DISK` es el disco interno.
2. Cambia a `DEBUG=0` en el `borrar_todo.cmd` del USB (no hace falta tocar el WIM).
3. Conecta el USB, arranca desde él (F12 / F9 / Esc según la marca) y espera a que el equipo se apague solo.
4. **Quita el USB** antes de volver a encender, para que no repita el borrado.

Al encender un equipo ya limpio verás `Start PXE over IPv4/IPv6`: es normal (no hay nada que arrancar). Puedes desactivar el arranque por red en la BIOS.

## Seguridad integrada

- Si el disco objetivo aparece como USB en `detail disk`, el script aborta sin borrar nada.
- Si no encuentra la carpeta `Drivers\Disk`, el script aborta.

Aun así, **verifica siempre la numeración de discos** en cada modelo nuevo: no es la misma en todos los equipos.

## Problemas habituales

| Problema | Causa | Solución |
|---|---|---|
| Hay que abrir Shift+F10 y lanzar el script a mano | `startnet.cmd` no se ejecutaba: la imagen arrancada no era la modificada o arrancaba Windows Setup | Exportar solo el índice 1 y usarlo como `boot.wim` |
| El equipo se reiniciaba antes de borrar | `start cmd /k` no espera a que termine el script | Usar `call` |
| No se encuentra el script | La letra de unidad del USB cambia entre equipos | Buscar `borrar_todo.cmd` en todas las unidades |
| Error `winload.efi` al arrancar | Al exportar el índice 1 se perdió la marca de arrancable | Exportar con `/Bootable` |
| Vuelve a arrancar del USB y repite el borrado | `wpeutil reboot` con el USB puesto | Usar `wpeutil shutdown` |
| No aparece el disco en `list disk` | Falta el driver de almacenamiento (Intel VMD/RST, RAID) | Añadir el driver a `Drivers\Disk` o cambiar RAID a AHCI en la BIOS |

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

- El disco objetivo está fijado a `TARGET_DISK=1`. Mejora pendiente: elegir automáticamente el disco interno más grande que no sea USB.
- Si no existe `Drivers\Disk`, el script aborta. Mejora pendiente: avisar y continuar sin drivers.
- `clean` solo elimina la tabla de particiones; los datos siguen en el disco. Para un borrado más completo: `clean all` (lento) o Secure Erase del fabricante en SSD/NVMe.
- Probado en portátiles propios con un único disco interno; otros modelos pueden requerir ajustes.

## Licencia

[MIT](LICENSE)
