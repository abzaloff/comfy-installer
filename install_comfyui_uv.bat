@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

set "INSTALLER_DIR=%~dp0"
set "CUSTOM_NODES_LIST=%INSTALLER_DIR%custom_nodes.txt"
set "HAS_WINGET=0"

echo ==========================================
echo        ComfyUI UV Installer
echo ==========================================
echo.

choice /c YN /n /m "Do you really want to install ComfyUI into this folder? [Y/N] "
if errorlevel 2 (
    echo Installation cancelled.
    pause
    exit /b 0
)
echo.

call :detect_winget
if errorlevel 1 exit /b 1

call :ensure_git
if errorlevel 1 exit /b 1

call :ensure_uv
if errorlevel 1 exit /b 1

if exist ComfyUI (
    echo ERROR: Folder "ComfyUI" already exists.
    echo Remove it or run this installer from another folder.
    pause
    exit /b 1
)

if not exist "%CUSTOM_NODES_LIST%" (
    echo Creating custom_nodes.txt...
    (
    echo # One custom node git repository URL per line.
    echo # Empty lines and lines starting with # are ignored.
    ) > "%CUSTOM_NODES_LIST%"
)

echo Cloning ComfyUI...
git clone --depth 1 https://github.com/Comfy-Org/ComfyUI.git
if errorlevel 1 (
    echo ERROR: Failed to clone ComfyUI.
    pause
    exit /b 1
)

cd /d ComfyUI

echo.
echo Creating venv with UV...
uv venv venv --python 3.13 --seed --link-mode=copy
if errorlevel 1 (
    echo ERROR: Failed to create virtual environment.
    pause
    exit /b 1
)

echo.
echo Activating venv...
call venv\Scripts\activate.bat
if errorlevel 1 (
    echo ERROR: Failed to activate virtual environment.
    pause
    exit /b 1
)

echo.
echo Installing PyTorch CUDA 13.0...
uv pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130
if errorlevel 1 (
    echo ERROR: Failed to install PyTorch.
    pause
    exit /b 1
)

echo.
echo Installing ComfyUI requirements...
uv pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install ComfyUI requirements.
    pause
    exit /b 1
)

echo.
echo Installing ComfyUI-Manager custom node...
cd /d custom_nodes
git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager comfyui-manager
if errorlevel 1 (
    echo ERROR: Failed to clone ComfyUI-Manager.
    pause
    exit /b 1
)
cd /d ..

echo.
echo Installing ComfyUI-Manager requirements...
uv pip install -r custom_nodes\comfyui-manager\requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install ComfyUI-Manager requirements.
    pause
    exit /b 1
)

echo.
echo Installing matrix-nio...
uv pip install matrix-nio
if errorlevel 1 (
    echo ERROR: Failed to install matrix-nio.
    pause
    exit /b 1
)

echo.
echo Installing Triton Windows and SageAttention...
uv pip install triton-windows
if errorlevel 1 (
    echo ERROR: Failed to install triton-windows.
    pause
    exit /b 1
)

uv pip install sageattention
if errorlevel 1 (
    echo ERROR: Failed to install sageattention.
    pause
    exit /b 1
)

echo.
echo Installing manager requirements...
uv pip install -r manager_requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install manager requirements.
    pause
    exit /b 1
)

echo.
echo Configuring ComfyUI-Manager to use UV...
if not exist "user\__manager" mkdir "user\__manager"
if errorlevel 1 (
    echo ERROR: Failed to create ComfyUI-Manager configuration folder.
    pause
    exit /b 1
)
(
echo [default]
echo use_uv = True
) > "user\__manager\config.ini"
if errorlevel 1 (
    echo ERROR: Failed to configure ComfyUI-Manager.
    pause
    exit /b 1
)

echo.
echo Creating run_comfyui.bat...
(
echo @echo off
echo set "COMFY_DIR=%%~dp0ComfyUI"
echo if not exist "%%COMFY_DIR%%\main.py" ^(
echo     echo ERROR: ComfyUI was not found in "%%COMFY_DIR%%".
echo     pause
echo     exit /b 1
echo ^)
echo cd /d "%%COMFY_DIR%%"
echo.
echo start "" /B "venv\Scripts\python.exe" main.py --preview-method auto
echo.
echo echo Waiting for ComfyUI server...
echo.
echo :waitloop
echo powershell -Command "try { $r = Invoke-WebRequest -Uri http://127.0.0.1:8188 -UseBasicParsing -TimeoutSec 1; exit 0 } catch { exit 1 }"
echo if errorlevel 1 ^(
echo     timeout /t 1 /nobreak ^>nul
echo     goto waitloop
echo ^)
echo.
echo start "" http://127.0.0.1:8188
echo.
echo echo ComfyUI started.
echo pause
) > "%INSTALLER_DIR%run_comfyui.bat"

