
require("hallucinet")
local ui = require("ui")

--startup
local g_ui
local centre_elements
local popups
function love.load()
	init_hallucinet()

	local font = love.graphics.getFont()

	--build ui
	g_ui = ui.container:new()

	centre_elements = {}
	popups = {}

	--create sub-trays for use in callbacks
	local function clear_popup()
		for i,v in ipairs(popups) do
			v:remove()
		end
	end

	local y = love.graphics.getHeight() * 0.5

	local first_menu = ui.tray:new(94, y, 84, 84)
		:add_child(ui.row:new(false)
			:add_child(ui.button:new(nil, 64, 64))
			:add_child(ui.button:new(nil, 64, 64))
		)
	table.insert(centre_elements, first_menu)
	table.insert(popups, first_menu)

	local second_menu = ui.tray:new(94, y, 84, 84)
		:add_child(ui.row:new(false)
			:add_child(ui.button:new(nil, 64, 64))
			:add_child(ui.button:new(nil, 64, 64))
		)
		:add_child(ui.row:new(false)
			:add_child(ui.button:new(nil, 64, 64))
			:add_child(ui.button:new(nil, 64, 64))
			:add_child(ui.button:new(nil, 64, 64))
		)
	table.insert(centre_elements, second_menu)
	table.insert(popups, second_menu)

	--create main side tray
	local side_tray = ui.tray:new(0, y, 84, 84)
		:add_child(ui.button:new(nil, 64, 64, function()
			clear_popup()
		end))
		:add_child(ui.button:new(nil, 64, 64, function()
			clear_popup()
			g_ui:add_child(first_menu)
		end))
		:add_child(ui.button:new(nil, 64, 64, function()
			clear_popup()
			g_ui:add_child(second_menu)
		end))
		:add_child(ui.button:new(nil, 64, 64, function()
			love.event.quit()
		end))
	side_tray.anchor.v = "center"

	for i,v in ipairs(centre_elements) do
		v.anchor.v = "center"
	end

	g_ui:add_child(side_tray)
end

function love.resize(w, h)
	for i,v in ipairs(centre_elements) do
		v.y = h * 0.5
	end
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
