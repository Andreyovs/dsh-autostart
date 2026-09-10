@echo off
rem ============================================================================
rem  Автозапуск DeepSeek Harness при входе в Windows.
rem
rem  WSL2-машина НЕ стартует сама при включении ПК — её будит первый вызов
rem  wsl.exe. Этот .bat кладётся в папку автозагрузки (Win+R: shell:startup)
rem  или в Планировщик заданий (действие: этот .bat, запуск "при входе в
rem  систему"). Он просто включает WSL-дистрибутив: дальше systemd и
rem  [boot] command= из /etc/wsl.conf сами поднимут dsh web.
rem
rem  VM остаётся живой после выхода wsl.exe, т.к. в /etc/wsl.conf стоит
rem  [boot] systemd=true.
rem ============================================================================
setlocal

rem Если в системе несколько WSL-дистрибутивов, укажите нужный:
rem   wsl.exe -d Ubuntu-24.04 --exec true
wsl.exe --exec true

exit /b 0
