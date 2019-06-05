local network = require("nn_gpu")
local ffi = require("ffi")
require("splat")

local input_shader = love.graphics.newShader([[
extern float time_scale;
extern float time_freq;

extern vec2 pos_scale;

extern vec2 spin_scale;

extern float hole_scale;

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

float get_input(vec2 px) {
	float e_x = (rect_o.x +   mod(px.y,  rect_size.x)) / screen_size.x;
	float e_y = (rect_o.y + floor(px.y / rect_size.x)) / screen_size.y;
	e_x = e_x * 2.0 - 1.0;
	e_y = e_y * 2.0 - 1.0;

	e_x *= aspect;

	float st = sin(t * TAU);
	float ct = cos(t * TAU);

	if (px.x == 0) {
		return e_x * pos_scale.x;
	}
	if (px.x == 1) {
		return e_y * pos_scale.y;
	}
	if (px.x == 2) {
		return sin((t * time_freq + 1.0 / 3.0) * TAU) * time_scale;
	}
	if (px.x == 3) {
		return sin((t * time_freq + 2.0 / 3.0) * TAU) * time_scale;
	}
	if (px.x == 4) {
		return sin((t * time_freq + 3.0 / 3.0) * TAU) * time_scale;
	}
	if (px.x == 5) {
		return (e_x * ct - e_y * st) * spin_scale.x;
	}
	if (px.x == 6) {
		return (e_y * ct + e_x * st) * spin_scale.y;
	}
	if (px.x == 7) {
		return 1.0 - length(vec2(e_x, e_y) * hole_scale);
	}
	if (px.x == 8) {
		float spins = 0.0;
		float spin_offset = 0.0 * TAU;
		float st = spin_offset + t * TAU * spins;
		float s_x = e_x * cos(st) - e_y * sin(st);
		float s_y = e_y * cos(st) + e_x * sin(st);

		float anim_var = t; //linear
		//float anim_var = st * 0.5; //sin
		//float anim_var = st * st * sign(st) * 0.5; //sin2
		//float anim_var = abs(st) * 0.5; //bounce
		//float anim_var = st * st * 0.5; //bounce2
		//float anim_var = t + st * 0.2; //hesitant
		//float anim_var = triangle(t); //tri
		float anim_amount = -1.0;

		float d = length(vec2(e_x, e_y));

		//base shapes

		//float x = abs(s_y); //merge bands
		//float x = s_y; //scroll bands
		float x = abs(s_x) + abs(s_y); //diamond
		//float x = max(abs(s_x), abs(s_y)); //square
		//float x = d; //circle
		//float x = ((atan(s_y, s_x) / PI) + d * 0.2) * 3.0; //spiral

		//modifiers
		//x -= abs(s_x) * 0.5; //x bend
		//x += cos(s_x * TAU) * 0.1; //x wave
		//x += cos(s_y * TAU) * 0.1; //y wave
		//x += cos(d * TAU) * 0.1; //radial wave
		//x += d; //radial

		//general wave args
		float freq = 1.0;
		float scale = 0.1;

		//band args
		float duty = 0.25;
		float steep = 10.0;

		//fade in/out range
		float min_range = -2.0;
		float max_range = 2.0;
		float fade_steep = 0.5;
		float fade_var = x; //fade on surface
		//float fade_var = d; //fade on distance
		float fade = clamp(min(fade_var - min_range, max_range - fade_var) * fade_steep, 0.0, 1.0);

		float v = bands((x + anim_var * anim_amount) * freq, duty, steep); //bands
		//float v = sin((x + anim_var * anim_amount) * freq * TAU); //sin
		//float v = (x + anim_var * anim_amount) * freq; //linear
		return v * scale * fade;
	}
	return 1.0;
}

#ifdef PIXEL
vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
	float v = get_input(floor(screen_coords));
	return vec4(v, v, v, 1.0);
}
#endif
]])

local hallucinet = {}
hallucinet._mt = {
	__index = hallucinet
}
function hallucinet:new()
	return setmetatable({
		frames = {},
		fps = 30,
		duration = 0.01,

		mode = "static",

		pos_scale = 1.0,
		time_scale = 0.1,
		time_freq = 1.0,
		spin_scale = 0.2,
		hole_scale = 0.0,

		--net init stuff
		unique_components = 9,
		output_arity = 3,
		network_width = 30,
		network_depth = 8,

		init_type = "normal",
		init_scale = 1.0,
		init_ignore_bias = false,

		--cv init stuff
		canvas_resolution = 1.0,
		canvas_format="srgba8", --"rgb565"

		unsplat_mode = "rgb_norm",
		-- unsplat_mode = "hsv_norm",

		done = false,
		current_iteration = 0,
		render_progress = 0,
		rendered = 0,
		render_time = 0,
		last_start = nil,

		network = nil
	}, hallucinet._mt)
