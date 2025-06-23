@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo    注册表残留清理工具 v2.0
echo    专门清理卸载不干净的程序残留
echo ========================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [错误] 需要管理员权限运行此脚本！
    echo 请右键点击脚本，选择"以管理员身份运行"
    echo.
    pause
    exit /b 1
)

echo [提醒] 强烈建议在运行前备份注册表！
echo 按任意键继续，或 Ctrl+C 取消...
pause >nul
echo.

echo 开始扫描和清理注册表残留项...
echo.
set /a cleaned=0

REM ==========================================
REM 1. 清理无效的文件关联
REM ==========================================
echo [1/8] 清理无效的文件关联...
for /f "tokens=*" %%i in ('reg query "HKEY_CLASSES_ROOT" /s /k 2^>nul ^| findstr /E "\\shell\\open\\command$"') do (
    for /f "tokens=2*" %%a in ('reg query "%%i" /ve 2^>nul ^| findstr "REG_SZ REG_EXPAND_SZ"') do (
        set "cmdline=%%b"
        if defined cmdline (
            REM 去除引号并提取第一个参数（程序路径）
            set "cmdline=!cmdline:"=!"
            for /f "tokens=1" %%c in ("!cmdline!") do (
                set "exepath=%%c"
                REM 处理环境变量
                call set "exepath=!exepath!"
                if not exist "!exepath!" (
                    echo   删除无效关联: %%i
                    for /f "tokens=1-10 delims=\" %%d in ("%%i") do (
                        if "%%d"=="HKEY_CLASSES_ROOT" (
                            set "parentkey=%%d\%%e"
                            if "%%f" neq "" set "parentkey=!parentkey!\%%f"
                            reg delete "!parentkey!" /f >nul 2>&1
                            if !errorlevel! equ 0 set /a cleaned+=1
                        )
                    )
                )
            )
        )
    )
)

REM ==========================================
REM 2. 清理OpenWithList和OpenWithProgids中的无效项
REM ==========================================
echo [2/8] 清理文件扩展名关联中的无效项...
for /f "tokens=*" %%i in ('reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" /s 2^>nul ^| findstr "HKEY"') do (
    REM 清理OpenWithList
    for /f "tokens=1,2" %%a in ('reg query "%%i\OpenWithList" 2^>nul ^| findstr "REG_SZ"') do (
        set "appname=%%a"
        set "found=0"
        REM 在常见路径中查找应用程序
        if exist "%SystemRoot%\System32\!appname!" set "found=1"
        if exist "%ProgramFiles%\!appname!" set "found=1"
        if exist "%ProgramFiles(x86)%\!appname!" set "found=1"
        if exist "%LocalAppData%\Microsoft\WindowsApps\!appname!" set "found=1"
        
        if "!found!"=="0" (
            echo   删除OpenWithList无效项: !appname!
            reg delete "%%i\OpenWithList" /v "%%a" /f >nul 2>&1
            if !errorlevel! equ 0 set /a cleaned+=1
        )
    )
    
    REM 清理OpenWithProgids
    for /f "tokens=1" %%a in ('reg query "%%i\OpenWithProgids" 2^>nul ^| findstr "REG_NONE REG_SZ"') do (
        reg query "HKEY_CLASSES_ROOT\%%a" >nul 2>&1
        if !errorlevel! neq 0 (
            echo   删除OpenWithProgids无效项: %%a
            reg delete "%%i\OpenWithProgids" /v "%%a" /f >nul 2>&1
            if !errorlevel! equ 0 set /a cleaned+=1
        )
    )
)

REM ==========================================
REM 3. 清理Applications注册表项中的无效应用
REM ==========================================
echo [3/8] 清理Applications中的无效应用...
for /f "tokens=*" %%i in ('reg query "HKEY_CLASSES_ROOT\Applications" /s 2^>nul ^| findstr "\\shell\\open\\command$"') do (
    for /f "tokens=2*" %%a in ('reg query "%%i" /ve 2^>nul ^| findstr "REG_SZ REG_EXPAND_SZ"') do (
        set "apppath=%%b"
        if defined apppath (
            set "apppath=!apppath:"=!"
            for /f "tokens=1" %%c in ("!apppath!") do (
                set "exepath=%%c"
                call set "exepath=!exepath!"
                if not exist "!exepath!" (
                    for /f "tokens=1-3 delims=\" %%d in ("%%i") do (
                        if "%%d"=="HKEY_CLASSES_ROOT" if "%%e"=="Applications" (
                            echo   删除无效应用: %%f
                            reg delete "HKEY_CLASSES_ROOT\Applications\%%f" /f >nul 2>&1
                            if !errorlevel! equ 0 set /a cleaned+=1
                        )
                    )
                )
            )
        )
    )
)

REM ==========================================
REM 4. 清理右键菜单中的无效项
REM ==========================================
echo [4/8] 清理右键菜单无效项...
for /f "tokens=*" %%i in ('reg query "HKEY_CLASSES_ROOT\*\shell" /s 2^>nul ^| findstr "\\command$"') do (
    for /f "tokens=2*" %%a in ('reg query "%%i" /ve 2^>nul ^| findstr "REG_SZ REG_EXPAND_SZ"') do (
        set "cmdpath=%%b"
        if defined cmdpath (
            set "cmdpath=!cmdpath:"=!"
            for /f "tokens=1" %%c in ("!cmdpath!") do (
                set "exepath=%%c"
                call set "exepath=!exepath!"
                if not exist "!exepath!" (
                    for /f "tokens=1-5 delims=\" %%d in ("%%i") do (
                        if "%%d"=="HKEY_CLASSES_ROOT" if "%%e"=="*" if "%%f"=="shell" (
                            echo   删除无效右键菜单: %%g
                            reg delete "HKEY_CLASSES_ROOT\*\shell\%%g" /f >nul 2>&1
                            if !errorlevel! equ 0 set /a cleaned+=1
                        )
                    )
                )
            )
        )
    )
)

