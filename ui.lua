--[[
	hallucinet ui
]]

local ui = {}

--9slice base code
--offset from edges
--collapse corners dynamically

function draw_9slice(atlas, x, y, w, h, edge_offset)
	local aw, ah = atlas:getDimensions()

	local _q = love.graphics.newQuad(0, 0, 0, 0, aw, ah)

	love.graphics.draw(
		atlas, _q,
		x, y
	)
end

--ui base node element
local ui_base = {}
ui.base = ui_base

ui_base._mt = {__index = ui_base}
function ui_base:new()
	return setmetatable({
		children = {},
		x = 0, y = 0,
		w = 0, h = 0,
		--(defaults)
		position = "relative",
		col = {
			fg = {1, 1, 1, 1},
			fg_hover = {1, 1, 1, 1},
			bg = {0, 0, 0, 0.25},
			bg_hover = {0, 0, 0, 0.25},
		},
		visible = {
			fg = true,
			bg = true,
			children = true,
		},
		padding = {
			h = 10,
			v = 10,
			--fractional
			before = 1.0,
			between = 1.0,
			after = 1.0,
		},
		anchor = {
			h = "left",
			v = "top",
		},
		layout_direction = "v",
		noclip = false,
		is_hovered = false,
		is_dirty = true,
	}, ui_base._mt)
end

--mark a node's tree dirty
function ui_base:dirty()
	if not self.is_dirty then
		self.is_dirty = true
		--todo: figure out which way this should actually propagate :)
		if self.parent then
			self.parent:dirty()
		end
		for i,v in ipairs(self.children) do
			v:dirty()
		end
	end
end

