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
