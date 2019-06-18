--[[
	draw overlay-textured 9slices
]]

local _nn_tex_count = 24
local _nn_tex = {}
for i = 0, _nn_tex_count do
	local filename = string.format("assets/nn_tex_%04d.png", i)
	local img = love.graphics.newImage(filename)
	img:setWrap("clamp")
	local idx = math.max(1, love.math.random(1, #_nn_tex))
	table.insert(_nn_tex, idx, img)
end

local _tex_index = love.math.random(1, #_nn_tex)
local function next_tex()
	local img = _nn_tex[_tex_index]
	--increment
	_tex_index = _tex_index + 1
	if _tex_index > #_nn_tex then
		_tex_index = 1
	end
	return img
end


local _overlay_shader = love.graphics.newShader([[
extern Image over_tex;
extern vec2 over_tex_size;
extern vec2 pixel_offset;
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
	vec2 over_uv = (screen_coords - pixel_offset) / over_tex_size;

	return
		Texel(tex, texture_coords)
		* Texel(over_tex, over_uv)
		* color;
}
#endif
]])

function create_textured_9slice_f(atlas, pad)
	--default
	pad = pad or 2

	--get the texture
	local img = next_tex()
	--random offset
	local aw, ah = img:getDimensions()
	local offset = {
		love.math.random(1, aw),
		love.math.random(1, ah),
	}
	return function(x, y, w, h)
		local sx, sy = love.graphics.transformPoint(x, y)
		local ox = math.min(offset[1], aw - w - pad)
		local oy = math.min(offset[2], ah - h - pad)
		_overlay_shader:send("over_tex", img)
		_overlay_shader:send("over_tex_size", {aw, ah})
		_overlay_shader:send("pixel_offset", {
			sx - pad - 1 - ox,
			sy - pad - 1 - oy,
		})
		love.graphics.setShader(_overlay_shader)
		draw_9slice(atlas, x, y, w, h, pad, false)
		love.graphics.setShader()
	end
end

return create_textured_9slice_f