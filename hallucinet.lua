local network = require("nn_gpu")
local ffi = require("ffi")
require("splat")
require("shape_gen")

local input_template = [[
extern float time_scale;
extern float time_freq;

__CONSTANTS__

extern float t;

extern float aspect;

extern vec2 rect_o;
extern vec2 rect_size;

extern vec2 screen_size;

const float PI = 3.14159265358;
const float TAU = 2.0 * PI;

float triangle(float x) {
	x = fract(x);
	return 4.0 * min(x, 1.0 - x) - 1.0;
}

float bands(float x, float duty, float steep) {
	float s = (triangle(x) + (duty * 2.0 - 1.0)) * steep;
	return smoothstep(0.0, 1.0, clamp(s, -1.0, 1.0));
}

vec2 transform_point(vec2 p, vec2 offset, float rotation, vec2 scale) {
	float c = cos(-rotation);
	float s = sin(-rotation);
	//todo: optimise
	p -= offset;
	p /= scale;
	p = vec2(
		p.x * c - p.y * s,
		p.y * c + p.x * s
	);
	return p;
}

float get_input(vec2 px) {
	int input_stage = int(px.x);
	float e_x = (rect_o.x +   mod(px.y,  rect_size.x)) / screen_size.x;
	float e_y = (rect_o.y + floor(px.y / rect_size.x)) / screen_size.y;
	e_x = e_x * 2.0 - 1.0;
	e_y = e_y * 2.0 - 1.0;

	e_x *= aspect;

	__STAGES__

	return 1.0;
}

#ifdef PIXEL
vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
	float v = get_input(floor(screen_coords));
	return vec4(v, v, v, 1.0);
}
#endif
]]

local shape_template = [[
//get transformed position here
vec2 s_p = transform_point(
	vec2(e_x, e_y),
	vec2(shape_offset_x, shape_offset_y),
	(shape_rotation + t * anim_spins) * TAU,
	vec2(shape_scale_x, shape_scale_y)
);

//(unpack)
float s_x = s_p.x;
float s_y = s_p.y;

//mix animation curves
float st = sin(t * TAU);
float anim_var = 0;
anim_var += anim_amount_linear * (t);
anim_var += anim_amount_sin * (st * 0.5);
anim_var += anim_amount_sqsin * (st * st * sign(st) * 0.5);
anim_var += anim_amount_bounce * (abs(st) * 0.5);
anim_var += anim_amount_sqbounce * (st * st * 0.5);
anim_var += anim_amount_hesitant * (t + st * 0.2);
anim_var += anim_amount_tri * (triangle(t * 2.0));

float d = length(vec2(s_x, s_y));

//base shapes

float x = 0.0;
x += shape_amount_gradient * s_y;
x += shape_amount_wedge * abs(s_y);
x += shape_amount_curve * cos(s_y * PI * 0.5);
x += shape_amount_diamond * (abs(s_x) + abs(s_y));
x += shape_amount_square * max(abs(s_x), abs(s_y));
x += shape_amount_circle * d;

//fade in/out range
float fade_var = mix(
	d, //fade on distance
	x, //fade on surface
	range_var_balance
);
float fade = clamp(min(fade_var - min_range, max_range - fade_var) * fade_steep, 0.0, 1.0);

float v = (x + anim_var * anim_strength) * shape_freq;
if (bands_duty > 0.0 && bands_steep > 0.0) {
	v = bands(v, bands_duty, bands_steep);
} else if (use_sin > 0.0) {
	float v = sin(v * TAU);
}

return v * shape_strength * fade;
]]


