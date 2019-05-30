--[[
	hallucinet ui
]]

--9slice base code
--offset from edges
--collapse corners dynamically

--tray

--button

--overall settings
	render mode
		still
		animated
			static
				render fps
				render length
			dynamic
				dt per tick
	render resolution
		10% 25% 50% 100% 200%

--i/o
	save/load: named
		config
		frames

--colour design
	colour unpack modes
	plain: rgb/hsv
	designed:
		colour
			n colours
			blend modes
		gradient
			n gradients -1 to 1

--input design
	add/remove input generator
		basic:
			x, y
				scale
				symmetry x, y
			3 phase time
				scale
				freq
			shape
				generator
					scroll
					merge
					square
					circle
					spiral
				func
					bands
						single
						steep
						duty
					tri
					sin
				fade
					distance
					shape
					min
					max
				distort
					bend x
					bend y
					sin x
					sin y
			transform
				start + anim each
				translate
				rotate
				scale

		custom node graph later

--net design
	width
	depth
	init params
		gen type
		gen scale
		gen offset
		init bias
	output arity multiplier
	generate new
	modify weights

--postprocess
	hueshift
		static
		animated
	dither

	posterise

	edge detect

	invert

--render
	still
	anim

--tutorial