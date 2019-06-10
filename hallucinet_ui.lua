--[[
	hallucinet specific ui
]]
local ui = require("ui")
local network = require("nn_gpu")
local hallucinet = require("hallucinet")
require("shape_gen")

return function(w, h)

	local hallucinet_ui = {}

	--allocate the container
	hallucinet_ui.container = ui.container:new()

	--the things we need to watch for restarting nets
	local _net_specific = {

	}

	local _init_specific = {

	}

	--various "special" buttons etc
	local fs_button

	--various callbacks

	local hidden = false
	function hallucinet_ui:toggle_hide()
		hidden = not hidden
	end

	--per-frame

	function hallucinet_ui:update(dt)
		self.hallucinet:update(1/100)
	end

	function hallucinet_ui:draw()
		self.hallucinet:draw(love.timer.getTime())
		if not hidden then
			self.container:layout():draw()
		end
	end

	--events

	function hallucinet_ui:pointer(event, x, y)
		if not hidden then
			if not self.container:pointer(event, x, y) then
				--missed everything click?
				if event == "click" then
					local has_uncollapsed = nil
					for i,v in ipairs(self.centre_elements) do
						if v.left_side then
							for i,v in ipairs(v.children) do
								--iterate button's children
								for i,v in ipairs(v.children) do
									if not v.hidden then
										has_uncollapsed = v
										break
									end
								end
								if has_uncollapsed then
									break
								end
							end
						end
						if has_uncollapsed then
							break
						end
					end

					if has_uncollapsed then
						--collapse something
						has_uncollapsed:hide()
					else
						--or hide
						self:toggle_hide()
					end
				end
			end
		else
			--unhide on click
			if event == "click" then
				self:toggle_hide()
			end
		end
	end

	function hallucinet_ui:key(event, k)
		if not hidden then
			self.container:key(event, k)
		end
		if event == "pressed" then
			local alt_down = love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")
			if k == "tab" and not alt_down then
				self:toggle_hide()
			elseif k == "return" and alt_down then
				--toggle fullscreen
				fs_button:onclick()
			end
		end
	end

	-- net handling

	local function generate_spec_base()
		local function _hr()
			return 0.5 + love.math.random()
		end

		local function _random_quarter_turn(t)
			return shape_gen_transform(
				t,
				0, 0,
				(love.math.random(0, 3) / 4)
			)
		end

		local function _random_symmetry()
			local t = shape_gen_blank()
			if love.math.random() < 0.5 then
				shape_gen_set_wedge(t)
			else
				shape_gen_set_curve(t)
			end
			return _random_quarter_turn(t)
		end

		local function _spinning_grad()
			local t = shape_gen_set_gradient(shape_gen_blank(), _hr())
			shape_gen_anim_spins(t, love.math.random(-2, 2))
			return shape_gen_random_transform(t)
		end

		local possible_specs = {
			{
				{"time_triple", {_hr()}},
				{"time", {love.math.random(2, 4), _hr(), _hr()}},
				{"time", {1, _hr(), _hr()}},
				{"xy", {_hr()}},
			},
			{
				{"time_triple", {_hr()}},
				_spinning_grad(),
				_spinning_grad(),
				_spinning_grad(),
				_spinning_grad(),
			},
			{
				{"time_triple", {_hr()}},
				{"time", {love.math.random(1, 3), _hr(), _hr()}},
				_random_quarter_turn(shape_gen_set_gradient(shape_gen_blank())),
				_random_symmetry(),
				random_shape_gen(),
			},
			{
				{"time_triple", {_hr()}},
				{"time", {love.math.random(1, 3), _hr(), _hr()}},
				{"time", {1, _hr(), _hr()}},
				{"xy", {_hr()}},
				shape_gen_random_fade(
					shape_gen_anim_spins(
						shape_gen_anim(
							shape_gen_pattern_bands(
								shape_gen_random_shape(shape_gen_blank(
									_hr(),
									1 + love.math.random() * 2
								)), 0.1 + love.math.random() * 0.2
							), love.math.random(-3, 3), "linear"
						), love.math.random(-1, 1)
					)
				)
			},
		}

		return possible_specs[love.math.random(1, #possible_specs)]
	end


	--randomisation functions
	function hallucinet_ui:new_net()
		local hn = self.hallucinet
		--randomise settings (w / d / a)
		hn.network_width = love.math.random(3, 6) * 10
		hn.network_depth = love.math.random(5, 15)
		hn.output_arity = love.math.random(2, 4)
		--randomise init params (type, scale, bias)
		if love.math.random() < 0.5 then
			hn.init_type = "normal"
			hn.init_scale = 0.5 + love.math.random() * 0.4
		else
			hn.init_type = "signed_uniform"
			hn.init_scale = 0.9 + love.math.random() * 0.4
		end
		hn.init_ignore_bias = love.math.random() < 0.5

		--todo: need to switch the unpack mode here too
		-- hn.activation = love.math.random() < 0.5
		-- 	and network.activate.tanh
		-- 	or network.activate.lrelu

		self.hallucinet:init_net()
		self.hallucinet:init_storage()
	end

	function hallucinet_ui:new_input()
		self.hallucinet.input_generator_spec = generate_spec_base()
		self.hallucinet:init_storage()
	end

	function hallucinet_ui:go()
		-- 	(start/stop rendering)
		self.hallucinet:init_storage()
	end

	--

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

	--tray for just generating new options

	local right_side_tray = ui.tray:new(love.graphics.getWidth() - 84, h * 0.5, 84, 84)
	right_side_tray.right_side = true
	hallucinet_ui.container:add_child(right_side_tray)
	table.insert(hallucinet_ui.centre_elements, right_side_tray)

	-- go button
	right_side_tray:add_children({
		ui.button:new("new net", 64, 64, function()
			hallucinet_ui:new_net()
		end),
		ui.button:new("new input", 64, 64, function()
			hallucinet_ui:new_input()
		end),
		ui.button:new("surprise me", 64, 64, function()
			hallucinet_ui:new_net()
			hallucinet_ui:new_input()
		end),
	})


	--tray for all the basic buttons

	local side_tray = ui.tray:new(0, h * 0.5, 84, 84)
	side_tray.left_side = true
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

	-- add_popup_tray("input")
	-- 	-- 	plain: rgb/hsv
	-- 	:add_child(ui.row:new()
	-- 		:add_children({
	-- 			ui.button:new("xy", 64, 64, function()
	-- 			end),
	-- 			ui.button:new("time", 64, 64, function()
	-- 			end),
	-- 			ui.button:new("shape", 64, 64, function()
	-- 			end),
	-- 		})
	-- 	)

	-- 		custom node graph later

	-- add_popup_tray("net")
	-- 	-- 	plain: rgb/hsv
	-- 	:add_child(ui.col:new()
	-- 		:add_children({
	-- 			ui.text:new(nil, "modify", text_width_for_buttons(4)),
	-- 			ui.row:new():add_children({
	-- 				ui.button:new("random", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("smudge", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("revert", 64, 64, function()
	-- 				end),
	-- 			}),
	-- 			ui.text:new(nil, "shape", text_width_for_buttons(4)),
	-- 			ui.row:new():add_children({
	-- 				ui.button:new("width", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("depth", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("arity", 64, 64, function()
	-- 				end),
	-- 			}),
	-- 			ui.text:new(nil, "init parameters", text_width_for_buttons(4)),
	-- 			ui.row:new():add_children({
	-- 				ui.button:new("type", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("scale", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("offset", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("bias", 64, 64, function()
	-- 				end),
	-- 			}),
	-- 		})
	-- 	)

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

	-- tutorial
	local tutorial_width = 600
	add_popup_tray("tutorial")
		:add_children({
			ui.text:new(nil, "Render Settings", tutorial_width, "center"),
			ui.row:new():add_children({
				ui.text:new(nil, "Static Mode", 100, "left"),
				ui.text:new(nil,
					"Renders out all frames of a set framerate + duration animation ahead of time. this means it requires more memory for longer animations, but animates as smoothly as possible once it's done",
					tutorial_width - 100 - 30, "left"
				),
			}),
			ui.row:new():add_children({
				ui.text:new(nil, "Dynamic Mode", 100, "left"),
				ui.text:new(nil,
					"Renders out a frame at a time, with a set time-step between frames. has a constant memory footprint. generally only good for very slow animations, very low resolutions, or very powerful machines",
					tutorial_width - 100 - 30, "left"
				),
			}),
			ui.row:new():add_children({
				ui.text:new(nil, "Still Mode", 100, "left"),
				ui.text:new(nil,
					"Renders a still image - useful to get a good quick idea of the overall \"look\" of a setup, but does not animate at all",
					tutorial_width - 100 - 30, "left"
				),
			}),
			ui.text:new(nil, "Lower resolution will lead to faster renders at the expense of visual quality - can be useful for quickly exploring lots of different variations", tutorial_width, "left"),

			ui.text:new(nil, "Generation Options", tutorial_width, "center"),
			ui.row:new():add_children({
				ui.text:new(nil, "New Net", 100, "left"),
				ui.text:new(nil,
					"Generate a new network to process this input - changes the colours and texture of the image",
					tutorial_width - 100 - 30, "left"
				),
			}),
			ui.row:new():add_children({
				ui.text:new(nil, "New Input", 100, "left"),
				ui.text:new(nil,
					"Generate a new input to feed to this network - changes the overall shape and animation, without changing the colour palette or amount of texture",
					tutorial_width - 100 - 30, "left"
				),
			}),
			ui.row:new():add_children({
				ui.text:new(nil, "Surprise Me", 100, "left"),
				ui.text:new(nil,
					"Generate a new net and input combo, for a totally new image",
					tutorial_width - 100 - 30, "left"
				),
			}),

			ui.text:new(nil, "Tips", tutorial_width, "center"),
			ui.row:new():add_children({
				ui.text:new(nil, "Click outside the ui to collapse menus, or toggle the ui completely and get a better look at your hallucination!", tutorial_width / 3 - 20, "left"),
				ui.text:new(nil, "Final resolution is set by the window mode at the start of rendering - fullscreen first and then render for highest render quality", tutorial_width / 3 - 20, "left"),
				ui.text:new(nil, "Static/still mode don't use much gpu power once they're finished rendering, so they are probably more suitable if you're on battery!", tutorial_width / 3 - 20, "left"),
			}),
		})

	add_popup_tray("about")
		:add_children({
			ui.text:new(nil, "created by 1bardesign", tutorial_width, "center"),
			ui.row:new():add_children({
				ui.button:new("updates on itch", (tutorial_width / 3), 32, function()
					love.system.openURL("https://1bardesign.itch.io/hallucinet")
				end),
				ui.button:new("twitter", (tutorial_width / 3), 32, function()
					love.system.openURL("https://twitter.com/1bardesign")
				end),
				ui.button:new("about love2d", (tutorial_width / 3), 32, function()
					love.system.openURL("https://love2d.org/")
				end),
			}),
			ui.text:new(nil, "info", tutorial_width, "center"),
			ui.row:new():add_children({
				ui.text:new(nil, "Inspiration", 100, "left"),
				ui.text:new(nil,
					"Hallucinet was inspired by Tuan Le's work on generating still images with randomly initialised neural nets. "..
					"Inspiration was also taken from Inigo Quilez's techniques for analytical geometry in shaders.",
					tutorial_width - 100 - 30, "left"
				),
			}),
			ui.row:new():add_children({
				ui.text:new(nil, "Implementation", 100, "left"),
				ui.text:new(nil,
					"The project started in js/webGL, but I quickly felt a standalone app would be better able to do the idea justice."..
					"Feedforward neural network code was built on top of Love2D using GLSL shaders, and "..
					"a UI for exploring the possibility space was added.",
					tutorial_width - 100 - 30, "left"
				),
			}),
			ui.row:new():add_children({
				ui.text:new(nil, "Still to come", 100, "left"),
				ui.text:new(nil,
					table.concat({
						"- Save/Load functionality",
						"- Custom colour map modes (additive colour channels, gradient maps)",
						"- Partial Net/Input Modifications",
						"- Network Weight Editor",
						"- Real supersampling (better quality with lower memory requirements)",
						"- Streaming to/from disk (longer animations possible)",
						"- More Optimisation",
						"",
						"Get in touch if there's any features that would be useful to you!",
					}, "\n"),
					tutorial_width - 100 - 30, "left"
				),
			}),
		})

	-- fs toggle
	fs_button = add_side_button("fullscreen", function (self)
		local fs = love.window.getFullscreen()
		love.window.setFullscreen(not fs , "desktop")
		local nt = fs and "fullscreen" or "windowed"
		self.ui_button_text:setf(nt, self.w, "center")
	end)

	-- exit
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
	hallucinet_ui.hallucinet = hallucinet:new(generate_spec_base())
	hallucinet_ui.hallucinet:init()

	return hallucinet_ui

end