local generator_templates = {
	xy = {
		{
			"scale",
		},
		{
			"e_x * scale",
			"e_y * scale",
		}
	},
	time = {
		{
			"time_freq",
			"time_offset",
			"time_scale",
		},
		{
			"sin((t * time_freq + time_offset) * TAU) * time_scale",
		}
	},
	time_triple = {
		{
			"time_scale",
		},
		{
			"sin((t + 1.0 / 3.0) * TAU) * time_scale",
			"sin((t + 2.0 / 3.0) * TAU) * time_scale",
			"sin((t + 3.0 / 3.0) * TAU) * time_scale",
		}
	},
	shape = {
		{
			--general shape args
			"shape_strength",
			"shape_freq",

			--overall curve args
			"bands_duty", -->0? bands mode
			"bands_steep", -->0? bands mode
			"use_sin", -->0? sin mode

			"shape_amount_gradient",
			"shape_amount_wedge",
			"shape_amount_curve",
			"shape_amount_diamond",
			"shape_amount_square",
			"shape_amount_circle",

			--animation args
			"anim_strength",
			"anim_amount_linear",
			"anim_amount_sin",
			"anim_amount_sqsin",
			"anim_amount_bounce",
			"anim_amount_sqbounce",
			"anim_amount_hesitant",
			"anim_amount_tri",

			--range args
			"range_var_balance", --1.0 = all shape, 0.0 = all distance
			"min_range",
			"max_range",
			"fade_steep",

			--transform anim args
			"anim_spins",
			"shape_rotation",
			"shape_offset_x",
			"shape_offset_y",
			"shape_scale_x",
			"shape_scale_y",
		},
		shape_template
	}
}

function input_shader_uniqueinputs(spec)
	local count = 0
	for _, v in ipairs(spec) do
		local name = v[1]
		local consts, outputs = unpack(generator_templates[name])
		if type(outputs) == "string" then
			count = count + 1
		else
			count = count + #outputs
		end
	end
	return count
end

function input_shader_source(spec)
	--const per-stage handling
	local const_block = {}
	local function const_name(const, i)
		return table.concat({const, "_", i})
	end
	local function add_const_block(name, value, i)
		table.insert(const_block, table.concat{"float ", const_name(name, i)," = ", string.format("%f", value),";"})
	end
	local function replace_consts(body, const_names, i)
		for _, name in ipairs(const_names) do
			body = body:gsub(name, const_name(name, i))
		end
		return body
	end

	--outputs handling
	local output_block = {}
	local _o_i = 0
	local function add_output_block(body)
		table.insert(output_block, table.concat{
			(_o_i == 0 and "" or "else "), "if (input_stage == ", _o_i, ") {\n\t\t", body, "\n\t}"
		})
		_o_i = _o_i + 1
	end

	for i, v in ipairs(spec) do
		local name, const_values = unpack(v)
		local template = generator_templates[name]
		if not template then
			error("missing generator template for "..name)
		end
		local const_names, outputs = unpack(template)
		--construct const block for generator
		for ci, cn in ipairs(const_names) do
			local cv = const_values[ci]
			add_const_block(cn, cv, i)
		end
		--construct output block for generator
		if type(outputs) == "string" then
			--verbatim block
			add_output_block(replace_consts(outputs:gsub("\n", "\n\t\t"), const_names, i))
		else
			--multiple return fragments
			for _, stage in ipairs(outputs) do
				add_output_block(table.concat{"return ", replace_consts(stage, const_names, i), ";"})
			end
		end
	end
	--template it in
	local src = input_template
	src = src:gsub("__CONSTANTS__", table.concat(const_block, "\n"))
	src = src:gsub("__STAGES__", table.concat(output_block, "\n\t"))
	return src
end

local hallucinet = {}
hallucinet._mt = {
	__index = hallucinet
}
function hallucinet:new(generator_spec)
	return setmetatable({
		frames = {},

		mode = "static",
		--static info
		static_fps = 15,
		static_duration = 10,
		static_render_progress = 0,
		--dynamic info
		dynamic_dt_scale = 0.001,
		dynamic_frametime = 1,
		--shared info
		render_time = 0,
		rendered = 0,
		last_start = nil,

		--input design
		input_generator_spec = generator_spec,

		--net init stuff
		unique_components = 9,
		output_arity = 3,
		network_width = 40,
		network_depth = 8,

		init_type = "normal",
		init_scale = 1.0,
		init_ignore_bias = false,

		--cv init stuff
		canvas_resolution = 1.0,
		canvas_format="srgba8", --"rgb565"

		unsplat_mode = "rgb_norm",

		done = false,
		current_iteration = 0,

		network = nil,

		input_shader = nil,
	}, hallucinet._mt)
end

function hallucinet:frame_count()
	return math.ceil(self.static_duration * self.static_fps)
end


function hallucinet:init()
	self:init_storage()
	self:init_net()
end

