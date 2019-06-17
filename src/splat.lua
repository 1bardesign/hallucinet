--shader for converting rgb inputs to neural net serialised inputs
--todo: kernel extraction as well
local splat_shader = love.graphics.newShader([[
extern Image tex;
extern vec2 tex_size;

extern vec2 start_pixel;
extern vec2 rect_size;

#ifdef PIXEL
vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
	float i = floor(screen_coords.y);
	vec2 px = start_pixel + vec2(
		mod(i, rect_size.x),
		floor(i / rect_size.x)
	);
	vec2 uv = px / tex_size;
	vec4 read = Texel(tex, uv);

	i = floor(screen_coords.x);
	float v =
		float(i == 0.0) * read.r +
		float(i == 1.0) * read.g +
		float(i == 2.0) * read.b +
		float(i == 3.0) * read.a;
	return vec4(v,v,v,1.0);
}
#endif
]])

function splat(input, x, y, w, h)
	splat_shader:send("tex", input)
	splat_shader:send("tex_size", {input:getDimensions()})
	splat_shader:send("start_pixel", {x, y})
	splat_shader:send("rect_size", {w, h})
	love.graphics.setShader(splat_shader)
	love.graphics.push()
	love.graphics.origin()
	love.graphics.rectangle("fill", 0, 0, 3, w * h)
	love.graphics.setShader()
	love.graphics.pop()
end

function splat_into(input, into, x, y, w, h)
	love.graphics.setCanvas(into)
	splat(input, x, y, w, h)
	love.graphics.setCanvas()
	return into
end

--shader for converting n channel outputs into rgb or hsv
local unsplat_shader = love.graphics.newShader([[
extern Image components;
extern vec2 components_size;

extern vec2 start_pixel;
extern vec2 rect_size;

extern int unsplat_mode;

extern int arity;

vec3 unsplat_norm(vec3 i) {
	return (i + vec3(1.0)) * vec3(0.5);
}

vec3 unsplat_rgb(vec3 i) {
	return i;
}

vec3 unsplat_rgb_norm(vec3 i) {
	return unsplat_rgb(unsplat_norm(i));
}

vec3 unsplat_hsv(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 unsplat_hsv_norm(vec3 i) {
	return unsplat_hsv(unsplat_norm(i));
}

vec3 unsplat(vec3 i) {
	if (unsplat_mode == 0) {
		return unsplat_rgb(i);
	}
	if (unsplat_mode == 1) {
		return unsplat_rgb_norm(i);
	}
	if (unsplat_mode == 2) {
		return unsplat_hsv(i);
	}
	if (unsplat_mode == 3) {
		return unsplat_hsv_norm(i);
	}
	return i;
}

#ifdef PIXEL
vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
	vec2 px = screen_coords - start_pixel;
	float i = floor(px.x) + floor(px.y) * rect_size.x + 0.5;

	vec3 sample = vec3(0.0);
	for (int a = 0; a < arity; a++) {
		float offset = float(a) * 3.0;
		sample += vec3(
			Texel(components, vec2((offset + 0.5) / components_size.x, i / components_size.y)).r,
			Texel(components, vec2((offset + 1.5) / components_size.x, i / components_size.y)).r,
			Texel(components, vec2((offset + 2.5) / components_size.x, i / components_size.y)).r
		);
	}

	sample /= float(arity);

	return gammaCorrectColor(vec4(unsplat(sample), 1.0));
}
#endif
]])

local unsplat_mode = {
	rgb = 0,
	rgb_norm = 1,
	hsv = 2,
	hsv_norm = 3,
}

function unsplat(mode, components, x, y, w, h)
	--
	local m = unsplat_mode[mode]
	if not m then
		error("invalid unsplat mode: "..tostring(mode))
	end
	unsplat_shader:send("components", components)
	unsplat_shader:send("components_size", {components:getDimensions()})
	unsplat_shader:send("unsplat_mode", m)
	unsplat_shader:send("start_pixel", {x, y})
	unsplat_shader:send("rect_size", {w, h})
	unsplat_shader:send("arity", math.ceil(components:getWidth() / 3))
	love.graphics.setShader(unsplat_shader)
	love.graphics.push()
	love.graphics.origin()
	love.graphics.rectangle("fill", x, y, w, h)
	love.graphics.setShader()
	love.graphics.pop()
end

function unsplat_into(mode, components, into)
	love.graphics.setCanvas(into)
	unsplat(mode, components, 0, 0, into:getDimensions())
	love.graphics.setCanvas()
	return into
end