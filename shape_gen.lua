--generator output functions
function shape_gen_blank(strength, frequency)
	strength = strength or 1
	frequency = frequency or 1
	return {"shape", {
		strength,	--"shape_strength"
		frequency,	--"shape_freq"
		0.0,	--"bands_duty"
		0.0,	--"bands_steep"
		0.0,	--"use_sin"
		0.0,	--"shape_amount_gradient"
		0.0,	--"shape_amount_wedge"
		0.0,	--"shape_amount_curve"
		0.0,	--"shape_amount_diamond"
		0.0,	--"shape_amount_square"
		0.0,	--"shape_amount_circle"
		0.0,	--"anim_strength"
		0.0,	--"anim_amount_linear"
		0.0,	--"anim_amount_sin"
		0.0,	--"anim_amount_sqsin"
		0.0,	--"anim_amount_bounce"
		0.0,	--"anim_amount_sqbounce"
		0.0,	--"anim_amount_hesitant"
		0.0,	--"anim_amount_tri"
		1.0,	--"range_var_balance"
		-2.0,	--"min_range"
		2.0,	--"max_range"
		0.5,	--"fade_steep"
		0.0,	--"anim_spins"
		0.0,	--"shape_rotation"
		0.0,	--"shape_offset_x"
		0.0,	--"shape_offset_y"
		1.0,	--"shape_scale_x"
		1.0,	--"shape_scale_y"
	}}
end

function shape_gen_pattern_linear(t)
	t[2][3] = 0
	t[2][4] = 0
	t[2][5] = 0
	return t
end

function shape_gen_pattern_bands(t, duty, steep)
	shape_gen_pattern_linear(t)
	t[2][3] = duty or 0.5
	t[2][4] = steep or 10.0
	return t
end

function shape_gen_pattern_sin(t)
	shape_gen_pattern_linear(t)
	t[2][5] = 1.0
	return t
end

function shape_gen_set_gradient(t, amount)
	t[2][6] = amount or 1.0
	return t
end
function shape_gen_set_wedge(t, amount)
	t[2][7] = amount or 1.0
	return t
end
function shape_gen_set_curve(t, amount)
	t[2][8] = amount or 1.0
	return t
end
function shape_gen_set_diamond(t, amount)
	t[2][9] = amount or 1.0
	return t
end
function shape_gen_set_square(t, amount)
	t[2][10] = amount or 1.0
	return t
end
function shape_gen_set_circle(t, amount)
	t[2][11] = amount or 1.0
	return t
end

function shape_gen_anim(t, loops, anim_type)
	t[2][12] = math.floor(loops)
	t[2][13] = anim_type == "linear"	and 1.0 or 0.0
	t[2][14] = anim_type == "sin"		and 1.0 or 0.0
	t[2][15] = anim_type == "sqsin"		and 1.0 or 0.0
	t[2][16] = anim_type == "bounce"	and 1.0 or 0.0
	t[2][17] = anim_type == "sqbounce"	and 1.0 or 0.0
	t[2][18] = anim_type == "hesitant"	and 1.0 or 0.0
	t[2][19] = anim_type == "tri"		and 1.0 or 0.0
	return t
end

function shape_gen_fade(t, fade_type, min, max, fade_distance)
	t[2][20] = fade_type == "distance" and 0.0 or 1.0
	t[2][21] = min
	t[2][22] = max
	t[2][23] = fade_distance
	return t
end

function shape_gen_anim_spins(t, spins)
	t[2][24] = spins
	return t
end

function shape_gen_transform(t, ox, oy, r, sx, sy)
	t[2][25] = r or 0.0
	t[2][26] = ox or 0.0
	t[2][27] = oy or ox or 0.0
	t[2][28] = sx or 1.0
	t[2][29] = sy or 1.0
	return t
end

function shape_gen_random_transform(t)
	return shape_gen_transform(t,
		love.math.random() * 2.0 - 1.0,
		love.math.random() * 2.0 - 1.0,
		love.math.random() * 2.0 - 1.0
	)
end

function shape_gen_random_pattern(t)
	if love.math.random() < 0.5 then
		shape_gen_pattern_bands(t, 0.25, 10.0)
	elseif love.math.random() < 0.5 then
		shape_gen_pattern_sin(t)
	end
	return t
end

function shape_gen_random_shape(t)
	local _gt = love.math.random(0, 6)
	local function _pr(_gt, tg)
		return (_gt == tg or (_gt == 0 and love.math.random() < 0.5))
	end
	local function _random_amount()
		return (love.math.random() < 0.5 and -1 or 1)
	end
	shape_gen_set_gradient(
		t,
		_pr(_gt, 1)
			and _random_amount()
			or 0.0
	)
	shape_gen_set_wedge(
		t,
		_pr(_gt, 2)
			and _random_amount()
			or 0.0
	)
	shape_gen_set_curve(
		t,
		_pr(_gt, 3)
			and _random_amount()
			or 0.0
	)
	shape_gen_set_diamond(
		t,
		_pr(_gt, 4)
			and _random_amount()
			or 0.0
	)
	shape_gen_set_square(
		t,
		_pr(_gt, 5)
			and _random_amount()
			or 0.0
	)
	shape_gen_set_circle(
		t,
		_pr(_gt, 6)
			and _random_amount()
			or 0.0
	)
	return t
end

function shape_gen_random_fade(t)
	return shape_gen_fade(t,
		love.math.random() < 0.5 and "distance" or "shape",
		0.5 - love.math.random() * 5,
		1 + love.math.random() * 5,
		0.5 + love.math.random()
	)
end

function random_shape_gen()
	local t = shape_gen_blank()

	shape_gen_random_shape(t)
	shape_gen_random_pattern(t)

	shape_gen_anim(t, love.math.random(-3, 3),
		love.math.random() < 0.5 and "linear"
		or love.math.random() < 0.5 and "sin"
		or love.math.random() < 0.5 and "bounce"
		or love.math.random() < 0.5 and "hesitant"
		or love.math.random() < 0.5 and "tri"
		or love.math.random() < 0.5 and "sqsin"
		or "sqbounce"
	)

	if love.math.random() < 0.75 then
		shape_gen_random_fade(t)
	end

	shape_gen_random_transform(t)
	return t
end