--layout an entire tree
function ui_base:layout()
	--base size is just padding around zero
	local between = self.padding.between
	local before = self.padding.before
	local after = self.padding.after
	local ba_total = before + after

	self.w = self.padding.h * ba_total
	self.h = self.padding.v * ba_total

	--start of positioning
	local x = self.padding.h * before
	local y = self.padding.v * before

	for i, v in ipairs(self.children) do
		if v.position == "relative" then
			--position child
			v.x = x
			v.y = y
			--layout child + its children
			v:layout()
			--step around it in the right direction
			local pad_amount = (i < #self.children and between or after)
			if self.layout_direction == "v" then
				self.w = math.max(self.w, self.padding.h * ba_total + v.w)
				y = y + v.h + self.padding.v * pad_amount
			elseif self.layout_direction == "h" then
				self.h = math.max(self.h, self.padding.v * ba_total + v.h)
				x = x + v.w + self.padding.h * pad_amount
			end
		else
			--just layout child + its children (doesn't affect out layout)
			v:layout()
		end
	end

	if self.layout_direction == "v" then
		self.h = y
	elseif self.layout_direction == "h" then
		self.w = x
	end

	return self
end

--child management
function ui_base:add_child(c)
	c:remove()
	table.insert(self.children, c)
	c.parent = self
	--(relayout handled by remove call)
	return self
end

function ui_base:remove_child(c)
	for i, v in ipairs(self.children) do
		if v == c then
			table.remove(self.children, i)
			break
		end
	end
	self:dirty()
	return self
end

function ui_base:clear_children()
	while #self.children > 0 do
		self.children[1]:remove()
	end
	return self
end

function ui_base:remove()
	if self.parent then
		self.parent:remove_child(self)
		self.parent = nil
		self:dirty()
	end
	return self
end

--chainable modifiers
function ui_base:set_padding(name, p)
	if self.padding[name] == nil then
		error("attempt to set bogus padding "..name)
	end
	self.padding[name] = p
	return self
end

function ui_base:set_colour(name, r, g, b, a)
	local c = self.col[name]
	if c == nil then
		error("attempt to set bogus colour "..name)
	end
	c[1] = r
	c[2] = g
	c[3] = b
	c[4] = a
	return self
end

function ui_base:set_visible(name, v)
	if self.visible[name] == nil then
		error("attempt to set bogus visibility "..name)
	end
	self.visible[name] = v
	return self
end

--drawing
function ui_base:draw_background()
	love.graphics.rectangle("fill", 0, 0, self.w, self.h)
end

function ui_base:draw_children()
	for _,v in ipairs(self.children) do
		v:draw()
	end
end

function ui_base:pos()
	--todo: cache this?
	local x, y = self.x, self.y
	local ah, av = self.anchor.h, self.anchor.v
	
	if ah == "left" then
		--no change
	elseif ah == "center" or "centre" then
		x = x - self.w * 0.5
	elseif ah == "right" then
		x = x - self.w
	end

	if av == "top" then
		--no change
	elseif av == "center" or "centre" then
		x = x - self.h * 0.5
	elseif av == "bottom" then
		x = x - self.h
	end

	return x, y
end

function ui_base:pos_absolute()
	local px, py = 0, 0
	if 
		self.position ~= "absolute"
		and self.parent
	then
		px, py = self.parent:pos_absolute()
	end
	return px + self.x, py + self.y
end

function ui_base:base_draw(inner)
	love.graphics.push()
	--set up position
	if self.position == "absolute" then
		love.graphics.origin()
	end
	love.graphics.translate(self:pos())
	--draw bg
	if self.visible.bg then
		local r, g, b, a = unpack(self.is_hovered and self.col.bg_hover or self.col.bg)
		love.graphics.setColor(r, g, b, a)
		self:draw_background()
	end
	--draw fg
	if self.visible.fg then
		local r, g, b, a = unpack(self.is_hovered and self.col.fg_hover or self.col.fg)
		love.graphics.setColor(r, g, b, a)
		if inner then
			inner(self)
		end
	end
	--draw children
	if self.visible.children then
		self:draw_children()
	end
	--restore state
	love.graphics.pop()
	love.graphics.setColor(1,1,1,1)
end

function ui_base:draw(inner)
	self:base_draw(inner)
end

--inputs
function ui_base:pointer(event, x, y)
	local px, py = self:pos_absolute()
	local dx = x - px
	local dy = y - py

	self.is_hovered = false

	for i,v in ipairs(self.children) do
		if v:pointer(event, x, y) then
			return true
		end
	end

	if not self.noclip then
		self.is_hovered =
			dx >= 0 and dx < self.w
			and dy >= 0 and dy < self.h
	end

	if self.is_hovered then
		if event == "click" and self.onclick then
			self:onclick(x, y)
		end
		if event == "drag" and self.ondrag then
			self:ondrag(x, y)
		end
		if event == "release" and self.onrelease then
			self:onrelease(x, y)
		end
	end

	return self.is_hovered
end

--nop function to dummy out functions with
function ui_base:nop()
	return self
end

--(internal)
local _leaf_nops = {
	"add_child",
	"remove_child",
	"layout",
	"draw_children",
}
--set up a leaf type (meant for constructors not for individuals)
function ui_base:_set_leaf_type()
	for i,v in ipairs(_leaf_nops) do
		self[v] = ui_base.nop
	end
	self.is_leaf = true
	return self
end

--dummy container for linking everything together
local ui_container = ui_base:new()
ui.container = ui_container
ui_container._mt = {__index = ui_container}

function ui_container:new()
	self = setmetatable(ui_base:new(), ui_container._mt)
	self.visible.bg = false
	self.visible.fg = false
	self.noclip = true
	return self
end

--tray for holding buttons etc
local ui_tray = ui_base:new()
ui.tray = ui_tray
ui_tray._mt = {__index = ui_tray}

function ui_tray:new(x, y, w, h)
	self = setmetatable(ui_base:new(), ui_tray._mt)
	self.x, self.y = x, y
	self.w, self.h = w, h
	self.position = "absolute"
	return self
end

function ui_tray:layout()
	--cache beforehand
	local cache_w, cache_h = self.w, self.h
	--layout as normal
	ui_base.layout(self)
	--preserve at least what we had
	self.w = math.max(cache_w, self.w)
	self.h = math.max(cache_h, self.h)

	return self
end

--inline row
local ui_row = ui_base:new()
ui.row = ui_row
ui_row._mt = {__index = ui_row}

function ui_row:new(v)
	self = setmetatable(ui_base:new(), ui_row._mt)
	self.layout_direction = "h"
	self.padding.v = 0
	self.padding.before = 0
	self.padding.after = 0
	self.visible.bg = v
	self.noclip = true
	return self
end

--inline col
local ui_col = ui_base:new()
ui.col = ui_col
ui_col._mt = {__index = ui_col}

function ui_col:new(v)
	self = setmetatable(ui_base:new(), ui_row._mt)
	self.padding.h = 0
	self.padding.before = 0
	self.padding.after = 0
	self.layout_direction = "v"
	self.visible.bg = v
	self.noclip = true
	return self
end

--button
local ui_button = ui_base:new():_set_leaf_type()
ui.button = ui_button
ui_button._mt = {__index = ui_button}

function ui_button:new(asset, w, h)
	self = setmetatable(ui_base:new(), ui_button._mt)

	if asset then
		self.ui_button_asset = asset
		--take asset size if bigger
		self.aw, self.ah = asset:getDimensions()
		w = math.max(self.aw, w or 0)
		h = math.max(self.ah, h or 0)
	end
	self.w, self.h = w, h

	self.col.bg_hover = {0, 0, 0, 0.5}

	return self
end

--draw button image centred
function ui_button:_draw()
	if self.ui_button_asset then
		love.graphics.draw(
			self.ui_button_asset,
			math.floor(self.w * 0.5),
			math.floor(self.h * 0.5),
			0,
			math.floor(self.aw * 0.5),
			math.floor(self.ah * 0.5)
		)
	end
end

function ui_button:draw()
	self:base_draw(self._draw)
end

--text element
local ui_text = ui_base:new():_set_leaf_type()
ui.text = ui_text
ui_text._mt = {__index = ui_text}
function ui_text:new(font, t, w, align)
	self = setmetatable(ui_base:new(), ui_text._mt)

	self.set_w = w
	self.align = align or "center"
	self.ui_text = love.graphics.newText(font, nil)

	return self:set_text(t, w, align)
end

function ui_text:set_text(t, w, align)
	self.set_w = w or self.set_w
	self.align = align or self.align

	self.ui_text:setf(t, self.set_w, self.align)

	local ba_total = (self.padding.before + self.padding.after)
	self.w = self.set_w + self.padding.h * ba_total
	self.h = self.ui_text:getHeight() + self.padding.v * ba_total

	return self
end

function ui_text:_draw()
	love.graphics.draw(
		self.ui_text,
		self.padding.h * self.padding.before,
		self.padding.v * self.padding.before
	)
end

function ui_text:draw()
	return self:base_draw(self._draw)
end

--[[

--play/pause
	(start/stop rendering)
	(hide panel)

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

--random
	input configuration
	output configuration
	network
	everything

--tutorial
]]

return ui