REM ==========================================
REM 5. 清理文件夹右键菜单中的无效项
REM ==========================================
echo [5/8] 清理文件夹右键菜单无效项...
for /f "tokens=*" %%i in ('reg query "HKEY_CLASSES_ROOT\Directory\shell" /s 2^>nul ^| findstr "\\command$"') do (
    for /f "tokens=2*" %%a in ('reg query "%%i" /ve 2^>nul ^| findstr "REG_SZ REG_EXPAND_SZ"') do (
        set "cmdpath=%%b"
        if defined cmdpath (
            set "cmdpath=!cmdpath:"=!"
            for /f "tokens=1" %%c in ("!cmdpath!") do (
                set "exepath=%%c"
                call set "exepath=!exepath!"
                if not exist "!exepath!" (
                    for /f "tokens=1-4 delims=\" %%d in ("%%i") do (
                        if "%%d"=="HKEY_CLASSES_ROOT" if "%%e"=="Directory" if "%%f"=="shell" (
                            echo   删除无效文件夹右键菜单: %%g
                            reg delete "HKEY_CLASSES_ROOT\Directory\shell\%%g" /f >nul 2>&1
                            if !errorlevel! equ 0 set /a cleaned+=1
                        )
                    )
                )
            )
        )
    )
)

REM ==========================================
REM 6. 清理MUICache中的无效项
REM ==========================================
echo [6/8] 清理MUICache中的无效项...
for /f "tokens=1,2,3*" %%a in ('reg query "HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" 2^>nul ^| findstr "REG_SZ"') do (
    set "filepath=%%a"
    if defined filepath (
        if not exist "!filepath!" (
            echo   删除MUICache无效项: !filepath!
            reg delete "HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" /v "!filepath!" /f >nul 2>&1
            if !errorlevel! equ 0 set /a cleaned+=1
        )
    )
)

REM ==========================================
REM 7. 清理ApplicationAssociationToasts中的无效项
REM ==========================================
echo [7/8] 清理应用关联提示中的无效项...
for /f "tokens=1,2,3*" %%a in ('reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" 2^>nul ^| findstr "REG_DWORD"') do (
    set "appname=%%a"
    echo !appname! | findstr /C:"Applications\" >nul
    if !errorlevel! equ 0 (
        for /f "tokens=2 delims=\" %%b in ("!appname!") do (
            set "found=0"
            if exist "%ProgramFiles%\%%b" set "found=1"
            if exist "%ProgramFiles(x86)%\%%b" set "found=1"
            if exist "%SystemRoot%\System32\%%b" set "found=1"
            if exist "%LocalAppData%\Microsoft\WindowsApps\%%b" set "found=1"
            
            if "!found!"=="0" (
                echo   删除无效关联提示: !appname!
                reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts" /v "!appname!" /f >nul 2>&1
                if !errorlevel! equ 0 set /a cleaned+=1
            )
        )
    )
)

REM ==========================================
REM 8. 清理卸载程序列表中的无效项
REM ==========================================
echo [8/8] 清理卸载程序列表中的无效项...
for /f "tokens=*" %%i in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s 2^>nul ^| findstr "HKEY"') do (
    for /f "tokens=2*" %%a in ('reg query "%%i" /v "UninstallString" 2^>nul ^| findstr "REG_SZ REG_EXPAND_SZ"') do (
        set "uninstallcmd=%%b"
        if defined uninstallcmd (
            set "uninstallcmd=!uninstallcmd:"=!"
            for /f "tokens=1" %%c in ("!uninstallcmd!") do (
                set "exepath=%%c"
                call set "exepath=!exepath!"
                if not exist "!exepath!" (
                    for /f "tokens=1-6 delims=\" %%d in ("%%i") do (
                        if "%%d"=="HKEY_LOCAL_MACHINE" (
                            echo   删除无效卸载项: %%h
                            reg delete "%%i" /f >nul 2>&1
                            if !errorlevel! equ 0 set /a cleaned+=1
                        )
                    )
                )
            )
        )
    )
)

REM 同样处理当前用户的卸载程序列表
for /f "tokens=*" %%i in ('reg query "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s 2^>nul ^| findstr "HKEY"') do (
    for /f "tokens=2*" %%a in ('reg query "%%i" /v "UninstallString" 2^>nul ^| findstr "REG_SZ REG_EXPAND_SZ"') do (
        set "uninstallcmd=%%b"
        if defined uninstallcmd (
            set "uninstallcmd=!uninstallcmd:"=!"
            for /f "tokens=1" %%c in ("!uninstallcmd!") do (
                set "exepath=%%c"
                call set "exepath=!exepath!"
                if not exist "!exepath!" (
                    for /f "tokens=1-6 delims=\" %%d in ("%%i") do (
                        if "%%d"=="HKEY_CURRENT_USER" (
                            echo   删除无效卸载项: %%h
                            reg delete "%%i" /f >nul 2>&1
                            if !errorlevel! equ 0 set /a cleaned+=1
                        )
                    )
                )
            )
        )
    )
)

echo.
echo ========================================
echo 清理完成！
echo 总共清理了 !cleaned! 个无效注册表项
echo ========================================
echo.
echo 建议现在重启计算机以使所有更改生效。
echo 如果遇到问题，请使用之前备份的注册表文件恢复。
echo.
pause