function hallucinet:init_storage()
	self.frames = {}
	self.current_iteration = 0
	self.rendered = 0
	self.done = false
	self.render_time = 0
	self.last_start = nil
	self.input_shader = love.graphics.newShader(
		input_shader_source(
			self.input_generator_spec
		)
	)
	self.dynamic_time = 0
	self.unique_components = input_shader_uniqueinputs(self.input_generator_spec)

	local frame_count =
		self.mode == "dynamic" and 2
		or self:frame_count()

	for i=1, frame_count do
		local cv = love.graphics.newCanvas(
			self.canvas_resolution * love.graphics.getWidth(),
			self.canvas_resolution * love.graphics.getHeight(),
			{ format = self.canvas_format }
		)
		--cv:setFilter("nearest", "nearest")
		table.insert(self.frames, cv)
	end
end

function hallucinet:init_net()
	self.network = network:new({
		input_size = self.unique_components,
		output_size = 3 * self.output_arity,
		width = self.network_width,
		depth = self.network_depth,

		--initialisation cfg
		initialise = {
			self.init_type,
			self.init_scale,
			self.init_ignore_bias
		},

		--activation function
		activation = network.activate.tanh,
	})
end

--todo: consider moving this inside object as well?
local iter_cost = 2 ^ 10

local chunk_update_total_h = 32
local chunk_update_split = 1 --must be integer into above
local chunk_update_h = chunk_update_total_h / chunk_update_split
local chunk_update_w = math.ceil(iter_cost / chunk_update_h)
local chunk_update_pixels = chunk_update_w * chunk_update_h
local cv_cache = {
	input = {},
	output = {},
}
local function get_cached_canvas(t, x, y, f)
	local id = table.concat{x, "_", y}
	local cv = cv_cache[t][id]
	if cv == nil then
		cv_cache[t][id] = f(x, y)
		return get_cached_canvas(t, x, y, f)
	end
	return cv
end

function hallucinet:render_slice(frame_cv, x, y, w, h, t)
	--only render this partial sample if we're in-frame
	local fw, fh = frame_cv:getDimensions()
	if y < fh then
		local input_cv = get_cached_canvas("input", self.unique_components, w * h, network.utility.create_canvas)
		local output_cv = get_cached_canvas("output", w, h, function(w, h)
			return love.graphics.newCanvas(
				w, h,
				{format = frame_cv:getFormat()}
			)
		end)

		--extract pixels for next area
		love.graphics.setCanvas(input_cv)
		love.graphics.setShader(self.input_shader)

		local function _send_if_exists(shader, name, v)
			if shader:hasUniform(name) then
				shader:send(name, v)
			end
		end

		_send_if_exists(self.input_shader, "screen_size", {fw, fh})
		_send_if_exists(self.input_shader, "aspect", fw / fh)

		_send_if_exists(self.input_shader, "t", t)

		_send_if_exists(self.input_shader, "rect_o", {x, y})
		_send_if_exists(self.input_shader, "rect_size", {w, h})

		--can trade-off here if shader incoherence is hurting throughput
		--but the more complicated draw itself is likely to hurt more
		local draw_mode = "single_rect"
		local iw, ih = input_cv:getDimensions()
		if draw_mode == "single_rect" then
			love.graphics.rectangle("fill", 0, 0, iw, ih)
		elseif draw_mode == "multi_rect" then
			for x = 0, iw - 1 do
				love.graphics.rectangle("fill", x, 0, 1, ih)
			end
		else
			error("bad input draw mode")
		end

		love.graphics.setShader()
		love.graphics.setCanvas()
		--run through net
		if self.use_1pass then
			self.network:feedforward_1pass(input_cv)
		else
			self.network:feedforward(input_cv)
		end
		--extract output
		local output = self.network:get_output()
		--un-splat output into this frame
		unsplat_into(self.unsplat_mode, output, output_cv)
		love.graphics.setCanvas(frame_cv)
		love.graphics.draw(
			output_cv,
			x, y,
			0,
			1, vs
		)
		love.graphics.setCanvas()
		--count
		self.rendered = self.rendered + 1
	end
end

