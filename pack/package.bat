@echo off

call "..\config.bat"

::initial setup
rmdir /s /q dist
del "hallucinet.love"
del "hallucinet-win.zip"

::raw love2d file
call "%SZ_PATH%7z.exe" a -tzip "hallucinet.love" "..\*.lua" "..\src" "..\assets" "..\lib" "readme.md"

::windows
mkdir dist
copy /b "%LOVE_PATH%love.exe"+"hallucinet.love" "dist\hallucinet.exe"
copy "%LOVE_PATH%*.dll" "dist"
copy "%LOVE_PATH%license.txt" "dist\license_love2d.txt"
copy "..\readme.md" "dist\readme.md"
cd dist
call "%SZ_PATH%7z.exe" a -tzip "..\hallucinet-win.zip" .
cd ..
rmdir /s /q dist


::todo: osx/linux

::final sanity cleanup
rmdir /s /q dist

::todo: print out sizes of files?

pause