echo.
echo Creating update_comfyui.bat...
(
echo @echo off
echo set "COMFY_DIR=%%~dp0ComfyUI"
echo if not exist "%%COMFY_DIR%%\.git" ^(
echo     echo ERROR: ComfyUI git repository was not found in "%%COMFY_DIR%%".
echo     pause
echo     exit /b 1
echo ^)
echo cd /d "%%COMFY_DIR%%"
echo.
echo echo Updating ComfyUI...
echo git pull
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to update ComfyUI.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Done.
echo pause
) > "%INSTALLER_DIR%update_comfyui.bat"

echo.
echo Creating update_requirements.bat...
(
echo @echo off
echo set "COMFY_DIR=%%~dp0ComfyUI"
echo if not exist "%%COMFY_DIR%%\requirements.txt" ^(
echo     echo ERROR: ComfyUI was not found in "%%COMFY_DIR%%".
echo     pause
echo     exit /b 1
echo ^)
echo cd /d "%%COMFY_DIR%%"
echo.
echo call venv\Scripts\activate.bat
echo.
echo echo Installing all requirements...
echo uv pip install -r manager_requirements.txt -r requirements.txt
echo.
echo echo Done.
echo pause
) > "%INSTALLER_DIR%update_requirements.bat"

echo.
echo Creating venv_reinstall.bat...
(
echo @echo off
echo setlocal EnableExtensions
echo title ComfyUI Venv Reinstaller
echo set "COMFY_DIR=%%~dp0ComfyUI"
echo.
echo if not exist "%%COMFY_DIR%%\requirements.txt" ^(
echo     echo ERROR: ComfyUI was not found in "%%COMFY_DIR%%".
echo     pause
echo     exit /b 1
echo ^)
echo if not exist "%%COMFY_DIR%%\manager_requirements.txt" ^(
echo     echo ERROR: ComfyUI manager_requirements.txt was not found.
echo     pause
echo     exit /b 1
echo ^)
echo if not exist "%%COMFY_DIR%%\custom_nodes\comfyui-manager\requirements.txt" ^(
echo     echo ERROR: ComfyUI-Manager requirements.txt was not found.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo where uv ^>nul 2^>nul
echo if errorlevel 1 ^(
echo     echo ERROR: UV was not found in PATH.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo This will delete and recreate the ComfyUI venv folder.
echo choice /C YN /M "Do you really want to reinstall the venv? Y/N"
echo if errorlevel 2 exit /b 0
echo.
echo cd /d "%%COMFY_DIR%%"
echo if exist "venv" ^(
echo     echo Removing existing venv...
echo     rmdir /s /q "venv"
echo     if exist "venv" ^(
echo         echo ERROR: Failed to remove venv. Close ComfyUI and any terminal using it, then try again.
echo         pause
echo         exit /b 1
echo     ^)
echo ^)
echo.
echo echo Creating venv with UV...
echo uv venv venv --python 3.13 --seed --link-mode=copy
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to create virtual environment.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Activating venv...
echo call venv\Scripts\activate.bat
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to activate virtual environment.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Installing PyTorch CUDA 13.0...
echo uv pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to install PyTorch.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Installing ComfyUI requirements...
echo uv pip install -r requirements.txt
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to install ComfyUI requirements.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Installing ComfyUI-Manager requirements...
echo uv pip install -r custom_nodes\comfyui-manager\requirements.txt
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to install ComfyUI-Manager requirements.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Installing matrix-nio...
echo uv pip install matrix-nio
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to install matrix-nio.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Installing Triton Windows and SageAttention...
echo uv pip install triton-windows
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to install triton-windows.
echo     pause
echo     exit /b 1
echo ^)
echo uv pip install sageattention
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to install sageattention.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Installing manager requirements...
echo uv pip install -r manager_requirements.txt
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to install manager requirements.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo echo Venv reinstalled successfully.
echo pause
echo exit /b 0
) > "%INSTALLER_DIR%venv_reinstall.bat"

echo.
echo Creating install_dependency.bat...
(
echo @echo off
echo title ComfyUI Dependency Installer
echo set "COMFY_DIR=%%~dp0ComfyUI"
echo if not exist "%%COMFY_DIR%%\venv\Scripts\activate.bat" ^(
echo     echo ERROR: ComfyUI venv was not found in "%%COMFY_DIR%%".
echo     pause
echo     exit /b 1
echo ^)
echo cd /d "%%COMFY_DIR%%"
echo.
echo call venv\Scripts\activate.bat
echo.
echo :menu
echo cls
echo echo ==========================================
echo echo      ComfyUI Dependency Installer
echo echo ==========================================
echo echo.
echo set /p PACKAGE=Enter package name ^(or exit^):
echo.
echo if /i "%%PACKAGE%%"=="exit" goto end
echo if "%%PACKAGE%%"=="" goto menu
echo.
echo echo.
echo echo Installing %%PACKAGE%%...
echo uv pip install %%PACKAGE%%
echo.
echo echo.
echo pause
echo goto menu
echo.
echo :end
) > "%INSTALLER_DIR%install_dependency.bat"

echo.
echo Creating install_custom_nodes.bat...
setlocal DisableDelayedExpansion
(
echo @echo off
echo chcp 65001 ^>nul
echo setlocal EnableExtensions EnableDelayedExpansion
echo set "INSTALLER_DIR=%%~dp0"
echo set "COMFY_DIR=%%INSTALLER_DIR%%ComfyUI"
echo set "CUSTOM_NODES_LIST=%%INSTALLER_DIR%%custom_nodes.txt"
echo.
echo if not exist "%%CUSTOM_NODES_LIST%%" ^(
echo     echo ERROR: custom_nodes.txt was not found next to this file.
echo     echo Add one custom node git repository URL per line and run again.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo if not exist "%%COMFY_DIR%%\venv\Scripts\activate.bat" ^(
echo     echo ERROR: ComfyUI venv was not found in "%%COMFY_DIR%%".
echo     pause
echo     exit /b 1
echo ^)
echo.
echo cd /d "%%COMFY_DIR%%"
echo.
echo call venv\Scripts\activate.bat
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to activate virtual environment.
echo     pause
echo     exit /b 1
echo ^)
echo.
echo if not exist custom_nodes mkdir custom_nodes
echo.
echo for /f "usebackq eol=# tokens=* delims=" %%%%U in ^("%%CUSTOM_NODES_LIST%%"^) do ^(
echo     call :InstallCustomNode "%%%%U"
echo     if errorlevel 1 ^(
echo         pause
echo         exit /b 1
echo     ^)
echo ^)
echo.
echo echo.
echo echo Custom nodes installation completed.
echo pause
echo exit /b 0
echo.
echo :InstallCustomNode
echo set "NODE_URL=%%~1"
echo for /f "tokens=* delims= " %%%%A in ^("!NODE_URL!"^) do set "NODE_URL=%%%%A"
echo if "!NODE_URL!"=="" exit /b 0
echo.
echo for %%%%A in ^("!NODE_URL!"^) do set "NODE_NAME=%%%%~nA"
echo if /i "!NODE_NAME:~-4!"==".git" set "NODE_NAME=!NODE_NAME:~0,-4!"
echo set "NODE_DIR=custom_nodes\!NODE_NAME!"
echo.
echo echo.
echo if exist "!NODE_DIR!\.git" ^(
echo     echo Updating !NODE_NAME!...
echo     git -C "!NODE_DIR!" pull --ff-only
echo ^) else if exist "!NODE_DIR!" ^(
echo     echo ERROR: "!NODE_DIR!" already exists but is not a git repository.
echo     exit /b 1
echo ^) else ^(
echo     echo Cloning !NODE_NAME!...
echo     git clone --depth 1 "!NODE_URL!" "!NODE_DIR!"
echo ^)
echo if errorlevel 1 ^(
echo     echo ERROR: Failed to clone or update !NODE_NAME!.
echo     exit /b 1
echo ^)
echo.
echo if exist "!NODE_DIR!\requirements.txt" ^(
echo     echo Installing requirements for !NODE_NAME!...
echo     uv pip install -r "!NODE_DIR!\requirements.txt"
echo     if errorlevel 1 ^(
echo         echo ERROR: Failed to install requirements for !NODE_NAME!.
echo         exit /b 1
echo     ^)
echo ^) else ^(
echo     echo No requirements.txt for !NODE_NAME!.
echo ^)
echo.
echo exit /b 0
) > "%INSTALLER_DIR%install_custom_nodes.bat"
endlocal

echo.
echo ==========================================
echo Installation completed successfully.
echo.
echo Created files:
echo   run_comfyui.bat
echo   update_comfyui.bat
echo   update_requirements.bat
echo   venv_reinstall.bat
echo   install_dependency.bat
echo   install_custom_nodes.bat
echo   custom_nodes.txt
echo ==========================================
echo.
echo Run run_comfyui.bat to start ComfyUI.
pause

exit /b 0

:detect_winget
where winget >nul 2>nul
if not errorlevel 1 (
    set "HAS_WINGET=1"
    echo winget found.
    exit /b 0
)

echo winget was not found.
echo.
echo You can install App Installer from Microsoft Store and then run this installer again:
echo https://apps.microsoft.com/detail/9nblggh4nns1
echo.
choice /C YN /M "Continue installation without winget? Y/N"
if errorlevel 2 (
    echo Installation cancelled.
    pause
    exit /b 1
)

echo Continuing without winget. The installer will use direct downloads as a fallback.
exit /b 0

:ensure_git
where git >nul 2>nul
if not errorlevel 1 (
    echo Git found.
    exit /b 0
)

if "%HAS_WINGET%"=="1" goto install_git_with_winget
goto install_git_direct

:install_git_with_winget
echo Git not found. Installing Git with winget...
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo ERROR: Git installation failed.
    pause
    exit /b 1
)
goto verify_git

