#!/bin/bash

#initial setup
rm -rf dist
rm deepsky.love
rm deepsky-win.zip
rm deepsky-osx.zip

#raw love2d file
cd ..
zip -r pack/deepsky.love *.lua src assets lib config
cd pack


#windows
mkdir dist
cat ./win/love.exe deepsky.love > dist/deepsky.exe
cp ./win/*.dll dist
cp ./win/license.txt dist/license_love2d.txt
cd dist
zip -r ../deepsky-win.zip .
cd ..
rm -rf dist
