--[[
	hallucinet specific ui
]]
local ui = require("src.ui")
local network = require("src.nn_gpu")
local hallucinet = require("src.hallucinet")
require("src.shape_gen")
local create_textured_9slice_f = require("src.draw_textured_9slice")

local function new_textured_button(asset_or_text, w, h, callback, key)
	local b =  ui.button:new(asset_or_text, w, h, callback, key)
	b.rect_fn = create_textured_9slice_f(ui.base_9slice)
	return b
end

return function(w, h, is_screensaver)

	local hallucinet_ui = {}

	--allocate the container
	hallucinet_ui.container = ui.container:new()

	--todo: the parameters we need to watch for restarting/reinitialising nets
	local _net_specific = {}
	local _init_specific = {}

	local base_font = love.graphics.getFont()
	local heading_font = love.graphics.newFont(16)

	--various "special" buttons etc
	local fs_button

	--
	local started = false
	local title_blend = 1.0
	function hallucinet_ui:start()
		started = true
	end

	--various callbacks
	local hidden = false
	function hallucinet_ui:toggle_hide()
		hidden = not hidden
	end

	--per-frame
	function hallucinet_ui:update(dt)
		if not started then
			local tb = self.title_button
			tb.bg_v = math.min(tb.bg_v_max, tb.bg_v + dt)
			tb:set_colours(tb.bg_v)
		else
			title_blend = math.max(0, title_blend - dt * 3.0)
		end
		self.hallucinet:update(1/100)
	end

	function hallucinet_ui:draw()
		--cross blend amounts
		local pre_blend = title_blend
		local after_blend = 1.0 - pre_blend

		local pre_col = self.title_button.bg_v * 0.3
		local after_col = 0.5

		--clear
		love.graphics.clear(
			(title_blend * pre_col) + (after_blend * after_col),
			(title_blend * pre_col) + (after_blend * after_col),
			(title_blend * pre_col) + (after_blend * after_col),
			0
		)

		--draw title
		if pre_blend > 0 then
			love.graphics.setColor(1, 1, 1, pre_blend)
			hallucinet_ui.title:layout():draw()
		end

		--draw hnet and gfx
		if after_blend > 0 then
			love.graphics.setColor(1, 1, 1, after_blend)
			self.hallucinet:draw(love.timer.getTime())
			if not hidden then
				love.graphics.setColor(1, 1, 1, after_blend)
				self.container:layout():draw()
			end
		end
	end

	--events

	function hallucinet_ui:pointer(event, x, y)
		if not started then
			if event == "click" then
				self:start()
				--self.title:pointer(event, x, y) --do we need anything passed along?..
			end
			return
		end
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
		if not started then
			self.title:key(event, k)
			return
		end

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


	do
		local text_extra = 100
		local text_w = 334 + text_extra
		local text_total_pad = 40

		--set up the special start button + intro message
		local title_button = ui.button:new(love.graphics.newImage("assets/title.png"), 350, 350)
		title_button.rect_fn = create_textured_9slice_f(ui.base_9slice, 0)
		--
		title_button.bg_v = 0.25
		title_button.bg_v_max = 0.9
		title_button.bg_v_cols = {
			{"bg",       1.0},
			{"bg_hover", 1.0},
			{"fg",       1.0 / title_button.bg_v_max},
			{"fg_hover", 1.0 / title_button.bg_v_max},
		}
		function title_button:set_colours(c)
			for i,v in ipairs(self.bg_v_cols) do
				local n, am = v[1], v[2]
				self:set_colour(
					n,
					math.min(1.0, c * am),
					math.min(1.0, c * am),
					math.min(1.0, c * am),
					1.0
				)
			end
		end
		title_button:set_colours(title_button.bg_v)
		hallucinet_ui.title_button = title_button

		hallucinet_ui.title = ui.tray:new(0, 0, text_w + text_total_pad, 400):add_children({
			ui.row:new():add_children({
				ui.button:new(nil, text_extra / 2 - 10, 0):set_visible("bg", false),
				title_button,
			}),
			ui.button:new(nil, 0, 32):set_visible("bg", false),
			ui.col:new(true):add_children({
				ui.text:new(base_font, "Hallucinet contains some flashing visuals.\nIt is not recommended for photosensitive individuals.", text_w, "center"),
				ui.text:new(base_font, "Click anywhere to continue.", text_w, "center"),
			}),
		}):set_visible("bg", false)
		--tag as center
		hallucinet_ui.title.centre = true
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
				v.x = w - v.w
			elseif v.center or v.centre then
				v.x = (w - v.w) * 0.5
			end
			v.anchor.v = "centre"
			v.y = h * 0.5
			v:dirty()
		end
	end

	--vertically centred elements
	hallucinet_ui.centre_elements = {}
	table.insert(hallucinet_ui.centre_elements, hallucinet_ui.title)

	--tray for just generating new options

	local right_side_tray = ui.tray:new(love.graphics.getWidth() - 84, h * 0.5, 84, 84)
	right_side_tray.right_side = true
	hallucinet_ui.container:add_child(right_side_tray)
	table.insert(hallucinet_ui.centre_elements, right_side_tray)

	-- go button
	right_side_tray:add_children({
		new_textured_button("New\nNet", 64, 64, function()
			hallucinet_ui:new_net()
		end),
		new_textured_button("New\nInput", 64, 64, function()
			hallucinet_ui:new_input()
		end),
		new_textured_button("Surprise\nMe!", 64, 64, function()
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
		local b = new_textured_button(asset, 64, 64, function(self)
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
				row:add_child(new_textured_button(v[1], 64, 64, v[2]))
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
	local static_option_width = 42
	local static_option_height = 26
	local static_option_text_width = text_width_for_buttons(3)
	local function option_header_text(t)
		return ui.text:new(base_font, t, static_option_text_width, "center")
			:set_padding("v", 10)
			:set_height(static_option_height + 2)
	end

	--todo: move these to separate trays probably!
	local rendering_trays = {
		ui.col:new():add_children({
			option_header_text("Frame Rate"),
			ui.row:new():add_children({
				ui.button:new("10", 32, static_option_height, function()
					_set_static_fps(10)
				end),
				ui.button:new("15", 32, static_option_height, function()
					_set_static_fps(15)
				end),
				ui.button:new("20", 36, static_option_height, function()
					_set_static_fps(20)
				end),
				ui.button:new("30", 36, static_option_height, function()
					_set_static_fps(30)
				end),
				ui.button:new("60", 36, static_option_height, function()
					_set_static_fps(60)
				end),
			}),
			option_header_text("Duration"),
			ui.row:new():add_children({
				ui.button:new("3 s", 32, static_option_height, function()
					_set_duration(3)
				end),
				ui.button:new("5 s", 32, static_option_height, function()
					_set_duration(5)
				end),
				ui.button:new("10 s", 36, static_option_height, function()
					_set_duration(10)
				end),
				ui.button:new("20 s", 36, static_option_height, function()
					_set_duration(20)
				end),
				ui.button:new("30 s", 36, static_option_height, function()
					_set_duration(30)
				end),
			}),
		}),
		ui.col:new():add_children({
			option_header_text("Duration in Frames"),
			ui.row:new():add_children({
				ui.button:new("50", 32, static_option_height, function()
					_set_dynamic_dt(1/50)
				end),
				ui.button:new("100", 32, static_option_height, function()
					_set_dynamic_dt(1/100)
				end),
				ui.button:new("250", 36, static_option_height, function()
					_set_dynamic_dt(1/250)
				end),
				ui.button:new("500", 36, static_option_height, function()
					_set_dynamic_dt(1/500)
				end),
				ui.button:new("1000", 36, static_option_height, function()
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

	add_popup_tray("Render Settings")
		:add_children({
			--render type
			ui.row:new():add_children(
			{
				ui.col:new():add_children({
					ui.text:new(base_font, "Render Mode", text_width_for_buttons(2), "center"),
					ui.row:new():add_children({
						ui.button:new("Static", 64, 64, function()
							hallucinet_ui.hallucinet.mode = "static"
							hallucinet_ui.hallucinet.static_fps = 15
							hallucinet_ui.hallucinet.static_duration = 10
							hallucinet_ui.hallucinet:init_storage()
							_show_rendering_tray(1)
						end),
						ui.row:new():add_children({
							ui.button:new("Still", 64, 64, function()
								hallucinet_ui.hallucinet.mode = "static"
								hallucinet_ui.hallucinet.static_fps = 1
								hallucinet_ui.hallucinet.static_duration = 0.01
								hallucinet_ui.hallucinet:init_storage()
								_show_rendering_tray(nil)
							end),
						}),
					}),
					ui.button:new("Dynamic", 64, 64, function()
						hallucinet_ui.hallucinet.mode = "dynamic"
						hallucinet_ui.hallucinet.dynamic_dt_scale = 1/1000
						hallucinet_ui.hallucinet:init_storage()
						_show_rendering_tray(2)
					end),
				}),
				--ui.button:new(nil, 32, 32):set_visible("bg", false), --pad with fake button
				ui.col:new()
				:add_child(ui.text:new(base_font, "Mode Options", text_width_for_buttons(3), "center"))
				:add_children(rendering_trays),
			}),
			-- 	render resolution
			ui.text:new(base_font, "Resolution", text_width_for_buttons(5), "center"),
			ui.row:new():add_children({
				ui.button:new("10%", 64, static_option_height, function()
					_set_resolution(0.10)
				end),
				ui.button:new("25%", 64, static_option_height, function()
					_set_resolution(0.25)
				end),
				ui.button:new("50%", 64, static_option_height, function()
					_set_resolution(0.50)
				end),
				ui.button:new("100%", 64, static_option_height, function()
					_set_resolution(1.00)
				end),
				ui.button:new("200%", 64, static_option_height, function()
					_set_resolution(2.00)
				end),
			}),
		})

	-- --saving to disk
	-- add_popup_tray("i/o")
	-- 	:add_children({
	-- 		ui.text:new(base_font, "config", text_width_for_buttons(2), "center"),
	-- 		ui.row:new():add_children({
	-- 			ui.button:new("save", 64, 64, function()
	-- 			end),
	-- 			ui.button:new("load", 64, 64, function()
	-- 			end),
	-- 		}),
	-- 		ui.text:new(base_font, "frames", text_width_for_buttons(2), "center"),
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
	-- 			ui.text:new(base_font, "modify", text_width_for_buttons(4)),
	-- 			ui.row:new():add_children({
	-- 				ui.button:new("random", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("smudge", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("revert", 64, 64, function()
	-- 				end),
	-- 			}),
	-- 			ui.text:new(base_font, "shape", text_width_for_buttons(4)),
	-- 			ui.row:new():add_children({
	-- 				ui.button:new("width", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("depth", 64, 64, function()
	-- 				end),
	-- 				ui.button:new("arity", 64, 64, function()
	-- 				end),
	-- 			}),
	-- 			ui.text:new(base_font, "init parameters", text_width_for_buttons(4)),
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
	local tutorial_width = 796
	local function _tut_heading(t)
		return ui.text:new(heading_font, t, tutorial_width, "center")
			:set_visible("bg", true)
			:set_colour("bg", 0.1, 0.1, 0.1, 1.0)
			:set_colour("bg_hover", 0.1, 0.1, 0.1, 1.0)
	end
	local tut_col_w = tutorial_width / 3 - 20
	local function _col_tab(t, b)
		if t then t = ui.text:new(base_font, t, tut_col_w, "center"):set_padding("before", 0.5):set_height(16) end
		if b then b = ui.text:new(base_font, b, tut_col_w, "left") end
		local kids = t and {t, b} or {b}
		return ui.col:new():add_children(kids)
	end

	add_popup_tray("Tutorial")
		:add_children({
			_tut_heading("Render Settings"),

			ui.col:new():add_children({
				ui.row:new():add_children({
					_col_tab(
						"Static Mode",
						"Renders out all frames of a set framerate + duration animation ahead of time. this means it requires more memory for longer animations, but animates as smoothly as possible once it's done."
					),
					_col_tab(
						"Dynamic Mode",
						"Renders out a frame at a time, with a set time-step between frames. has a constant memory footprint. generally only good for very slow animations, very low resolutions, or very powerful machines."
					),
					_col_tab(
						"Still Mode",
						"Renders a still image - useful to get a good quick idea of the overall \"look\" of a setup, but does not animate at all."
					),
				}),
				ui.text:new(base_font, "Lower resolution will lead to faster renders at the expense of visual quality.\nThis can be useful for quickly \"exploring\", or for folks with weaker GPUs.", tutorial_width, "center"),
			}),

			_tut_heading("Generation Options"),
			ui.row:new():add_children({
				_col_tab(
					"New Net",
					"Generate a new network to process this input - changes the colours and texture of the image."
				),
				_col_tab(
					"New Input",
					"Generate a new input to feed to this network - changes the overall shape and animation, without changing the colour palette or amount of texture."
				),
				_col_tab(
					"Surprise Me",
					"Generate a new net and input combo, for a totally new image."
				),
			}),

			_tut_heading("Tips"),
			ui.row:new():add_children({
				_col_tab(nil, "Click outside the ui to collapse menus, or toggle the ui completely and get a better look at your hallucination!"),
				_col_tab(nil, "Final resolution is set by the window mode at the start of rendering - fullscreen first and then render for highest render quality."),
				_col_tab(nil, "Static/still mode don't use much gpu power once they're finished rendering, so they are probably more suitable if you're on battery."),
			}),
		})

	local about_width = 600
	add_popup_tray("About")
		:add_children({
			ui.text:new(heading_font, "Created by 1BarDesign", about_width, "center"),
			ui.row:new():add_children({
				ui.button:new("Updates on itch", (about_width / 3), 32, function()
					love.system.openURL("https://1bardesign.itch.io/hallucinet")
				end),
				ui.button:new("Twitter", (about_width / 3), 32, function()
					love.system.openURL("https://twitter.com/1bardesign")
				end),
				ui.button:new("About LÖVE", (about_width / 3), 32, function()
					love.system.openURL("https://love2d.org/")
				end),
			}),

			ui.text:new(heading_font, "About Hallucinet", about_width, "center"),

			ui.row:new():add_children({
				ui.text:new(base_font, "Inspiration", 100, "left"),
				ui.text:new(base_font,
					"Hallucinet was inspired by Tuan Le's work on generating still images with randomly initialised neural nets, "..
					"the Electric Sheep project, the shadertoy community, and the wider demoscene.",
					about_width - 100 - 30, "left"
				),
			}),
			ui.row:new():add_children({
				ui.text:new(base_font, "Implementation", 100, "left"),
				ui.text:new(base_font,
					"The project started its life as a browser app, but I quickly felt a standalone application would be better able to do the idea justice. "..
					"Fairly simple feedforward neural network code was built on top of LÖVE using GLSL shaders, and "..
					"a UI for setting render parameters and exploring the possibility space was added.",
					about_width - 100 - 30, "left"
				),
			}),
			ui.row:new():add_children({
				ui.text:new(base_font, "Possible Future Enhancements", 100, "left"),
				ui.text:new(base_font,
					table.concat({
						"- Network Save/Load functionality",
						"- Custom colour modes (additive colour channels, gradient maps)",
						"- Partial Net/Input Modifications (for exploring \"similar\" parameters)",
						"- Network Weight Editor",
						"- Real supersampling (better quality + lower memory requirements)",
						"- Streaming frames to/from disk (longer animations possible)",
						"- Camera controls (pan/zoom/animation)",
						"- More Optimisation",
					}, "\n"),
					about_width - 100 - 30, "left"
				),
			}),
			ui.button:new("Feedback Form - Leave your Thoughts, Feature Requests, and Bug Reports here!", about_width + 20, 32, function()
				love.system.openURL("https://forms.gle/hDU4227UYpoJUyvs9")
			end),
		})

	-- fs toggle
	fs_button = add_side_button("Fullscreen", function (self)
		local fs = love.window.getFullscreen()
		love.window.setFullscreen(not fs , "desktop")
		local nt = fs and "Fullscreen" or "Windowed"
		self.ui_button_text:setf(nt, self.w, "center")
	end)

	--image i/o
	local save_width = 370
	local save_txt_width = save_width - 20

	local function do_save(just_estimate_size)
		local hnf = hallucinet_ui.hallucinet.frames

		--figure out what to render
		local frames = hnf
		if mode == "dynamic" or mode == "static" then
			frames = {frames[1]}
		end

		--get the filename header
		local now = os.date("*t")
		now = string.format("%d-%02d-%02d %02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec)

		local size = 0

		for i,v in ipairs(frames) do
			if just_estimate_size then
				local bytes_per_pixel_estimate = 1.0; --post-compression pessimistic
				local size_est = v:getWidth() * v:getHeight() * bytes_per_pixel_estimate;
				size = size + size_est
			else
				local id = v:newImageData()
				local fd = id:encode("png")
				id:release() --done with image data

				size = size + fd:getSize()
				--get the filename
				local fn = now
				if #frames > 1 then
					fn = string.format("%s %05d", fn, i)
				end
				fn = fn .. ".png"

				--open + write the file
				local f = io.open(fn, "wb")
				if f then
					f:write(fd:getString())
					f:close() --done with file
				end
				--todo: check if we could get the string separately - seems likely?
				fd:release() --done with file data from here
			end

		end

		return size
	end

	add_popup_tray("Save")
		:add_children({
			ui.text:new(heading_font, "Save Images", save_txt_width, "center"),
			ui.text:new(base_font, "You can save out single frames in still or dynamic render mode, or entire animation sets in static render mode.", save_txt_width, "center"),
			ui.text:new(base_font, "Animations can eat a lot of disk space and take a long time to save. A single 1080p image will need 1-5 megabytes, with more detailed images being larger.\nEven the smallest static animation is 30 frames.\nYou've been warned!", save_txt_width, "center"),
			ui.text:new(base_font, "Images are saved at their rendered resolution. When making wallpapers, be sure to go fullscreen before rendering for highest quality.", save_txt_width, "center"),
			ui.text:new(base_font, "The files will end up wherever you ran hallucinet from, named for the date and time they were saved. Animation frames have a 5 digit numeric suffix.", save_txt_width, "center"),
			ui.button:new("Save", save_width, 32, function(self)
				do_save(false)
			end),
			ui.button:new("Estimate Size", save_width, 32, function(self)
				local size = do_save(true)
				self.ui_button_text:setf("Estimate: ~"..tostring(math.ceil(size/1e6)).."mb", self.w, "center")
			end),
		})

	-- exit
	add_side_button("Quit", function()
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

	--screensaver mode

	if is_screensaver then
		--setup still mode
		hallucinet_ui.hallucinet.mode = "static"
		hallucinet_ui.hallucinet.static_fps = 1
		hallucinet_ui.hallucinet.static_duration = 0.01
		--skip intro
		hallucinet_ui:start()
		title_blend = 0
		--go fullscreen
		fs_button:onclick()
		--hide ui
		hallucinet_ui:toggle_hide()
		--re-init
		hallucinet_ui.hallucinet:init_storage()
		--rebuild update
		local old_update = hallucinet_ui.update
		local cycle_time = 60 * 5 --every few minutes
		local cycle_timer = 0
		function hallucinet_ui:update(dt)
			old_update(self, dt)
			cycle_timer = cycle_timer + dt
			if cycle_timer > cycle_time then
				cycle_timer = cycle_timer - cycle_time
				self:new_net()
				self:new_input()
			end
		end
		--respond to key/mouse by exiting
		function hallucinet_ui:pointer()
			love.event.quit()
		end
		function hallucinet_ui:key()
			love.event.quit()
		end
		--todo: only flip once we're actually rendered
	end

	return hallucinet_ui

end