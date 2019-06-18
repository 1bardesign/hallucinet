#!/bin/bash

#initial setup
rm -rf dist
rm hallucinet.love
rm hallucinet-win.zip

#raw love2d file
cd ..
zip -r pack/hallucinet.love *.lua src assets lib config readme.md
cd pack

#windows
mkdir dist
cat ./win/love.exe hallucinet.love > dist/hallucinet.exe
cp ./win/*.dll dist
cp ./win/license.txt dist/license_love2d.txt
cp ../readme.md dist/readme.md
cd dist
zip -r ../hallucinet-win.zip .
cd ..
rm -rf dist
