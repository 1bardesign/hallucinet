
require("hallucinet")
local ui = require("ui")

--startup
local g_ui
local side_tray
local popup
function love.load()
	init_hallucinet()

	local font = love.graphics.getFont()

	side_tray = ui.tray:new(0, 0, 84, love.graphics.getHeight())
		:add_child(ui.button:new(nil, 64, 64))
		:add_child(ui.button:new(nil, 64, 64))
		:add_child(ui.button:new(nil, 64, 64))
		:add_child(ui.button:new(nil, 64, 64))

	popup = ui.tray:new(94, 10, 84, 84)
		:add_child(ui.row:new(false)
			:add_child(ui.button:new(nil, 64, 64))
			:add_child(ui.button:new(nil, 64, 64))
		)

	--collect to container
	g_ui = ui.container:new()
	for i,v in ipairs({
		side_tray, popup, 
	}) do
		g_ui:add_child(v)
	end
end

function love.resize(w, h)
	side_tray.h = h
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

	if key == "s" then
		save()
	end

	if key == "l" then
		load()
	end
end

local is_clicked = false
function love.mousemoved( x, y, dx, dy, istouch )
	g_ui:pointer(is_clicked and "drag" or "move", x, y)
end

function love.mousepressed( x, y, button, istouch, presses )
	if button == 1 then
		g_ui:pointer("click", x, y)
		is_clicked = true
	end
end

function love.mousereleased( x, y, button, istouch, presses )
	if button == 1 then
		g_ui:pointer("release", x, y)
		is_clicked = false
	end
end

--update state
function love.update(dt)
	update_hallucinet(1/100)
end

function love.draw()
	love.graphics.clear(0.5,0.5,0.5,0)
	draw_hallucinet(love.timer.getTime())
	g_ui:layout():draw()
end