:install_git_direct
echo Git not found. Downloading Git for Windows installer...
set "GIT_INSTALLER=%TEMP%\comfyui-git-installer.exe"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $page=(Invoke-WebRequest -UseBasicParsing -Uri 'https://git-scm.com/install/windows').Content; $match=[regex]::Match($page, 'https://github\.com/git-for-windows/git/releases/download/[^< ]+/Git-[^< ]+-64-bit\.exe'); if (-not $match.Success) { throw 'Git for Windows installer link was not found.' }; Invoke-WebRequest -UseBasicParsing -Uri $match.Value -OutFile '%GIT_INSTALLER%'"
if errorlevel 1 (
    echo ERROR: Git installer download failed.
    pause
    exit /b 1
)

if not exist "%GIT_INSTALLER%" (
    echo ERROR: Git installer was not downloaded.
    pause
    exit /b 1
)

echo Installing Git...
"%GIT_INSTALLER%" /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS
if errorlevel 1 (
    echo ERROR: Git installation failed.
    pause
    exit /b 1
)

:verify_git
call :refresh_path
where git >nul 2>nul
if errorlevel 1 (
    if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
)
where git >nul 2>nul
if errorlevel 1 (
    if exist "%ProgramFiles(x86)%\Git\cmd\git.exe" set "PATH=%ProgramFiles(x86)%\Git\cmd;%PATH%"
)
where git >nul 2>nul
if errorlevel 1 (
    echo ERROR: Git installation did not complete or git.exe is not available in PATH.
    echo Check your internet connection or install Git manually, then run this installer again.
    pause
    exit /b 1
)

