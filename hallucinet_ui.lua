--[[
	hallucinet specific ui
]]
local ui = require("ui")
local hallucinet = require("hallucinet")

return function(w, h)

	local hallucinet_ui = {}

	--allocate the container
	hallucinet_ui.container = ui.container:new()

	--various callbacks

	local hidden = false
	function hallucinet_ui:toggle_hide()
		hidden = not hidden
	end

	function hallucinet_ui:update(dt)
		self.hallucinet:update(1/1000)
	end

	function hallucinet_ui:draw()
		self.hallucinet:draw(love.timer.getTime())
		if not hidden then
			self.container:layout():draw()
		end
	end

	function hallucinet_ui:pointer(event, x, y)
		if not hidden then
			self.container:pointer(event, x, y)
		else
			if event == "click" then
				self:toggle_hide()
			end
		end
	end

	function hallucinet_ui:key(event, k)
		if not hidden then
			self.container:key(event, k)
		end
		if event == "pressed" and k == "tab" then
			self:toggle_hide()
		end
	end

	function hallucinet_ui:resize(w, h)
		for i,v in ipairs(self.centre_elements) do
			if v.right_side then
				v.x = love.graphics.getWidth() - v.w
			end
			v.anchor.v = "centre"
			v.y = h * 0.5
			v:dirty()
		end
	end

	--vertically centred elements
	hallucinet_ui.centre_elements = {}

	--
	function hallucinet_ui:go()
		-- 	(start/stop rendering)
		self.hallucinet:init_storage()
	end

	--tray for just the go button that pops up when there's changes

	local right_side_tray = ui.tray:new(love.graphics.getWidth() - 84, h * 0.5, 84, 84)
	right_side_tray.right_side = true
	-- go button
	right_side_tray:add_child(
		ui.button:new("go!", 64, 64, function()
			hallucinet_ui:go()
		end)
	)
	--(append)
	hallucinet_ui.container:add_child(right_side_tray)
	table.insert(hallucinet_ui.centre_elements, right_side_tray)


	--tray for all the basic buttons

	local side_tray = ui.tray:new(0, h * 0.5, 84, 84)
	hallucinet_ui.container:add_child(side_tray)
	table.insert(hallucinet_ui.centre_elements, side_tray)

	--gather all the side tray definitions into here
	function add_side_button(asset, f)
		local b = ui.button:new(asset, 64, 64, function(self)
			self:hide_children(false, true)
			f(self)
		end)
		side_tray:add_child(b)
		return b
	end

	function add_popup_tray(asset, buttons)
		local b = add_side_button(asset, function(self)
			self:hide_children(false, true)
		end)

		local t = ui.tray:new(94, y, 84, 84)
		table.insert(hallucinet_ui.centre_elements, t)
		if buttons then
			for i,v in ipairs(buttons) do
				row:add_child(ui.button:new(v[1], 64, 64, v[2]))
			end
		end
		b:add_child(t)
		return t
	end

	--
	local function text_width_for_buttons(i)
		return 64 * i + 10 * (i - 1) - 20
	end

	--create sub-trays for use in callbacks

	-- "just give me more" button

	add_side_button("another!", function()
		local hn = hallucinet_ui.hallucinet
		--randomise settings (w / d / a)
		hn.network_width = love.math.random(2, 8) * 10
		hn.network_depth = love.math.random(3, 15)
		hn.output_arity = love.math.random(2, 9)
		--randomise init params (type, scale, bias)
		hn.init_type = love.math.random() < 0.5 and "normal" or "signed_uniform"
		hn.init_scale = 0.6 + math.pow(love.math.random(), 3) * 0.8
		hn.init_ignore_bias = love.math.random() < 0.5
		--generate new input

		--generate new net
		hn:init()
		--start as normal
		hallucinet_ui:go()
	end)

	function _set_static_fps(fps)
		hallucinet_ui.hallucinet.static_fps = fps
		hallucinet_ui.hallucinet:init_storage()
	end

	function _set_duration(duration)
		hallucinet_ui.hallucinet.static_duration = duration
		hallucinet_ui.hallucinet:init_storage()
	end

	function _set_dynamic_dt(dt)
		hallucinet_ui.hallucinet.dynamic_dt = dt
		hallucinet_ui.hallucinet:init_storage()
	end

	-- rendering quality/etc settings
	local rendering_trays = {
		ui.col:new():add_children({
			ui.text:new(nil, "framerate", text_width_for_buttons(3), "center"),
			ui.row:new():add_children({
				ui.button:new("10", 32, 32, function()
					_set_static_fps(10)
				end),
				ui.button:new("15", 32, 32, function()
					_set_static_fps(15)
				end),
				ui.button:new("20", 36, 32, function()
					_set_static_fps(20)
				end),
				ui.button:new("30", 36, 32, function()
					_set_static_fps(30)
				end),
				ui.button:new("60", 36, 32, function()
					_set_static_fps(60)
				end),
			}),
			ui.text:new(nil, "duration", text_width_for_buttons(3), "center"),
			ui.row:new():add_children({
				ui.button:new("3 s", 32, 32, function()
					_set_duration(3)
				end),
				ui.button:new("5 s", 32, 32, function()
					_set_duration(5)
				end),
				ui.button:new("10 s", 36, 32, function()
					_set_duration(10)
				end),
				ui.button:new("20 s", 36, 32, function()
					_set_duration(20)
				end),
				ui.button:new("30 s", 36, 32, function()
					_set_duration(30)
				end),
			}),
		}),
		ui.col:new():add_children({
			ui.text:new(nil, "duration in frames", text_width_for_buttons(3), "center"),
			ui.row:new():add_children({
				ui.button:new("50", 32, 32, function()
					_set_dynamic_dt(1/50)
				end),
				ui.button:new("100", 32, 32, function()
					_set_dynamic_dt(1/100)
				end),
				ui.button:new("250", 36, 32, function()
					_set_dynamic_dt(1/250)
				end),
				ui.button:new("500", 36, 32, function()
					_set_dynamic_dt(1/500)
				end),
				ui.button:new("1000", 36, 32, function()
					_set_dynamic_dt(1/1000)
				end),
			}),
		})
	}
	local function _show_rendering_tray(show_i)
		for i,v in ipairs(rendering_trays) do
			v:hide(i ~= show_i)
		end
	end
	_show_rendering_tray(1) --static by default

	local function _set_resolution(res)
		hallucinet_ui.hallucinet.canvas_resolution = res
		hallucinet_ui.hallucinet:init_storage()
	end

	add_popup_tray("render settings")
		:add_children({
			--render type
			ui.row:new():add_children(
			{
				ui.col:new():add_children({
					ui.text:new(nil, "mode", text_width_for_buttons(2), "center"),
					ui.row:new():add_children({
						ui.button:new("static", 64, 64, function()
							hallucinet_ui.hallucinet.mode = "static"
							hallucinet_ui.hallucinet.static_fps = 15
							hallucinet_ui.hallucinet.static_duration = 10
							hallucinet_ui.hallucinet:init_storage()
							_show_rendering_tray(1)
						end),
						ui.button:new("dynamic", 64, 64, function()
							hallucinet_ui.hallucinet.mode = "dynamic"
							hallucinet_ui.hallucinet.dynamic_dt_scale = 1/1000
							hallucinet_ui.hallucinet:init_storage()
							_show_rendering_tray(2)
						end),
					}),
					ui.row:new():add_children({
						ui.button:new("still", 64, 64, function()
							hallucinet_ui.hallucinet.mode = "static"
							hallucinet_ui.hallucinet.static_fps = 1
							hallucinet_ui.hallucinet.static_duration = 0.01
							hallucinet_ui.hallucinet:init_storage()
							_show_rendering_tray(nil)
						end),
					}),
				}),
				ui.col:new()
				:add_child(ui.text:new(nil, "options", text_width_for_buttons(3), "center"))
				:add_children(rendering_trays),
			}),
			-- 	render resolution
			ui.text:new(nil, "resolution", text_width_for_buttons(5), "center"),
			ui.row:new():add_children({
				ui.button:new("10%", 64, 32, function()
					_set_resolution(0.10)
				end),
				ui.button:new("25%", 64, 32, function()
					_set_resolution(0.25)
				end),
				ui.button:new("50%", 64, 32, function()
					_set_resolution(0.50)
				end),
				ui.button:new("100%", 64, 32, function()
					_set_resolution(1.00)
				end),
				ui.button:new("200%", 64, 32, function()
					_set_resolution(2.00)
				end),
			})
		})

	-- --saving to disk
	-- add_popup_tray("i/o")
	-- 	:add_children({
	-- 		ui.text:new(nil, "config", text_width_for_buttons(2), "center"),
	-- 		ui.row:new():add_children({
	-- 			ui.button:new("save", 64, 64, function()
	-- 			end),
	-- 			ui.button:new("load", 64, 64, function()
	-- 			end),
	-- 		}),
	-- 		ui.text:new(nil, "frames", text_width_for_buttons(2), "center"),
	-- 		ui.row:new():add_children({
	-- 			ui.button:new("save", 64, 64, function()
	-- 			end),
	-- 			ui.button:new("load", 64, 64, function()
	-- 			end),
	-- 		}),
	-- 	})

	-- --colour design
	-- add_popup_tray("colour")
	-- 	-- 	plain: rgb/hsv
	-- 	:add_child(ui.row:new()
	-- 		:add_child(ui.button:new("rgb", 64, 64, function()
	-- 			hallucinet_ui.hallucinet.unsplat_mode = "rgb_norm"
	-- 		end))
	-- 		:add_child(ui.button:new("hsv", 64, 64, function()
	-- 			hallucinet_ui.hallucinet.unsplat_mode = "hsv_norm"
	-- 		end))
	-- 	)
	-- 	:add_child(ui.row:new()
	-- 		:add_child(ui.button:new("colour", 64, 64, function()
	-- 		end))
	-- 		:add_child(ui.button:new("gradient", 64, 64, function()
	-- 		end))
	-- 	)

	-- --input design
	-- 	add/remove input generator
	-- 		basic:
	-- 			x, y
	-- 				scale
	-- 				symmetry x, y
	-- 			3 phase time
	-- 				scale
	-- 				freq
	-- 			shape
	-- 				generator
	-- 					scroll
	-- 					merge
	-- 					square
	-- 					circle
	-- 					spiral
	-- 				func
	-- 					bands
	-- 						single
	-- 						steep
	-- 						duty
	-- 					tri
	-- 					sin
	-- 				fade
	-- 					distance
	-- 					shape
	-- 					min
	-- 					max
	-- 				distort
	-- 					bend x
	-- 					bend y
	-- 					sin x
	-- 					sin y
	-- 			transform
	-- 				start + anim each
	-- 				translate
	-- 				rotate
	-- 				scale

	--todo: read generator_spec interactively here

	add_popup_tray("input")
		-- 	plain: rgb/hsv
		:add_child(ui.row:new()
			:add_children({
				ui.button:new("xy", 64, 64, function()
				end),
				ui.button:new("time", 64, 64, function()
				end),
				ui.button:new("shape", 64, 64, function()
				end),
			})
		)

	-- 		custom node graph later

	add_popup_tray("net")
		-- 	plain: rgb/hsv
		:add_child(ui.col:new()
			:add_children({
				ui.text:new(nil, "modify", text_width_for_buttons(4)),
				ui.row:new():add_children({
					ui.button:new("random", 64, 64, function()
					end),
					ui.button:new("smudge", 64, 64, function()
					end),
					ui.button:new("revert", 64, 64, function()
					end),
				}),
				ui.text:new(nil, "shape", text_width_for_buttons(4)),
				ui.row:new():add_children({
					ui.button:new("width", 64, 64, function()
					end),
					ui.button:new("depth", 64, 64, function()
					end),
					ui.button:new("arity", 64, 64, function()
					end),
				}),
				ui.text:new(nil, "init parameters", text_width_for_buttons(4)),
				ui.row:new():add_children({
					ui.button:new("type", 64, 64, function()
					end),
					ui.button:new("scale", 64, 64, function()
					end),
					ui.button:new("offset", 64, 64, function()
					end),
					ui.button:new("bias", 64, 64, function()
					end),
				}),
			})
		)

	-- --net design
	-- 	width
	-- 	depth
	-- 	init params
	-- 		gen type
	-- 		gen scale
	-- 		gen offset
	-- 		init bias
	-- 	output arity multiplier
	-- 	generate new
	-- 	modify weights

	-- --postprocess
	-- 	hueshift
	-- 		static
	-- 		animated
	-- 	dither
	-- 	posterise
	-- 	edge detect
	-- 	invert

	-- --random
	-- 	input configuration
	-- 	output configuration
	-- 	network
	-- 	everything

	add_side_button("hide", function(self)
		-- 	(hide ui
		hallucinet_ui:toggle_hide()
	end)

	-- --tutorial

	add_side_button("quit", function()
		love.event.quit()
	end)

	--hide all sub-trays
	for _, v in ipairs(side_tray.children) do
		v:hide_children(true)
	end

	--position everything
	hallucinet_ui:resize(w, h)

	--set up actual hallucinet
	hallucinet_ui.hallucinet = hallucinet:new()
	hallucinet_ui.hallucinet:init()

	return hallucinet_ui

end