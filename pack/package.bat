@echo off

call "..\config.bat"

::initial setup
rmdir /s /q dist
del "deepsky.love"
del "deepsky-win.zip"
del "deepsky-osx.zip"

::raw love2d file
call "%SZ_PATH%7z.exe" a -tzip "deepsky.love" "..\*.lua" "..\src" "..\assets" "..\lib" "..\config"

::windows
mkdir dist
copy /b "%LOVE_PATH%love.exe"+"deepsky.love" "dist/deepsky.exe"
copy "%LOVE_PATH%*.dll" "dist"
copy "%LOVE_PATH%license.txt" "dist/license_love2d.txt"
cd dist
call "%SZ_PATH%7z.exe" a -tzip "../deepsky-win.zip" .
cd ..
rmdir /s /q dist

::osx (not working for now)

:: mkdir dist

:: cd dist
:: call "%SZ_PATH%7z.exe" x "../osx/love-11.1-macos.zip"
:: copy "../osx/Info.plist" "deepsky.app/Contents/Info.plist"
:: copy "../deepsky.love" "deepsky.app/Contents/Resources/deepsky.love"
:: call "%SZ_PATH%7z.exe" a -tzip -mtc=off -mx=0 "../deepsky-osx.zip" .
:: cd ..
:: rmdir /s /q dist

::final sanity cleanup
rmdir /s /q dist

::todo: print out sizes of files?

pause