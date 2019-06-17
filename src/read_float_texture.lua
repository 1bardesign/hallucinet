--[[
	read the values out of a 1 channel float texture

	todo: swap over to simply using a 1-channel imagedata with love 11.3
]]

local ffi = require("ffi")

local formats = {}
formats[16] = "rgba16f"
formats[32] = "rgba32f"

return function(tex, depth)
	--figure out the format to use
	depth = depth or 32
	local format = formats[depth]
	if not format then
		error("no matching format for depth "..depth)
	end

	--create storage
	local w, h = tex:getDimensions()
	local cv = love.graphics.newCanvas(w, h, {format=format})
	
	--do the draw
	love.graphics.push()
	love.graphics.setColor(1,1,1,1)
	love.graphics.setShader()
	love.graphics.setCanvas(cv)
	love.graphics.origin()
	love.graphics.draw(tex)
	love.graphics.pop()
	love.graphics.setCanvas()

	--pull out the data
	local data = cv:newImageData()
	local t = {}
	for y = 0, data:getHeight() - 1 do
		for x = 0, data:getWidth() - 1 do
			local r, g, b, a = data:getPixel(x, y)
			table.insert(t, r)
		end
	end
	return t, w, h
end