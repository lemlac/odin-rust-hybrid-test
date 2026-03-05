@echo off

:: Point this to where you installed emscripten.
set EMSCRIPTEN_SDK_DIR=C:\tools\emsdk
set OUT_DIR=build\web

if not exist %OUT_DIR% mkdir %OUT_DIR%

set EMSDK_QUIET=1
call %EMSCRIPTEN_SDK_DIR%\emsdk_env.bat
IF %ERRORLEVEL% NEQ 0 (
    echo Something went wrong
    exit /b 1
)

echo Building mymath (WASM)...
set RUST_TARGET=wasm32-unknown-unknown
cargo build ^
    --manifest-path="mymath/Cargo.toml" ^
    --target %RUST_TARGET%
IF %ERRORLEVEL% NEQ 0 (
    echo Something went wrong
    exit /b 1
)

pushd mymath\target\%RUST_TARGET%\debug
call emar x libmymath.a
IF %ERRORLEVEL% NEQ 0 (
    echo Something went wrong
    exit /b 1
)
popd

:: Note RAYLIB_WASM_LIB=env.o -- env.o is an internal WASM object file. You can
:: see how RAYLIB_WASM_LIB is used inside <odin>/vendor/raylib/raylib.odin.
::
:: The emcc call will be fed the actual raylib library file. That stuff will end
:: up in env.o
::
:: Note that there is a rayGUI equivalent: -define:RAYGUI_WASM_LIB=env.o
odin build source\main_web -target:js_wasm32 -build-mode:obj -define:RAYLIB_WASM_LIB=env.o -define:RAYGUI_WASM_LIB=env.o -vet -strict-style -out:%OUT_DIR%\game.wasm.o
IF %ERRORLEVEL% NEQ 0 (
    echo Something went wrong
    exit /b 5
)

for /f "delims=" %%i in ('odin root') do set "ODIN_PATH=%%i"
for /f "delims=" %%i in ('dir /b "mymath\target\%RUST_TARGET%\debug\*.o"') do set RUST_OBJ=mymath\target\%RUST_TARGET%\debug\%%i

set files="%OUT_DIR%\game.wasm.o" ^
    "%ODIN_PATH%\vendor\raylib\wasm\libraylib.a" ^
    "%ODIN_PATH%\vendor\raylib\wasm\libraygui.a" ^
    %RUST_OBJ%

:: index_template.html contains the javascript code that calls the procedures in
:: source/main_web/main_web.odin
set OPT_LEVEL=-Os
@REM set flags=%OPT_LEVEL% ^
@REM     -sUSE_GLFW=3 ^
@REM     -sWASM_BIGINT ^
@REM     -sEXPORT_ALL=1 ^
@REM     -Wl,--allow-multiple-definition ^
@REM     -sERROR_ON_UNDEFINED_SYMBOLS=0 ^
@REM     --shell-file source\main_web\index_template.html ^
@REM     --preload-file assets
set flags=-Os ^
    -sUSE_GLFW=3 ^
    -sWASM_BIGINT ^
    -sWARN_ON_UNDEFINED_SYMBOLS=0 ^
    -sASSERTIONS ^
    --shell-file source\main_web\index_template.html ^
    --preload-file assets

:: For debugging: Add `-g` to `emcc` (gives better error callstack in chrome)
::
:: This uses `cmd /c` to avoid emcc stealing the whole command prompt. Otherwise
:: it does not run the lines that follow it.
call emcc -o "%OUT_DIR%\index.html" %files% %flags%
IF %ERRORLEVEL% NEQ 0 (
    echo Something went wrong
    exit /b 1
)

del "%OUT_DIR%\game.wasm.o" 

echo Web build created in %OUT_DIR%