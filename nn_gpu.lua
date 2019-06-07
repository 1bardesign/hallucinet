--[[
	neural network

	gpu-only implementation
]]

local json = require("json")
local read_float_texture = require("read_float_texture")

-------------------------------------------------------------------------------
--shared utility

local _1d_canvas_format = "r32f"
local function create_canvas(w, h)
	local cv = love.graphics.newCanvas(
		w, h,
		{format = _1d_canvas_format}
	)
	cv:setFilter("nearest", "nearest")
	cv:setWrap("clamp", "clamp")
	return cv
end

--reset the graphics state
local function _reset_gfx()
	love.graphics.setBlendMode("alpha", "alphamultiply")
	love.graphics.setCanvas()
	love.graphics.setShader()
	love.graphics.setColor(1,1,1,1)
end

-- convert table of numbers (or ffi array) into float texture
-- by rendering into it with points (todo: update to imagedata with love 11.3)
local function table_to_texture(values, w, h, start)
	w = w or #values
	h = h or math.ceil(#values / w)
	start = start or 1
	local cv = create_canvas(w, h)
	love.graphics.setCanvas(cv)
	love.graphics.origin()
	local o = 0.25 --fix pixel centre issue
	for pass = 1, 2 do
		if pass == 1 then
			love.graphics.setBlendMode("add")
		else
			love.graphics.setBlendMode("subtract")
		end
		for y = 0, h-1 do
			for x = 0, w-1 do
				local i = start + x + y * w
				local v = values[i]
				if pass == 2 then
					v = v * -1
				end
				v = math.max(0, v)
				while v > 0 do
					local p = math.min(v, 1)
					v = v - 1
					love.graphics.setColor(p,p,p,1)
					love.graphics.points(x + o, y + o)
				end
			end
		end
	end
	_reset_gfx()
	return cv
end

--convert to splattered float format
local function input_to_texture(from, args)
	local cv = create_canvas(args.input_size, args.arity)
	--todo: split out kernel, channels etc into input texture
	local i = 0

	return cv
end

-------------------------------------------------------------------------------
--individual layer type for neural network
local layer = {}
layer.__mt = {
	__index = layer,
}

function layer:new(args)
	local r = setmetatable({
		input_size = args.input_size,
		output_size = args.output_size,
		weights = {},
		textures = {},
	}, self.__mt)
	if args.weights then
		for i,v in ipairs(args.weights) do
			r.weights[i] = v
		end
	else
		local size = (r.input_size + 1) * r.output_size
		local init_cfg = args.initialise
		if not init_cfg then
			init_cfg = {
				"normal", 0.1, true
			}
		end
		local init_f, init_scale, init_bias_zero = unpack(init_cfg)
		for i = 1, size do
			local v = 0
			if
				init_bias_zero
				and (i - 1) % (r.input_size + 1) == 0
			then
				v = 0
			else
				if init_f == "normal" then
					v = love.math.randomNormal(init_scale, 0)
				elseif init_f == "uniform" then
					v = love.math.random() * init_scale
				elseif init_f == "signed_uniform" then
					v = (love.math.random() * 2 - 1) * init_scale
				end
			end
			r.weights[i] = v
		end
	end
	r:flush()
	return r
end

function layer:clone()
	local r = layer:new({
		input_size = self.input_size,
		output_size = self.output_size,
		weights = self.weights,
	})
	return r
end

function layer:flush()
	self.textures = {}
	return self
end

local _arity_dependent_names = {
	"feed",
	"output",
	"delta",
}
function layer:cache_textures(arity)
	if not self.textures.weights then
		self.textures.weights = table_to_texture(
			self.weights,
			self.input_size + 1,
			self.output_size,
			1
		)
	end
	if self.arity ~= arity then
		self.arity = arity
		for i,v in ipairs(_arity_dependent_names) do
			if arity == nil then
				self.textures[v] = nil
			else
				self.textures[v] = create_canvas(self.output_size, self.arity)
			end
		end
	end
end

function layer:read_weights_from_gpu()
	if self.textures.weights then
		local v, w, h = read_float_texture(self.textures.weights, 16)
		--sanity check
		if
			w == self.input_size + 1
			and h == self.output_size
		then
			self.values = v
		end
	end
end

-------------------------------------------------------------------------------
--network type for neural network
local network = {}
network.__mt = {
	__index = network,
}

function network:new(args)
	local r = setmetatable({
		layers = {},
		activation = args.activation or network.activate.relu,
	}, self.__mt)

	if args.weights then
		--got explicit weights table
		for _, l in ipairs(args.weights) do
			local weights = {}
			local node_count = #l
			local weight_count = #l[1]
			for _, n in ipairs(l) do
				for _, v in ipairs(n) do
					table.insert(weights, v)
				end
			end
			table.insert(r.layers, layer:new({
				input_size = weight_count - 1,
				output_size = node_count,
				weights = weights,
			}))
		end
	else
		--gotta generate a new network
		if
			not args.input_size
			or not args.output_size
			or not args.width
			or not args.depth
		then
			error("missing argument")
		end
		for l = 1, args.depth do
			--internal size
			local input_size = args.width
			local output_size = args.width

			--input layer
			if l == 1 then
				input_size = args.input_size
			end
			--output layer
			if l == args.depth then
				output_size = args.output_size
			end

			--generate new layer
			table.insert(r.layers, layer:new({
				input_size = input_size,
				output_size = output_size,
				--initialise weights
				initialise = args.initialise,
			}))
		end
	end
	return r
end

function network:clone()
	return network:new(self:get_weights())
end

function network:read_weights_from_gpu()
	for _, l in ipairs(self.layers) do
		l:read_weights_from_gpu()
	end
end

function network:get_weights(weights)
	self:read_weights_from_gpu()
	local w = {}
	for _,l in ipairs(self.layers) do
		local lw = {}
		local i = 0
		for y = 1, l.output_size do
			local n = {}
			for x = 1, l.input_size + 1 do
				i = i + 1
				local v = l.weights[i]
				table.insert(n, v)
			end
			table.insert(lw, n)
		end
		table.insert(w, lw)
	end
end

local function _mismatched_weights_array_size()
	error("mismatched weights array size in network:set_weights")
end

function network:set_weights(weights)
	if #weights ~= #self.layers then
		_mismatched_weights_array_size()
	end
	for i,l in ipairs(self.layers) do
		l:flush()
		l.weights = {}
		local lw = weights[i]
		for _,n in ipairs(lw) do
			for _,w in ipairs(n) do
				table.insert(l.weights, w)
			end
		end
	end
end

--read/write

function network:serialise()
	local t = {
		weights = self:get_weights(),
		activation = self.activation,
	}
	return json.encode(t)
end

function network:deserialise(s)
	local t = json.decode(s)
	return network:new({
		weights = t.weights,
		activation = t.activation or network.activate.relu,
	})
end

--get the output layer
function network:output_layer()
	return self.layers[#self.layers]
end

--get the current output
function network:get_output()
	return self:output_layer().textures.output
end

--uniform constants script-side
network.activate = {
	relu = 0,
	lrelu = 1,
	tanh = 2,
}

-------------------------------------------------------------------------------
--shared utility stuff between shaders
local shader_common_src = [[
#pragma language glsl3

float random(vec2 v) {
	vec2 rescale = sin(v);
	float r = dot(rescale, vec2(12.9898, 78.233));
	r = fract(sin(r) * 143758.5453);
	return r;
}

//activation functions and derivatives

//linear rectifier
float relu(float v) {
	return max(0.0, v);
}

float drelu(float v) {
	if(v > 0) {
		return 1.0;
	}
	return 0.0;
}

//leaky linear rectifier
const float LRELU_LEAK = 0.01;
float lrelu(float v) {
	if (v >= 0.0) {
		return v;
	}
	return v * LRELU_LEAK;
}

float dlrelu(float v) {
	if(v > 0) {
		return 1.0;
	}
	return LRELU_LEAK;
}

//hyperbolic tangent
float tanh(float x) {
	float e = exp(2.0 * x);
	return (e - 1.0) / (e + 1.0);
}

//(necessary for derivative of tanh)
float cosh(float x) {
	float e = exp(x);
	return (e + 1.0 / e) / 2.0;
}

float dtanh(float x) {
	float ch = cosh(2.0 * x);
	float tanh2 = (ch - 1.0) / (ch + 1.0);
	return 1.0 - tanh2;
}

const int ACTIVATE_RELU = 0;
const int ACTIVATE_LRELU = 1;
const int ACTIVATE_TANH = 2;

//generic activation function
float activate(int f, float v) {
	if(f == ACTIVATE_RELU) {
		v = relu(v);
	} else if(f == ACTIVATE_LRELU) {
		v = lrelu(v);
	} else if(f == ACTIVATE_TANH) {
		v = tanh(v);
	}
	return v;
}

//derivative of generic activation function
float transfer_derivative(int f, float v) {
	if(f == ACTIVATE_RELU) {
		v = drelu(v);
	} else if(f == ACTIVATE_LRELU) {
		v = dlrelu(v);
	} else if(f == ACTIVATE_TANH) {
		v = dtanh(v);
	} else {
		v = 1.0;
	}
	return v;
}

float clip_value(float v, float limit) {
	return sign(v) * min(limit, abs(v));
}

]]

local shader_weights_src = [[
extern Image weights;
extern int arity;
float weight(int n, int i) {
	return texelFetch(weights, ivec2(i, n), 0).r;
}
]]

function send_if_exists(shader, name, ...)
	if shader:hasUniform(name) then
		shader:send(name, ...)
	end
end

-- Run input through network

local shader_feedforward = love.graphics.newShader(shader_common_src..shader_weights_src..[[
extern Image inputs;
extern int in_count;

#ifdef PIXEL
float sample(Image tex, int node, int i, int row) {
	float w = weight(node, i + 1);
	float in_v = texelFetch(tex, ivec2(i, row), 0).r;
	return in_v * w;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
	//which output?
	int node = int(screen_coords.x - 0.5);
	int row = int(screen_coords.y - 0.5);
	//gather
	float v = 0;
	//bias
	v += 1.0 * weight(node, 0);
	//inputs
	for(int i = 0; i < in_count; i++) {
		v += sample(inputs, node, i, row);
	}
	return vec4(v, v, v, 1);
}
#endif
]])

local shader_activate = love.graphics.newShader(shader_common_src..[[
extern int activation_function;
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
	float v = Texel(tex, texture_coords).r;
	v = activate(activation_function, v);
	return vec4(v, v, v, 1);
}
#endif
]])

--feed input through the network
function network:feedforward(input)
	--sanity check and cache everything
	local arity = input:getHeight()
	for i,v in ipairs(self.layers) do
		v:cache_textures(arity)
	end

	--setup state
	love.graphics.origin()
	love.graphics.setBlendMode("replace", "premultiplied")
	for i,v in ipairs(self.layers) do
		--render pre-activation weights
		love.graphics.setCanvas(v.textures.feed)
		love.graphics.setShader(shader_feedforward)
		send_if_exists(shader_feedforward, "weights", v.textures.weights)
		send_if_exists(shader_feedforward, "inputs", input)
		send_if_exists(shader_feedforward, "in_count", v.input_size)
		send_if_exists(shader_feedforward, "arity", arity)
		love.graphics.rectangle("fill", 0, 0, v.textures.output:getWidth(), v.textures.output:getHeight())
		--render output
		love.graphics.setCanvas(v.textures.output)
		love.graphics.setShader(shader_activate)
		send_if_exists(shader_activate, "activation_function", self.activation)
		love.graphics.draw(v.textures.feed,0,0)
		--input for next stage
		input = v.textures.output
	end
	--reset state
	_reset_gfx()
end

-- 1 pass version of feedforward
-- (doesn't get intermediate feeds/outputs so cannot be used for learning)
-- (generally much faster though)

local shader_feedforward_1pass = love.graphics.newShader(shader_common_src..[[
extern ArrayImage weights;
extern int layers;

extern int input_size;
extern int internal_size;
extern int output_size;

extern Image input_texture;

extern int activation_function;

const int MAX_WEIGHTS = 256;

float buffer_a[MAX_WEIGHTS];
float buffer_b[MAX_WEIGHTS];

#ifdef PIXEL
float weight(int layer, int n, int i) {
	return texelFetch(weights, ivec3(i, n, layer), 0).r;
}

float sample_tex(Image tex, int node, int i, int row) {
	float w = weight(0, node, i + 1);
	float in_v = texelFetch(tex, ivec2(i, row), 0).r;
	return in_v * w;
}

float sample_buf(int layer, int node, int i) {
	float w = weight(layer, node, i + 1);
	float in_v = (layer % 2) == 1 ? buffer_a[i] : buffer_b[i];
	return in_v * w;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
	int row = int(screen_coords.y);

	for (int layer = 0; layer < layers - 1; layer++) {
		//number of inputs and outputs for this layer
		int input_count =
			layer == 0 ? input_size :
			internal_size;
		//(output is gathered later; internal layers all output internal size)
		int output_count = internal_size;

		//gather into buffer
		for(int n = 0; n < output_count; n++) {
			float v = 0;
			v += 1.0 * weight(layer, n, 0);
			if (layer == 0) {
				for (int i = 0; i < input_count; i++) {
					v += sample_tex(input_texture, n, i, row);
				}
			} else {
				for (int i = 0; i < input_count; i++) {
					v += sample_buf(layer, n, i);
				}
			}
			//activate
			v = activate(activation_function, v);
			//store
			if((layer % 2) == 0) {
				buffer_a[n] = v;
			} else {
				buffer_b[n] = v;
			}
		}
	}

	//gather final layer
	int layer = layers - 1;
	int output_node = int(screen_coords.x);
	float v = 0;
	v += 1.0 * weight(layer, output_node, 0);
	for (int i = 0; i < internal_size; i++) {
		v += sample_buf(layer, output_node, i);
	}
	v = activate(activation_function, v);

	return vec4(v, v, v, 1);
}
#endif
]])

function network:feedforward_1pass(input)
	--sanity check and cache everything
	local arity = input:getHeight()
	for i,v in ipairs(self.layers) do
		v:cache_textures(arity)
	end

	--set mode
	love.graphics.origin()
	love.graphics.setBlendMode("replace", "premultiplied")

	--cache weights into a stacked texture
	--todo: some way to clear this
	if not self._stacked_weights_cv then
		--gather required dimensions
		local max_dim_x, max_dim_y = 0, 0
		for i,v in ipairs(self.layers) do
			max_dim_x = math.max(max_dim_x, v.textures.weights:getWidth())
			max_dim_y = math.max(max_dim_y, v.textures.weights:getHeight())
		end

		self._stacked_weights_cv = love.graphics.newCanvas(
			max_dim_x, max_dim_y, #self.layers,
			{
				format = _1d_canvas_format,
			}
		)
		for i,v in ipairs(self.layers) do
			love.graphics.setCanvas(self._stacked_weights_cv, i)
			love.graphics.draw(v.textures.weights)
		end
	end

	--setup state
	local output_layer = self:output_layer()
	local output_cv = output_layer.textures.output
	love.graphics.setCanvas(output_cv)

	love.graphics.setShader(shader_feedforward_1pass)
	send_if_exists(shader_feedforward_1pass, "weights",             self._stacked_weights_cv)
	send_if_exists(shader_feedforward_1pass, "layers",              #self.layers)
	send_if_exists(shader_feedforward_1pass, "input_size",          self.layers[1].input_size)
	send_if_exists(shader_feedforward_1pass, "internal_size",       output_layer.input_size)
	send_if_exists(shader_feedforward_1pass, "output_size",         output_layer.output_size)
	send_if_exists(shader_feedforward_1pass, "input_texture",       input)
	send_if_exists(shader_feedforward_1pass, "activation_function", self.activation)

	love.graphics.rectangle("fill", 0, 0, output_cv:getWidth(), output_cv:getHeight())

	--reset state
	_reset_gfx()
end

--expose some of the utility stuff
network.utility = {
	create_canvas = create_canvas,
	table_to_texture = table_to_texture,
	input_to_texture = input_to_texture,
}

return network