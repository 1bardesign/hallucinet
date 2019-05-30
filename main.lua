
require("hallucinet")
local ui = require("ui")

--startup
local overlay_ui
function love.load()
	init_hallucinet()

	local font = love.graphics.getFont()

	overlay_ui = ui.base:new()
		:add_child(
			ui.tray:new(10, 10, 200, 100)
				-- :add_child(ui.text:new(font, "little text", 100, "center"))
				:add_child(ui.row:new(false)
					:add_child(ui.col:new(false)
						:add_child(ui.button:new(nil, 50, 50))
						:add_child(ui.button:new(nil, 50, 50))
					):add_child(ui.col:new(false)
						:add_child(ui.button:new(nil, 50, 50))
						:add_child(ui.row:new(false)
							:add_child(ui.button:new(nil, 50, 50))
							:add_child(ui.button:new(nil, 50, 50))
						)
						:add_child(ui.button:new(nil, 50, 50))
					):add_child(ui.col:new(false)
						:add_child(ui.button:new(nil, 50, 50))
						:add_child(ui.button:new(nil, 50, 50))
					)
				)
				:add_child(ui.text:new(font, "the grid above is currently made of explicit nested rows and columns, but it might be enough for my needs", 200, "center"))
		):add_child(
			ui.tray:new(400, 10, 100, 10)
				:add_child(ui.text:new(font, "another separate tray", 100, "center"))
		)
	overlay_ui.visible.bg = false
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

function love.mousemoved( x, y, dx, dy, istouch )
	overlay_ui:pointer(false, x, y)
end

function love.mousepressed( x, y, button, istouch, presses )
	overlay_ui:pointer(true, x, y)
end

--update state
function love.update(dt)
	update_hallucinet(1/100)
end

function love.draw()
	love.graphics.clear(0.5,0.5,0.5,0)
	draw_hallucinet(love.timer.getTime())
	overlay_ui:layout():draw()
end
