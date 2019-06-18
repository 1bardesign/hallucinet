for %%f in (*.png) do (
	C:\Users\Max\Desktop\bin\minor\pngquant.exe --ext=.png --force %%f
	C:\Users\Max\Desktop\bin\minor\truepng.exe %%f
)

pause