function hallucinet:update_step()
	local frame_count = self:frame_count()

	local fw, fh = self.frames[1]:getDimensions()
	local fcw = math.ceil(fw / chunk_update_w)
	local fch = math.ceil(fh / chunk_update_total_h)
	local chunks_per_split = fcw * fch
	local total_chunks = chunks_per_split * chunk_update_split

	local function get_chunk_pos(chunk_i)
		local current_split = math.ceil((chunk_i + 1) / chunks_per_split) - 1
		local vs = 1
		if chunk_update_h == 1 then
			vs = chunk_update_total_h - current_split
		end

		local x = math.floor(chunk_i % fcw) * chunk_update_w
		local y = math.floor((chunk_i % chunks_per_split) / fcw) * chunk_update_total_h + current_split * chunk_update_h
		local w = math.min(x + chunk_update_w, fw) - x
		local h = math.min(y + chunk_update_h, fh) - y
		return x, y, w, h
	end

	--always render into frame 2
	if self.mode == "dynamic" then
		--get the frame and area within it to update
		local t = self.dynamic_time

		x, y, w, h = get_chunk_pos(self.current_iteration)

		local frame_cv = self.frames[2]
		self:render_slice(frame_cv, x, y, w, h, t)

		--iterate forward
		self.current_iteration = self.current_iteration + 1
		if (self.current_iteration / frame_count) > total_chunks then
			self.frames[2] = self.frames[1]
			self.frames[1] = frame_cv
			self.current_iteration = 0
			self.dynamic_time = (self.dynamic_time + self.dynamic_dt_scale) % 1

			local now = love.timer.getTime()
			self.dynamic_frametime = now - (self._dynamic_last_cycle or (now - 1))
			self._dynamic_last_cycle = now
		end
	end

	--render across the animation
	if self.mode == "static" then
		local frame = math.floor(self.current_iteration % frame_count) + 1
		local chunk_i = math.floor(self.current_iteration / frame_count)

		--get the frame and area within it to update
		local t = frame / frame_count

		x, y, w, h = get_chunk_pos(chunk_i)

		self:render_slice(self.frames[frame], x, y, w, h, t)

		--iterate forward
		self.current_iteration = self.current_iteration + 1
		if (self.current_iteration / frame_count) > total_chunks then
			self.done = true
		end
		self.static_render_progress = self.current_iteration / frame_count / total_chunks
	end
end

function hallucinet:update(t)
	if self.done then
		love.timer.sleep(t)
		return
	end

	local start = love.timer.getTime()
	if not self.last_start then
		self.last_start = start
	end
	self.render_time = self.render_time + (start - self.last_start)
	self.last_start = start

	while not self.done and love.timer.getTime() - start < t do
		self:update_step()
	end
end

function hallucinet:draw(t)
	local cv = self.frames[1]
	if self.mode == "static" then
		t = t / self.static_duration
		t = t % 1
		local f = math.max(1, math.min(self:frame_count(), math.floor(1 + t * self:frame_count())))
		cv = self.frames[f]
	end

	love.graphics.draw(
		cv,
		0, 0,
		0,
		love.graphics.getWidth() / cv:getWidth(),
		love.graphics.getHeight() / cv:getHeight()
	)

	if love.keyboard.isDown("`") then
		local lines
		if self.mode == "static" then
			lines = {
				{"progress: ", math.floor(self.static_render_progress * 100), "%" },
				{"time:     ", math.floor(self.render_time * 100) / 100, "s (", math.floor(self:frame_count() * self.static_render_progress / self.render_time * 100) / 100 ,"fps)"},
				{"eta:      ", math.max(0, math.floor(((1 / self.static_render_progress) - 1) * self.render_time)), "s"},
			}
		elseif self.mode == "dynamic" then
			lines = {
				{"fps:      ", math.floor((1.0 / self.dynamic_frametime) * 100) / 100 },
			}
		end
		table.insert(lines, {"ticks:    ", self.rendered})
		table.insert(lines, {"memory: ",
				math.ceil(collectgarbage("count")/1e3),"mb cpu ",
				math.ceil(love.graphics.getStats().texturememory/1e6)," mb gpu"
			}
		)
		for i,v in ipairs(lines) do
			love.graphics.print(
				v,
				10,
				10 + (i - 1) * 20
			)
		end
	end
end

--save and load (todo)
--[[
function save()
	local f = io.open("checkpoint", "wb")
	if f then
		f:write(g_net:serialise())
		f:close()
	end
end

function load()
	local f = io.open("checkpoint", "rb")
	if f then
		local s = f:read("*all")
		f:close()
		if s and s ~= "" then
			local loaded = nn:deserialise(s)
			if love.keyboard.isDown("lshift") then
				g_net = loaded
			else
				do_test(loaded)
			end
		end
	end
end
]]

return hallucinet