echo Git installed.
exit /b 0

:ensure_uv
where uv >nul 2>nul
if not errorlevel 1 (
    echo UV found.
    exit /b 0
)

if "%HAS_WINGET%"=="1" goto install_uv_with_winget
goto install_uv_direct

:install_uv_with_winget
echo UV not found. Installing UV with winget...
winget install --id astral-sh.uv -e --source winget --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo ERROR: UV installation failed.
    pause
    exit /b 1
)
goto configure_uv_path

:install_uv_direct
echo UV not found. Installing UV from the official installer script...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-RestMethod -Uri 'https://astral.sh/uv/install.ps1' | Invoke-Expression"
if errorlevel 1 (
    echo ERROR: UV installation failed.
    pause
    exit /b 1
)

:configure_uv_path
set "UV_BIN=%USERPROFILE%\.local\bin"
call :add_user_path "%UV_BIN%"
call :refresh_path

where uv >nul 2>nul
if errorlevel 1 (
    if exist "%UV_BIN%\uv.exe" set "PATH=%UV_BIN%;%PATH%"
)

where uv >nul 2>nul
if errorlevel 1 (
    echo ERROR: UV installation did not complete or uv.exe is not available in PATH.
    echo Check your internet connection or install UV manually, then run this installer again.
    pause
    exit /b 1
)

echo UV installed.
exit /b 0

:add_user_path
set "PATH_TO_ADD=%~1"
if "%PATH_TO_ADD%"=="" exit /b 0

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=[Environment]::GetEnvironmentVariable('Path','User'); if ($null -eq $p) { $p='' }; $n='%PATH_TO_ADD%'; if (-not (($p -split ';') -contains $n)) { [Environment]::SetEnvironmentVariable('Path', (($p.TrimEnd(';') + ';' + $n).TrimStart(';')), 'User') }"
exit /b 0

:refresh_path
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%A"
exit /b 0