end

function hallucinet:frame_count()
	return math.ceil(self.duration * self.fps)
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

	for i=1, self:frame_count() do
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

	local frame_count = self:frame_count()

	while not self.done and love.timer.getTime() - start < t do
		local frame = math.floor(self.current_iteration % frame_count) + 1
		local chunk_i = math.floor(self.current_iteration / frame_count)

		local fw, fh = self.frames[frame]:getDimensions()
		local fcw = math.ceil(fw / chunk_update_w)
		local fch = math.ceil(fh / chunk_update_total_h)
		local chunks_per_split = fcw * fch
		local total_chunks = chunks_per_split * chunk_update_split

		local current_split = math.ceil((chunk_i + 1) / chunks_per_split) - 1

		local vs = 1
		if chunk_update_h == 1 then
			vs = chunk_update_total_h - current_split
		end
		--get the frame and area within it to update
		local x = math.floor(chunk_i % fcw) * chunk_update_w
		local y = math.floor((chunk_i % chunks_per_split) / fcw) * chunk_update_total_h + current_split * chunk_update_h
		local w = math.min(x + chunk_update_w, fw) - x
		local h = math.min(y + chunk_update_h, fh) - y

		--only render this partial sample if we're in-frame
		if y < fh then

			local frame_cv = self.frames[frame]

			local input_cv = get_cached_canvas("input", self.unique_components, w * h, network.utility.create_canvas)
			local output_cv = get_cached_canvas("output", w, h, function(w, h)
				return love.graphics.newCanvas(
					w, h,
					{format = frame_cv:getFormat()}
				)
			end)

			local area = {x + 0.5, y + 0.5, w, h}

			--extract pixels for next area
			love.graphics.setCanvas(input_cv)
			love.graphics.setShader(input_shader)

			local t = frame / frame_count

			input_shader:send("screen_size", {fw, fh})
			input_shader:send("aspect", fw / fh)

			input_shader:send("t", t)

			input_shader:send("time_freq", self.time_freq)
			input_shader:send("time_scale", self.time_scale)

			input_shader:send("pos_scale", {self.pos_scale, self.pos_scale})

			input_shader:send("spin_scale", {self.spin_scale, self.spin_scale})

			input_shader:send("hole_scale", self.hole_scale)

			input_shader:send("rect_o", {x, y})
			input_shader:send("rect_size", {w, h})

			--can trade-off here if shader incoherence is hurting throughput
			--but the more complicated draw itself is likely to hurt more
			local draw_mode = "multi_rect"
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

		--iterate forward
		self.current_iteration = self.current_iteration + 1
		if (self.current_iteration / frame_count) > total_chunks then
			self.done = true
		end
		self.render_progress = self.current_iteration / frame_count / total_chunks
	end
end

function hallucinet:draw(t)
	if not self.done then
		love.graphics.setColor(1,1,1,0.1)
	end
	t = t / self.duration
	t = t % 1
	local f = math.max(1, math.min(self:frame_count(), math.floor(1 + t * self:frame_count())))
	local cv = self.frames[f]

	love.graphics.draw(
		cv,
		0, 0,
		0,
		love.graphics.getWidth() / cv:getWidth(),
		love.graphics.getHeight() / cv:getHeight()
	)

	love.graphics.setColor(1,1,1,1)

	if not self.done or love.keyboard.isDown("tab") then
		for i,v in ipairs({
			{"progress: ", math.floor(self.render_progress * 100), "%" },
			{"ticks:    ", self.rendered},
			{"time:     ", math.floor(self.render_time * 100) / 100, "s (", math.floor(self:frame_count() * self.render_progress / self.render_time * 100) / 100 ,"fps)"},
			{"eta:      ", math.max(0, math.floor(((1 / self.render_progress) - 1) * self.render_time)), "s"},
			{"memory: ",
				math.ceil(collectgarbage("count")/1e3),"mb cpu ",
				math.ceil(love.graphics.getStats().texturememory/1e6)," mb gpu"
			},
		}) do
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