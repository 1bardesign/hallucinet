
local ui

--startup
function love.load()
	local font = love.graphics.getFont()

	--build ui
	ui = require("src.hallucinet_ui")(love.graphics.getDimensions())
end

function love.resize(w, h)
	ui:resize(w, h)
end

--buttons
function love.keypressed(key, scan)
	if key == "q" then
		love.event.quit()
	end

	if key == "r" then
		if love.keyboard.isDown("lctrl") then
			love.event.quit("restart")
		else
			love.load()
		end
	end

	ui:key("pressed", key)
end

local is_clicked = false
function love.mousemoved( x, y, dx, dy, istouch )
	ui:pointer(is_clicked and "drag" or "move", x, y)
end

function love.mousepressed( x, y, button, istouch, presses )
	if button == 1 then
		ui:pointer("click", x, y)
		is_clicked = true
	end
end

function love.mousereleased( x, y, button, istouch, presses )
	if button == 1 then
		ui:pointer("release", x, y)
		is_clicked = false
	end
end

--update state
function love.update(dt)
	ui:update(dt)
end

function love.draw()
	ui:draw()
end
