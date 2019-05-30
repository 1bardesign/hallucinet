
require("hallucinet")

--startup
function love.load()
	init_hallucinet()
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

--update state
function love.update(dt)
	update_hallucinet(1/100)
end

function love.draw()
	love.graphics.clear(0.5,0.5,0.5,0)
	draw_hallucinet(love.timer.getTime())
end
