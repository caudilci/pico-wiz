pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

-- game state
function _init()
	frame = 0
	gamestate = "title"
	walls = { 16, 17, 18, 19, 20, 22 }

	dirx = { -1, 1, 0, 0, 1, 1, -1, -1 }
	diry = { 0, 0, -1, 1, -1, 1, 1, -1 }
	debug = {}
	--expected data {{{sprites}{{x,y},...}},...}
	ani_queue = {}
	mobs = {}
	tframe = -1
	move_complete = true
	ani_complete = true
	floor = 1
	enemies_killed = 0
	spells_cast = 0
	items_used = 0
	turn = 1
	draw_health_bars = false

	init_spellbook()
	init_items()
	init_player()
	init_cast()
	init_enemies()
	init_menu()
	init_world()
end

function _update()
	cls()
	frame += 1
	if gamestate == "standby" then
		update_player()
	elseif gamestate == "turn" then
		move_complete = move_all_mobs()
		tframe += 1
		if move_complete and ani_complete then
			set_state("standby")
		end
		--move enemies
	elseif gamestate == "menu" then
		update_menu()
	elseif gamestate == "cast" then
		update_cast()
	elseif gamestate == "gameover" then
		gameover()
	elseif gamestate == "title" then
		title()
	end
end

function _draw()
	if gamestate == "gameover" then
		draw_gameover()
		return
	elseif gamestate == "title" then
		draw_title()
		return
	end
	map(0)
	draw_items()
	draw_all_mobs()
	if draw_health_bars then
		draw_enemy_health()
	end
	draw_hp(0, 0, 0, 6, 6, true)
	draw_floor()
	draw_selected_spell()
	draw_debug()
	if gamestate == "turn" then
		ani_complete = animations(tframe)
	elseif gamestate == "menu" then
		draw_menu()
	elseif gamestate == "cast" then
		draw_cast()
	end
end

function set_state(state)
	if state == "standby" then
		draw_health_bars = false
		tframe = -1
		if #mobs == 1 then
			for item in all(floor_items) do
				if item.sprite == 52 then
					add_item(item.x, item.y, 7)
					del(floor_items, item)
				end
			end
		end
	elseif state == "turn" then
		update_enemies()
		turn += 1
		tframe = 1
	elseif state == "menu" then
		menu_vertical_index = player.spell_index
	elseif state == "cast" then
		draw_health_bars = true
	elseif state == "gameover" then
	end
	gamestate = state
end

function draw_hp(x, y, cb, co, ct, withoutline)
	if withoutline then
		rectfill(x, y, x + get_hp_draw_offset() + 29, y + 8, cb)
		rect(x, y, x + get_hp_draw_offset() + 29, y + 8, co)
	end
	print("" .. player.hp .. "/" .. player.maxhp .. "♥", x + 2, y + 2, ct)
end

function draw_floor()
	if floor >= 10 then
		rectfill(56, 0, 70, 8, 0)
		rect(56, 0, 70, 8, 6)
		print('f' .. floor, 58, 2, 6)
	else
		rectfill(58, 0, 68, 8, 0)
		rect(58, 0, 68, 8, 6)
		print('f' .. floor, 60, 2, 6)
	end
end

function draw_selected_spell()
	local box_color1, box_color2
	local spell = mobs[1].spells[mobs[1].spell_index]
	if spell.uses == 0 then
		box_color1 = 5
		box_color2 = 6
	else
		box_color1 = 1
		box_color2 = 12
	end
	rectfill(118, 0, 127, 9, box_color1)
	rect(118, 0, 127, 9, box_color2)
	sspr(spell.icon.x, spell.icon.y, 8, 8, 119, 1, 8, 8)
end

function draw_debug()
	cursor(0, 10)
	color(8)
	for txt in all(debug) do
		print(txt)
	end
end

function draw_gameover()
	-- 18, 112, 88, 125
	sspr(18, 112, 80, 14, 23, 10)
	cursor(23, 28, 6)
	print("press ❎ to start over")
	print("")
	print("stats:")
	print("floor:" .. floor)
	print("max hp:" .. player.maxhp)
	print("spells owned:" .. #player.spells)
	print("spells cast:" .. spells_cast)
	print("enemies killed:" .. enemies_killed)
	print("items used:" .. items_used)
end

function gameover()
	if btnp(5) then
		_init()
	end
end

function draw_title()
	sspr(0, 50, 59, 14, 34, 10)
	print("press ❎ to start", 31, 28, 6)
end

function title()
	if btnp(5) then
		set_state("standby")
	end
end

function animations(tframe)
	local unfinished = false
	if tframe < 0 then
		return true
	end
	for pair in all(ani_queue) do
		local sprite = get_frame(tframe - 1, pair[1], 2)
		for point in all(pair[2]) do
			spr(sprite, point.x * 8, point.y * 8, 1, 1)
		end
		if sprite == pair[1][#pair[1]] or #pair[2] == 0 then
			del(ani_queue, pair)
		else
			unfinished = true
		end
	end
	return not unfinished
end

function move_all_mobs()
	local unfinished = false
	for mob in all(mobs) do
		local state = move_mob(mob)
		if not state then
			unfinished = true
		end
	end
	return not unfinished
end

function draw_all_mobs()
	for mob in all(mobs) do
		draw_mob(mob)
	end
end
-->8
-- items

function init_items()
	floor_items = {}
	items = {
		{
			-- health upgrade
			sprite = 48,
			on_pickup = function()
				player.hp += 25
				player.maxhp += 25
			end
		},
		{
			name = "dmg up",
			description = "permanently increases dmg of current spell",
			sprite = 54,
			icon = { x = 48, y = 24 },
			effect = function()
				player.spells[player.spell_index].dmg += 2
			end
		},
		{
			name = "uses up",
			description = "permanently increases uses of current spell",
			sprite = 55,
			icon = { x = 56, y = 24 },
			effect = function()
				player.spells[player.spell_index].uses += 2
				player.spells[player.spell_index].maxuses += 2
			end
		},
		{
			name = "range up",
			description = "permanently increases uses of current spell",
			sprite = 56,
			icon = { x = 64, y = 24 },
			effect = function()
				player.spells[player.spell_index].range += 2
			end
		},
		{
			-- spell point
			sprite = 49,
			on_pickup = function()
				player.sp += 1
			end
		},
		{
			-- closed portal
			sprite = 52
		},
		{
			-- open portal
			sprite = 53,
			on_pickup = function()
				floor += 1
				floor_items = {}
				init_world()
			end
		},
		{
			name = "health pot",
			description = "refills health",
			sprite = 50,
			icon = { x = 16, y = 24 },
			effect = function()
				player.hp = player.maxhp
			end
		},
		{
			name = "mana pot",
			description = "refills spell uses for all spells",
			sprite = 51,
			icon = { x = 24, y = 24 },
			effect = function()
				for spell in all(player.spells) do
					spell.uses = spell.maxuses
				end
			end
		}
	}
end

function add_item(x, y, type)
	local baseitem = items[type]
	local item = deepcopy(baseitem)
	item.x = x
	item.y = y
	add(floor_items, item)
end

function collect_item(x, y)
	local item = false
	for i in all(floor_items) do
		if i.x == x and i.y == y then
			item = i
		end
	end
	if item then
		if item.on_pickup then
			item.on_pickup()
		else
			local already_owned = false
			for pitem in all(player.items) do
				if pitem.name == item.name then
					pitem.count += 1
					already_owned = true
				end
			end
			if not already_owned and item.sprite != 52 then
				item.count = 1
				add(player.items, item)
			end
		end
		if item.sprite != 52 then
			del(floor_items, item)
		end
	end
end

function draw_items()
	for item in all(floor_items) do
		spr(item.sprite, item.x * 8, item.y * 8)
	end
end

-->8
-- helper functions

function chunk_string(chunk_size, string)
	local chunks = {}
	local prev_index = 1
	for i = chunk_size, #string, chunk_size do
		add(chunks, sub(string, prev_index, i))
		prev_index = i + 1
	end
	add(chunks, sub(string, prev_index))
	return chunks
end

function get_hp_draw_offset()
	if player.maxhp >= 100 then
		if player.hp >= 100 then
			return 8
		else
			return 4
		end
	end
	return 0
end

function get_frame(sframe, sprites, speed)
	return sprites[flr(sframe / speed) % #sprites + 1]
end

function detect_collision(mob)
	sprite = mget(mob.x, mob.y)
	if fget(sprite, 0) then
		return true
	end
	for m in all(mobs) do
		if m != mob and mob.x == m.x and mob.y == m.y then
			return m
		end
	end
	return false
end

function detect_collision(x, y)
	sprite = mget(x, y)
	if fget(sprite, 0) then
		return true
	end
	for m in all(mobs) do
		if x == m.x and y == m.y then
			return m
		end
	end
	return false
end

function shallowcopy(t)
	local t2 = {}
	for k, v in pairs(t) do
		t2[k] = v
	end
	return t2
end

function deepcopy(t)
	local t2 = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			t2[k] = deepcopy(v)
		else
			t2[k] = v
		end
	end
	return t2
end

function fov(x, y, r)
	local dx, dy
	local visible = {}
	for i = 0, 360 do
		dx = cos(i / 360)
		dy = sin(i / 360)
		local result = perffov(dx, dy, x, y, r)
		for point in all(result) do
			if not includes_point(visible, point) then
				add(visible, point)
			end
		end
	end
	return visible
end

function perffov(x, y, px, py, r)
	local ox, oy
	local visible = {}
	ox = px + 0.5
	oy = py + 0.5
	for i = 0, r do
		local flag = fget(mget(ox, oy))
		if flag != 1 then
			add(visible, { x = flr(ox), y = flr(oy) })
		else
			break
		end
		ox += x
		oy += y
	end
	return visible
end

function distance(x, y, x1, y1)
	local dx = x1 - x
	local dy = y1 - y
	return sqrt(dx * dx + dy * dy)
end

function in_circle(r, cx, cy, x, y)
	local xpart = x - cx
	local ypart = y - cy
	local result = xpart * xpart + ypart * ypart
	return result <= r * r
end

function normalize(x, y)
	local magnitude = flr(sqrt(x * x + y * y))
	return x / magnitude, y / magnitude
end

function is_visible(x, y, x1, y1, range)
	if includes_point(fov(x, y, range), { x = x1, y = y1 }) then
		return true
	end
	return false
end

function get_circle_points(cx, cy, r)
	local circp = {}
	add(circp, { x = cx, y = cy })
	for x = cx - r, cx do
		for y = cy - r, cy do
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r then
				xsym = cx - (x - cx)
				ysym = cy - (y - cy)
				add(circp, { x = x, y = y })
				add(circp, { x = x, y = ysym })
				add(circp, { x = xsym, y = y })
				add(circp, { x = xsym, y = ysym })
			end
		end
	end
	return circp
end

--TODO: do better
function get_line_points(x1, y1, x2, y2)
	local path = { { x = x1, y = y1 } }
	local i = 2
	while not includes_point(path, { x = x2, y = y2 }) do
		local x, y = getcloser(path[i - 1].x, path[i - 1].y, x2, y2)
		add(path, { x = x, y = y })
		i += 1
	end
	return path
end

function line_points(x1, y1, x2, y2)
	local r = distance(x1, y1, x2, y2)
	local dx, dy
	local visible = {}
	local sgnx, sgny = sgn(x2 - x1), sgn(y2 - y1)
	local startang, endang
	if sgnx == -1 then
		if sgny == -1 then
			startang = 90
			endang = 180
		else
			startang = 180
			endang = 270
		end
	else
		if sgny == -1 then
			startang = 0
			endang = 90
		else
			startang = 270
			endang = 360
		end
	end
	for i = startang, endang do
		dx = cos(i / 360)
		dy = sin(i / 360)
		local result = perffov(dx, dy, x1, y1, r)
		if includes_point(result, { x = x2, y = y2 }) then
			for point in all(result) do
				if not includes_point(visible, point) then
					add(visible, point)
				end
			end
			break
		end
	end
	if #visible < 1 then
		return get_line_points(x1, y1, x2, y2)
	end
	return visible
end

function inTriangle(x, y, x1, y1, x2, y2, px, py)
	local s1 = y2 - y
	local s2 = x2 - x
	local s3 = y1 - y
	local s4 = py - y
	local w1 = (x * s1 + s4 * s2 - px * s1) / (s3 * s2 - (x1 - x) * s1)
	local w2 = (s4 - w1 * s4) / s1
	return w1 >= 0 and w2 >= 0 and w1 + w2 <= 1
end

-- wa is width in terms of degrees
function get_cone_points(x, y, x1, y1, wa, r)
	local visible = {}
	local deltax, deltay = x1 - x, y1 - y
	local angle = atan2(deltax, deltay)
	local degang = angle * 360
	local s = degang - wa / 2
	local e = degang + wa / 2
	local countdir = sgn(e - s)
	for i = s, e, countdir do
		local dx = cos(i / 360)
		local dy = sin(i / 360)
		local result = perffov(dx, dy, x, y, r)
		for point in all(result) do
			if not includes_point(visible, point) then
				add(visible, point)
			end
		end
	end
	del(visible, { x = x, y = y })
	return visible
end

function includes_point(array, v)
	if #array == 0 then
		return false
	end
	for item in all(array) do
		if item.x == v.x and item.y == v.y then
			return true
		end
	end
	return false
end

function getcloser(x1, y1, x2, y2)
	local bdst, bx, by = 999, 0, 0
	for i = 1, 4 do
		local dx, dy = dirx[i], diry[i]
		local dist = distance(x1 + dx, y1 + dy, x2, y2)
		if dist < bdst and fget(mget(x1 + dx, y1 + dy)) != 1 then
			bdst = dist
			bx = x1 + dx
			by = y1 + dy
		end
	end
	return bx, by
end

-->8
-- menu

function init_menu()
	menu_tab_index = 1
	menu_vertical_index = 1
	menu_tabs = { "spells", "items" }
	menu_startx, menu_starty, menu_endx, menu_endy = 2, 2, 126, 126
	tab_menu_height = 11
	status_menu_heigt = 11
	-- in_upgrade_menu = false
end

function update_menu()
	if btnp(3) then
		if menu_tab_index == 1 then
			if menu_vertical_index == #spellbook then
				menu_vertical_index = 1
			else
				menu_vertical_index += 1
			end
		elseif menu_tab_index == 2 then
			if menu_vertical_index == #player.items then
				menu_vertical_index = 1
			else
				menu_vertical_index += 1
			end
		elseif menu_tab_index == 3 then
		end
	elseif btnp(2) then
		if menu_vertical_index == 1 then
			if menu_tab_index == 1 then
				menu_vertical_index = #spellbook
			elseif menu_tab_index == 2 then
				menu_vertical_index = #player.items
			elseif menu_tab_index == 3 then
			end
		else
			menu_vertical_index -= 1
		end
	elseif btnp(0) then
		if menu_tab_index == 1 then
			menu_tab_index = #menu_tabs
		else
			menu_tab_index -= 1
		end
		if menu_tab_index == 1 then
			menu_vertical_index = player.spell_index
		else
			menu_vertical_index = 1
		end
	elseif btnp(1) then
		if menu_tab_index == #menu_tabs then
			menu_tab_index = 1
		else
			menu_tab_index += 1
		end
		if menu_tab_index == 1 then
			menu_vertical_index = player.spell_index
		else
			menu_vertical_index = 1
		end
	elseif btnp(5) then
		menu_vertical_index = 1
		menu_tab_index = 1
		set_state("standby")
	elseif btnp(4) then
		if menu_tab_index == 1 then
			if menu_vertical_index <= #player.spells then
				player.spell_index = menu_vertical_index
			elseif menu_vertical_index > #player.spells and spellbook[menu_vertical_index].spcost <= player.sp then
				player.sp -= spellbook[menu_vertical_index].spcost
				acquire_spell(menu_vertical_index - #player.spells)
			end
		elseif menu_tab_index == 2 then
			player.items[menu_vertical_index].effect()
			items_used += 1
			if player.items[menu_vertical_index].count == 1 then
				del(player.items, player.items[menu_vertical_index])
			else
				player.items[menu_vertical_index].count -= 1
			end
		elseif menu_tab_index == 3 then
		end
	end
end

function draw_menu()
	draw_menu_tabs()
	draw_status_menu()
	rect(2, 21, 64, 125, 12)
	rectfill(3, 22, 63, 124, 1)
	rect(64, 21, 125, 75, 12)
	rectfill(65, 22, 124, 124, 1)
	if menu_tab_index == 1 then
		draw_spell_menu()
		draw_spell_description()
	elseif menu_tab_index == 2 then
		draw_item_menu()
		draw_item_description()
	elseif menu_tab_index == 3 then
	end
end

function draw_spell_menu()
	for i = 1, count(spellbook) do
		-- highlight spell looked at
		if i == menu_vertical_index then
			rectfill(3, 22 + 7 * (i - 1), 63, 22 + 6 + 7 * (i - 1), 12)
		elseif i == player.spell_index then
			rectfill(3, 22 + 7 * (player.spell_index - 1), 63, 22 + 6 + 7 * (player.spell_index - 1), 13)
		end
		if i <= #player.spells then
			print(player.spells[i].name, 4, 23 + 7 * (i - 1), 7)
			if player.spells[i].uses < 10 then
				if player.spells[i].maxuses < 10 then
					print(player.spells[i].uses .. "/" .. player.spells[i].maxuses, 52, 23 + 7 * (i - 1), 7)
				else
					print(player.spells[i].uses .. "/" .. player.spells[i].maxuses, 48, 23 + 7 * (i - 1), 7)
				end
			else
				print(player.spells[i].uses .. "/" .. player.spells[i].maxuses, 44, 23 + 7 * (i - 1), 7)
			end
		else
			print(unowned_spells[i - #player.spells].name, 4, 23 + 7 * (i - 1), 5)
			if unowned_spells[i - #player.spells].spcost < 10 then
				print('' .. unowned_spells[i - #player.spells].spcost .. 'sp', 52, 23 + 7 * (i - 1), 5)
			else
				print('' .. unowned_spells[i - #player.spells].spcost .. 'sp', 48, 23 + 7 * (i - 1), 5)
			end
		end
	end
end

function draw_status_menu()
	rect(2, 2, 125, 13, 12)
	rectfill(3, 3, 124, 12, 1)
	rect(2, 2, 125, 13, 12)
	rectfill(3, 3, 124, 12, 1)
	draw_hp(3, 3, 0, 0, 7, false)
	spr(items[5].sprite, 116, 4)
	print(player.sp, 111, 5, 7)
end

function draw_menu_tabs()
	local text_color1, text_color2, background_color1, background_color2 = 6, 7, 1, 12
	if menu_tab_index == 1 then
		text_color1, text_color2, background_color1, background_color2 = 7, 6, 12, 1
	end
	rectfill(3, 13, 64, 21, background_color1)
	rect(2, 13, 65, 21, 12)
	print("spells", 20, 15, text_color1)
	rectfill(65, 13, 125, 21, background_color2)
	rect(64, 13, 125, 21, 12)
	print("items", 85, 15, text_color2)
end

function draw_item_menu()
	for i = 1, count(player.items) do
		-- highlight spell looked at
		if i == menu_vertical_index then
			rectfill(3, 22 + 7 * (i - 1), 63, 22 + 6 + 7 * (i - 1), 12)
		end
		print(player.items[i].name, 4, 23 + 7 * (i - 1), 7)
		if player.items[i].count < 10 then
			print(player.items[i].count, 59, 23 + 7 * (i - 1), 7)
		else
			print(player.items[i].count, 55, 23 + 7 * (i - 1), 7)
		end
	end
end

function draw_item_description()
	local item = player.items[menu_vertical_index]
	if item then
		sspr(item.icon.x, item.icon.y, 8, 8, 66, 23, 16, 16)
		print(item.name, 85, 27, 7)
		cursor(66, 41)
		color(7)
		local description_chunks = chunk_string(15, item.description)
		foreach(description_chunks, print)
	end
end

function draw_spell_description()
	local spell = {}
	if menu_vertical_index <= #player.spells then
		spell = player.spells[menu_vertical_index]
	else
		spell = unowned_spells[menu_vertical_index - #player.spells]
	end
	sspr(spell.icon.x, spell.icon.y, 8, 8, 66, 23, 16, 16)
	print(spell.name, 85, 27, 7)
	cursor(66, 41)
	color(7)
	local description_chunks = chunk_string(15, spell.description)
	foreach(description_chunks, print)
	print('')
	print('uses: ' .. spell.uses .. '/' .. spell.maxuses)
	print('dmg: ' .. spell.dmg)
	print('range: ' .. spell.range)
	if spell.spelltype == "ball" then
		print('radius: ' .. spell.radius)
	elseif spell.spelltype == "bolt" then
	elseif spell.spelltype == "fan" then
		-- angle isn't really relevent to player
		print('spread: ' .. spell.angle, 7)
	end
end

-->8
-- cast
function init_cast()
	points = {}
	target = {}
	targetp = { x = player.x, y = player.y }
	origin = { x = player.x, y = player.y }
end

function update_cast()
	if #points == 0 or origin.x != player.x or origin.y != player.y then
		reset_range()
		points = fov(player.x, player.y, player.spells[player.spell_index].range)
		origin.x = player.x
		origin.y = player.y
		set_closest_target_enemy()
	end
	if #target == 0 then
		if player.spells[player.spell_index].spelltype == "ball" then
			target = get_circle_points(targetp.x, targetp.y, player.spells[player.spell_index].radius)
		elseif player.spells[player.spell_index].spelltype == "bolt" then
			target = line_points(player.x, player.y, targetp.x, targetp.y)
		elseif player.spells[player.spell_index].spelltype == "fan" then
			target = get_cone_points(player.x, player.y, targetp.x, targetp.y, player.spells[player.spell_index].angle, player.spells[player.spell_index].range)
		end
	end
	if btnp(5) then
		reset_range()
		reset_target()
		set_state("standby")
	elseif btnp(4) then
		player.spells[player.spell_index]:cast()
		spells_cast += 1
		reset_range()
		reset_target()
		set_state("turn")
	elseif btnp(0) then
		local newx = targetp.x - 1
		if includes_point(points, { x = newx, y = targetp.y }) then
			targetp.x = newx
		end
		reset_target()
	elseif btnp(1) then
		local newx = targetp.x + 1
		if includes_point(points, { x = newx, y = targetp.y }) then
			targetp.x = newx
		end
		reset_target()
	elseif btnp(2) then
		local newy = targetp.y - 1
		if includes_point(points, { x = targetp.x, y = newy }) then
			targetp.y = newy
		end
		reset_target()
	elseif btnp(3) then
		local newy = targetp.y + 1
		if includes_point(points, { x = targetp.x, y = newy }) then
			targetp.y = newy
		end
		reset_target()
	end
end

function draw_cast()
	highlight_range()
	highlight_target()
end

function highlight_range()
	for point in all(points) do
		mset(point.x, point.y, 3)
	end
end

function highlight_target()
	for point in all(target) do
		local flag = fget(mget(point.x, point.y))
		if flag != 1 then
			mset(point.x, point.y, 5)
		end
	end
	if frame % 30 < 15 then
		mset(targetp.x, targetp.y, 7)
	else
		mset(targetp.x, targetp.y, 5)
	end
end

function set_closest_target_enemy()
	for point in all(points) do
		for mob in all(mobs) do
			if mob != player then
				if mob.x == point.x and mob.y == point.y then
					targetp.x, targetp.y = point.x, point.y
					return
				end
			end
		end
	end
end

function reset_target()
	for point in all(target) do
		local flag = fget(mget(point.x, point.y))
		if flag != 1 then
			mset(point.x, point.y, 2)
		end
	end
	target = {}
end

function reset_range()
	for point in all(points) do
		mset(point.x, point.y, 2)
	end
end

function dmg_mob(damage, targets)
	for mob in all(mobs) do
		if mob != player and includes_point(targets, { x = mob.x, y = mob.y }) then
			mob.hp -= damage
		end
	end
end

function cast_spell(spell)
	spell.uses -= 1
	add(ani_queue, { spell.ani, target })
	dmg_mob(spell.dmg, target)
end

-->8
-- mob
function init_player()
	player = {
		x = 3,
		y = 3,
		ox = 0,
		oy = 0,
		dir = 1,
		sprites = { 240, 241 },
		flipx = false,
		sp = 3,
		hp = 50,
		maxhp = 50,
		spell_index = 1,
		spells = {},
		items = {},
		-- {item=spriteNum, ammt=num}
		collide = false
	}
	acquire_spell(1)
	acquire_spell(1)
	acquire_spell(1)
	add(mobs, player)
	local initial_health_pot = deepcopy(items[8])
	initial_health_pot.count = 1
	local initial_mana_pot = deepcopy(items[9])
	initial_mana_pot.count = 1
	add(player.items, initial_health_pot)
	add(player.items, initial_mana_pot)
end

function update_player()
	if player.hp <= 0 then
		set_state("gameover")
	end
	if btnp(2) then
		update_mob_pos(player, player.x, player.y - 1)
		collect_item(player.x, player.y)
		set_state("turn")
	elseif btnp(3) then
		update_mob_pos(player, player.x, player.y + 1)
		collect_item(player.x, player.y)
		set_state("turn")
	elseif btnp(0) then
		update_mob_pos(player, player.x - 1, player.y)
		collect_item(player.x, player.y)
		set_state("turn")
	elseif btnp(1) then
		update_mob_pos(player, player.x + 1, player.y)
		collect_item(player.x, player.y)
		set_state("turn")
	elseif btnp(4) then
		set_state("menu")
	elseif btnp(5) then
		if player.spells[player.spell_index].uses > 0 then
			set_state("cast")
			init_cast()
		end
	end
end

function update_mob_pos(mob, x, y)
	local collide = detect_collision(x, y)
	local dx, dy = mob.x - x, mob.y - y

	if dy > 0 then
		if not collide then
			mob.y = y
			mob.oy = 8
		elseif mob == player then
			mob.collide = true
		end
		mob.dir = 3
	elseif dy < 0 then
		if not collide then
			mob.y = y
			mob.oy = -8
		elseif mob == player then
			mob.collide = true
		end
		mob.dir = 4
	elseif dx > 0 then
		if not collide then
			mob.x = x
			mob.ox = 8
		elseif mob == player then
			mob.collide = true
		end
		mob.flip = false
		mob.dir = 1
	elseif dx < 0 then
		if not collide then
			mob.x = x
			mob.ox = -8
		elseif mob == player then
			mob.collide = true
		end
		mob.flip = false
		mob.dir = 2
	end
	if mob != player and collide == player then
		player.hp -= mob.meleedmg
		mob.collide = true
	end
end

function move_mob(mob)
	if mob.collide and tframe <= 4 then
		mob.ox += dirx[mob.dir]
		mob.oy += diry[mob.dir]
	else
		if mob.ox < 0 then
			mob.ox += 1
		elseif mob.ox > 0 then
			mob.ox -= 1
		end
		if mob.oy < 0 then
			mob.oy += 1
		elseif mob.oy > 0 then
			mob.oy -= 1
		end
		if mob.ox == 0
				and mob.oy == 0 then
			mob.collide = false
			return true
		else
			return false
		end
	end
end

function draw_mob(mob)
	local sprite = get_frame(frame, mob.sprites, 8)
	spr(sprite, mob.x * 8 + mob.ox, mob.y * 8 + mob.oy, 1, 1, mob.flip)
end

function init_enemies()
	enemyid = 1
	enemy_types = {
		{
			-- bat
			dir = 1,
			ox = 0,
			oy = 0,
			sprites = { 192, 193 },
			flipx = false,
			spell = nil,
			hp = 10,
			maxhp = 10,
			meleedmg = 5,
			collide = false
		},
		{
			-- slime
			dir = 1,
			ox = 0,
			oy = 0,
			sprites = { 194, 195 },
			flipx = false,
			spell = nil,
			hp = 12,
			maxhp = 12,
			meleedmg = 10,
			collide = false
		},
		{
			-- goblin
			dir = 1,
			ox = 0,
			oy = 0,
			sprites = { 196, 197 },
			flipx = false,
			hp = 15,
			spell = nil,
			maxhp = 15,
			meleedmg = 15,
			cooldown = 0,
			collide = false
		},
		{
			-- Tornado
			dir = 1,
			ox = 0,
			oy = 0,
			sprites = { 208, 209 },
			flipx = false,
			hp = 15,
			maxhp = 15,
			spell_index = 1,
			meleedmg = 15,
			cooldown = 0,
			spell = {
				ani = { 176, 177, 178, 179 },
				radius = 0.5,
				range = 4,
				dmg = 5,
				cast = function(self, mob)
					if mob.cooldown == 0 then
						if is_visible(mob.x, mob.y, player.x, player.y, self.range) then
							player.hp -= self.dmg
							add(ani_queue, { self.ani, { { x = player.x, y = player.y } } })
							mob.cooldown = 5
							return true
						end
					else
						mob.cooldown -= 1
						return false
					end
				end
			},
			collide = false
		}
	}

	add_enemy(4, 4, 4)
end

function add_enemy(x, y, type)
	local id = enemyid + 1
	local baseenemy = enemy_types[type]
	local enemy = shallowcopy(baseenemy)
	enemy.id = id
	enemy.x = x
	enemy.y = y
	add(mobs, enemy)
	enemyid = id
end

function update_enemies()
	for mob in all(mobs) do
		if mob.hp <= 0 then
			enemies_killed += 1
			del(mobs, mob)
		else
			local casted = false
			if mob.spell then
				casted = mob.spell:cast(mob)
			end
			if not casted then
				update_enemy_pos(mob)
			end
		end
	end
end

function update_enemy_pos(mob)
	if mob != player then
		local x, y = getcloser(mob.x, mob.y, player.x, player.y)
		update_mob_pos(mob, x, y)
	end
end

function draw_enemy_health()
	for mob in all(mobs) do
		if mob != player then
			if mob.collide then
				spr(176, mob.x * 8, mob.y * 8 + 1)
				line(mob.x * 8 + 1, mob.y * 8 + 7, mob.x * 8 + 6, mob.y * 8 + 7, 0)
				line(mob.x * 8 + 1, mob.y * 8 + 7, mob.x * 8 + mob.hp / mob.maxhp * 6, mob.y * 8 + 7, 8)
			else
				spr(176, mob.x * 8 + mob.ox, mob.y * 8 + 1 + mob.oy)
				line(mob.x * 8 + 1 + mob.ox, mob.y * 8 + 7 + mob.oy, mob.x * 8 + 6 + mob.ox, mob.y * 8 + 7 + mob.oy, 0)
				line(mob.x * 8 + 1 + mob.ox, mob.y * 8 + 7 + mob.oy, mob.x * 8 + mob.hp / mob.maxhp * 6 + mob.ox, mob.y * 8 + 7 + mob.oy, 8)
			end
		end
	end
end

-->8
--map gen
function init_world()
	read_room_options()
	generate_world()
	player.x, player.y = get_rand_open_tile()
	generate_enemies()
	generate_items()
end

function read_room_options()
	rooms = {}
	for i = 0, 127, 8 do
		add(rooms, {})
		for x = i, i + 7 do
			add(rooms[#rooms], {})
			for y = 32, 39 do
				local color = sget(x, y)
				local current = rooms[#rooms]
				if color == 5 then
					add(current[#current], rnd(walls))
				elseif color == 7 then
					add(current[#current], 2)
				end
			end
		end
	end
end

function generate_world()
	local room1 = rnd(rooms)
	local room2 = rnd(rooms)
	local room3 = rnd(rooms)
	local room4 = rnd(rooms)
	for x = 1, 8 do
		local ystrip1 = room1[x]
		local ystrip2 = room2[x]
		local ystrip3 = room3[x]
		local ystrip4 = room4[x]
		for y = 1, 8 do
			mset(x - 1, y - 1, ystrip1[y])
			mset(x - 1, y + 7, ystrip2[y])
			mset(x + 7, y - 1, ystrip3[y])
			mset(x + 7, y + 7, ystrip4[y])
		end
	end
	for i = 0, 15 do
		mset(i, 0, rnd(walls))
		mset(0, i, rnd(walls))
		mset(i, 15, rnd(walls))
		mset(15, i, rnd(walls))
	end
end

function get_rand_open_tile()
	local x, y, is_open = -1, -1, false
	while not is_open do
		x, y = flr(rnd(13)) + 1, flr(rnd(13)) + 1
		if mget(x, y) == 2 then
			is_open = true
		end
	end
	return x, y
end

function generate_enemies()
	for i = 1, floor do
		local x, y = get_rand_open_tile()
		while x == player.x and y == player.y do
			x, y = get_rand_open_tile()
		end
		-- TODO: randomize based on floor
		add_enemy(x, y, flr(rnd(min(floor, #enemy_types))) + 1)
	end
end

function generate_items()
	-- sp
	for i = 1, 3 do
		local x, y = get_rand_open_item_tile()
		add_item(x, y, 5)
	end
	-- upgrade
	local upgradex, upgradey = get_rand_open_item_tile()
	-- TODO: update with flr(rnd(max_upgrade_index))+1
	add_item(upgradex, upgradey, flr(rnd(3)) + 1)
	-- consumable
	local consumablex, consumabley = get_rand_open_item_tile()
	add_item(consumablex, consumabley, flr(rnd(2) + 8))
	-- portal
	local portalx, portaly = get_rand_open_item_tile()
	add_item(portalx, portaly, 6)
end

function get_rand_open_item_tile()
	local x, y = get_rand_open_tile()
	while x == player.x and y == player.y or includes_point(floor_items, { x = x, y = y }) do
		x, y = get_rand_open_tile()
	end
	return x, y
end

-->8
-- spellbook
function init_spellbook()
	spelltypes = { "ball", "bolt", "fan" }
	spellbook = {
		{
			name = "sparks",
			spcost = 1,
			maxuses = 15,
			uses = 15,
			description = "sparks fizzle from your staff",
			icon = { x = 0, y = 64 },
			ani = { 160, 161, 162, 163 },
			spelltype = spelltypes[1],
			radius = 0.5,
			range = 4,
			dmg = 0,
			cooldown = 3,
			cast = cast_spell
		},
		--different heal levels that cause enemy status effects
		--different shield levels
		--direct damage spells
		{
			name = "holy bolt",
			spcost = 1,
			maxuses = 30,
			uses = 3,
			icon = { x = 8, y = 64 },
			description = "deals 8 dmg",
			spelltype = spelltypes[2],
			ani = { 144, 145, 146, 147 },
			range = 6,
			radius = 1,
			dmg = 8,
			cast = cast_spell
		},
		{
			name = "fire fan",
			spcost = 3,
			maxuses = 15,
			uses = 15,
			description = "fire but fan",
			icon = { x = 32, y = 64 },
			ani = { 148, 149, 150, 151 },
			spelltype = spelltypes[3],
			-- in fan type spells radius is an angle in degrees
			angle = 30,
			range = 4,
			dmg = 5,
			cast = cast_spell
		},
		{
			name = "fire ball",
			spcost = 1,
			maxuses = 9,
			uses = 9,
			description = "fire but ball",
			icon = { x = 40, y = 64 },
			ani = { 148, 149, 150, 151 },
			spelltype = spelltypes[1],
			radius = 2,
			range = 4,
			dmg = 5,
			cast = cast_spell
		},
		{
			name = "teleport",
			spcost = 3,
			maxuses = 5,
			uses = 5,
			description = "teleport or swap places with an enemy",
			icon = { x = 48, y = 64 },
			ani = { 152, 153, 154, 155 },
			spelltype = spelltypes[1],
			radius = 0.5,
			range = 4,
			dmg = 0,
			cast = function(spell)
				spell.uses -= 1
				add(target, { x = player.x, y = player.y })
				add(ani_queue, { spell.ani, target })
				dmg_mob(spell.dmg, target)
				local x, y = player.x, player.y
				for mob in all(mobs) do
					if mob != player and includes_point(target, { x = mob.x, y = mob.y }) then
						player.x, player.y = mob.x, mob.y
						mob.x, mob.y = x, y
					end
				end
				if player.x == x and player.y == y then
					player.x, player.y = target[1].x, target[1].y
				end
				collect_item(player.x, player.y)
			end
		}
	}
	unowned_spells = deepcopy(spellbook)
end

function acquire_spell(unowned_spell_index)
	local spell = unowned_spells[unowned_spell_index]
	add(player.spells, spell)
	del(unowned_spells, spell)
end

__gfx__
000000007666666600000000ccccccccccccccccbbbbbbbbbbbbbbbb333333330000000000000000000000000000000000000000000000000000000000000000
000000006dddddd100000000cccccccccdddddd1bbbbbbbbbdddddd1333333330000000000000000000000000000000000000000000000000000000000000000
007007006d1111d100000000cccccccccd1111d1bbbbbbbbbd1111d1333333330000000000000000000000000000000000000000000000000000000000000000
000770006d1dd6d100000000cccccccccd1ddcd1bbbbbbbbbd1ddbd1333333330000000000000000000000000000000000000000000000000000000000000000
000770006d1dd6d100000000cccccccccd1ddcd1bbbbbbbbbd1ddbd1333333330000000000000000000000000000000000000000000000000000000000000000
007007006d6667d100000000cccccccccdccccd1bbbbbbbbbdbbbbd1333333330000000000000000000000000000000000000000000000000000000000000000
000000006dddddd1000000d0cccccccccdddddd1bbbbbbbbbdddddd1333333330000000000000000000000000000000000000000000000000000000000000000
000000001111111100000000cccccccc11111111bbbbbbbb11111111333333330000000000000000000000000000000000000000000000000000000000000000
7666666d7666666d7666666d7666616d7666666d7665666d7666666d6dddddd60000000000000000000000000000000000000000000000000000000000000000
6dddddd56dddddd56dddddd56ddd51655dddddd56dd1ddd56dddddd5d6dddd650000000000000000000000000000000000000000000000000000000000000000
6d1111d56dddddd56ddd6dd56ddd16d5616dddd56d516dd56d6115d5dd6666550000000000000000000000000000000000000000000000000000000000000000
6d1dd6d56dddddd56ddd16d56dd516d5651dddd56d1016d56d1156d5dd6666550000000000000000000000000000000000000000000000000000000000000000
6d1dd6d56dddddd56ddd51d16d516dd56516ddd5651001d56d1566d5dd6666550000000000000000000000000000000000000000000000000000000000000000
6d6667d56dddddd56ddd15516d16ddd56d5116d5610001656d5667d5dd6666550000000000000000000000000000000000000000000000000000000000000000
6dddddd56dddddd56dd551106516ddd56dd55165610000156dddddd5d15555d50000000000000000000000000000000000000000000000000000000000000000
d5555551d5555551d5111000d5155551d511111110000001d55555511555555d0000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07700770007777000777777007777770002222000022220000077000000770000007700000077000000000000000000000000000000000000000000000000000
7887788707bbbb700744447007444470002dd200002cc20000788700007cc70000722700007bb700000000000000000000000000000000000000000000000000
788888877bbbbbb7007777000077770002dd7d2002cc7c200788887007cccc700722227007bbbb70000000000000000000000000000000000000000000000000
788888877bbbbbb70788887007cccc7002dd7d2002cc7c20788888877cccccc7722222277bbbbbb7000000000000000000000000000000000000000000000000
078888707bbbbbb70788887007cccc7002ddd72002ccc72077788777777cc77777722777777bb777000000000000000000000000000000000000000000000000
078888707bbbbbb70788887007cccc7002dd7d2002cc7c2000788700007cc70000722700007bb700000000000000000000000000000000000000000000000000
0078870007bbbb700788887007cccc70002dd200002cc20000788700007cc70000722700007bb700000000000000000000000000000000000000000000000000
00077000007777000077770000777700002222000022220000777700007777000077770000777700000000000000000000000000000000000000000000000000
55577555555775555557755555577555555775555557755555577555555775555557755555577555555775555557755555577555555775555557755555577555
57777775555775555777777557777775577777755777777557777775577777755777777557777775557777555577775555777755557777555557777557777555
57777775555775555757777557777575577755755755777557577575575555755777777557755775577777755777577557777775577577755557777557777555
77777777777777777777777777777777777775777757777777577577777777777757757777777777777775777777757777577777775777777777777777777777
77777777777777777777777777777777775777777777757777577577777777777757757777777777775777777757777777777577777775777777777777777777
57777775555775555777757557577775575577755777557557577575575555755777777557755775577777755775777557777775577757755777755555577775
57777775555775555777777557777775577777755777777557777775577777755777777557777775557777555577775555777755557777555777755555577775
55577555555775555557755555577555555775555557755555577555555775555557755555577555555775555557755555577555555775555557755555577555
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00066666660000000000000000000000060000060000060000000000000000000000000000000000000000000000000000000000000000000000000000000000
00600000066000000000000000000000660000660000660000000000000000000000000000000000000000000000000000000000000000000000000000000000
06006000006006000000000000000000660000660000660060000000000000000000000000000000000000000000000000000000000000000000000000000000
66006000006066000000000000000000660000660000660660000000000000000000000000000000000000000000000000000000000000000000000000000000
66606000006060000066600000666000660000660000660600006666666000000000000000000000000000000000000000000000000000000000000000000000
06006000066000000600060006006600660000660000660000066666666000000000000000000000000000000000000000000000000000000000000000000000
00006000660006006000066060000660660000660000660060000000060000000000000000000000000000000000000000000000000000000000000000000000
00006006600066006000000060000060660000660000660660000000600000000000000000000000000000000000000000000000000000000000000000000000
00006066000066006000000060000060660000660000660660006606000000000000000000000000000000000000000000000000000000000000000000000000
00006060000066006000000060000060660000660000660660000060000000000000000000000000000000000000000000000000000000000000000000000000
00006000000066006000006060000060660000660000660660000606600000000000000000000000000000000000000000000000000000000000000000000000
00006000000066006600006066000060660006660006600660006000000000000000000000000000000000000000000000000000000000000000000000000000
00006000000066600660060006600600066060066060000666066666666000000000000000000000000000000000000000000000000000000000000000000000
00006000000006000066600000666000006600006600000060066666660000000000000000000000000000000000000000000000000000000000000000000000
0a000a000777777000aaaa0000bbbb0008080008000880000dddddd0000000000000000000000000000000000000000000000000000000000000000000000000
aaa00a00777767770a00a0a00b0000b08000808000888800d000000d000000000000000000000000000000000000000000000000000000000000000000000000
0a00aaa077766770a00aaa0ab000000b88088088008898000dddddd0000000000000000000000000000000000000000000000000000000000000000000000000
000aaaaa077aa000a000a00ab000000b898888980889988000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000aaa0000aa000a00a000ab000000ba889988a889a99800eeeeee0000000000000000000000000000000000000000000000000000000000000000000000000
00a00a000000aa00a0aaa00ab000000b0a8888a0899aa988e000000e000000000000000000000000000000000000000000000000000000000000000000000000
0aaa0a0000000a000a0a00a00b0000b000a88a0089a9a9980eeeeee0000000000000000000000000000000000000000000000000000000000000000000000000
00a0000000000a0000aaaa0000bbbb00000aa00008a77a8000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000000a00a000aa0a0a00a00a0a000000000000000000000000000088000000000000dddddd0d000000d0dddddd000000000000000000000000000000000
a000000000a00a000a00a0a00a00a0a0000000000000000000008000008888000dddddd0d000000d0dddddd00000000000000000000000000000000000000000
a00000000aa0aa000a00a0a0aa0aa0a000000000000000000008888000889800d000000d0dddddd0000000000eeeeee000000000000000000000000000000000
aa0000000a00a0000a00a0a0a00a0a00000000000000880000089980088998800dddddd0000000000eeeeee0e000000e00000000000000000000000000000000
0aa000000a00a0000aa0a00aa0aa0a0a000000000008880008889980889a9980000000000eeeeee0e000000e0eeeeee000000000000000000000000000000000
00a000000a0a000000a0a00aa0a00a0a000088000088998008999998899aa9880eeeeee0e000000e0eeeeee00000000000000000000000000000000000000000
00a00000aa0a00000aa0aa0a00a0a0aa00088800008999800899aaa889a9a998e000000e0eeeeee0000000000dddddd000000000000000000000000000000000
00a00000a0aa00000a000a0000a0a0a0000898000089aa80089aa7a808a77a800eeeeee0000000000dddddd0d000000d00000000000000000000000000000000
00000000000000000000000000aaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000aaaa000a0000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000aa0000a0000a0a000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aa00000a00a000a0000a0a000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aa00000a00a000a0000a0a000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000aa0000a0000a0a000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000aaaa000a0000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000aaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000007777760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000777600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000777677000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007776000076770000067700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007700000767000007760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000600000007000000060000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800800000000000000900000000000000000000033330000000000000000000000000001111000088008800880088000000bbb0000b1130000770000000000
008888000080080000099000000090000033330003333330b83000000b8300000011110019191000800000088080080800000013000000bb0708787000000000
02a8a8200088880000979900000990000333333003a33a30bbb300000bbb300001919100111110008080080888000088000003310000031b0707576000000000
2288822222a8a822097799900097990003a33a360033330000b30000000b3000011111020000100008000080087007800bbb33b1000bbb130700707000000000
00288200028882209999999909779990663333060565565600b30030000b3003000dd10100dd10020870078000888800b575b1b000b575b1058d070800000000
0000202000288200989999899899998966655653665555360b30000b00b3003b00122101012210110088880008088080b707b13000b707b307d0707000000000
0000000000002020091111909911119905555550665005030b33333b00b3333b00022c100022c1100808808008000080b575b13000b575b30700404000000000
00000000000000000099990009999990030000300030030000bbbbb000bbbbb0000101000010100080800808808008080bbb3300000bbb000007505700000000
67777677776777760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02800820028008200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06776770077677600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00667700007766000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00067700000776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000700000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000066660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000600066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000006000006600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000066000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000066000000000066600000600600006000006660000066600006000060006660000606600000000000000000000000000000000000000000
00000000000000000066000000000600660006606660066600060066000600660066000660060066006660660000000000000000000000000000000000000000
00000000000000000066000000606000066006660066600660600006606000066066000660600006606600066000000000000000000000000000000000000000
00000000000000000066000006606000006006600066000660600006006000006066000660600006006600000000000000000000000000000000000000000000
60777700007777000066000666606000006006600066000660600060006000006066000660600060006600000000000000000000000000000000000000000000
a0ffff7060ffff700066000006606000006006600066000660606600006000006066000660606600006600000000000000000000000000000000000000000000
a05f5ff7a05f5ff70066000006606000006006600066000660660000006000006066000660660000006600000000000000000000000000000000000000000000
f0fffff7a0fffff70006600006006600006606600066000660660000606600006066000600660000606600000000000000000000000000000000000000000000
a7777770f07777700000666660000660066606600066000660066006000660060006606000066006006600000000000000000000000000000000000000000000
a07777f0a77777f00000066000000066606006000060000600006660000066600000660000006660006000000000000000000000000000000000000000000000
a0777770a07777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777770a07777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
78868666666666666666666666666666666666667666666676666666766666667666666676666666766666667666666676666666766666667666666600000000
8dddd600000000000000000000000000006dddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd100000000
88811606606600666066600060666066606111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d100000000
6d8dd606666600600060600600600060606dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d100000000
881dd606666600666060600600666060606dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d100000000
6d666600666000006060600600006060606667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d100000000
6dddd600060000666066606000666066606dddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd100000060
11111600000000000000000000000000006111111111111111111111111111111111111111111111111111111111111111111111111111111111111100000000
76666666666666666666666666666666666000000000000000000000766666660000000000000000000000000000000000000000000000007666666600000000
6dddddd10000000000000000000000000000000000000000000000006dddddd10000000000000000000000000000000000000000000000006dddddd100000000
6d1111d10000000000000000000000000000000000000000000000006d1111d10000000000000000000000000000000000000000000000006d1111d100000000
6d1dd6d10000000000000000000000000000000000000000000000006d1dd6d10000000000000000000000000000000000000000000000006d1dd6d100000000
6d1dd6d10000000000000000000000000000000000000000000000006d1dd6d10000000000000000000000000000000000000000000000006d1dd6d100000000
6d6667d10000000000000000000000000000000000000000000000006d6667d10000000000000000000000000000000000000000000000006d6667d100000000
6dddddd10000006000000060000000600000006000000060000000606dddddd10000006000000060000000600000006000000060000000606dddddd100000060
11111111000000000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000000000001111111100000000
76666666000000007666666600000000000000000000000000000000766666660000000000000000000000000000000000000000766666667666666600000000
6dddddd1000000006dddddd1000000000000000000000000000000006dddddd100000000000000000000000000000000000000006dddddd16dddddd100000000
6d1111d1000000006d1111d1000000000000000000000000000000006d1111d100000000000000000000000000000000000000006d1111d16d1111d100000000
6d1dd6d1000000006d1dd6d1000000000000000000000000000000006d1dd6d100000000000000000000000000000000000000006d1dd6d16d1dd6d100000000
6d1dd6d1000000006d1dd6d1000000000000000000000000000000006d1dd6d100000000000000000000000000000000000000006d1dd6d16d1dd6d100000000
6d6667d1000000006d6667d1000000000000000000000000000000006d6667d100000000000000000000000000000000000000006d6667d16d6667d100000000
6dddddd1000000606dddddd1000000600000006000000060000000606dddddd100000060000000600000006000000060000000606dddddd16dddddd100000060
11111111000000001111111100000000000000000000000000000000111111110000000000000000000000000000000000000000111111111111111100000000
76666666000000000000000000000000000000000000000000000000000000000000000000000000766666660000000000000000000000000000000000000000
6dddddd10000000000000000000000000000000000000000000000000000000000000000000000006dddddd10000000000000000000000000000000000000000
6d1111d10000000000000000000000000000000000000000000000000000000000000000000000006d1111d10000000000000000000000000000000000000000
6d1dd6d10000000000000000000000000000000000000000000000000000000000000000000000006d1dd6d10000000000000000000000000000000000000000
6d1dd6d10000000000000000000000000000000000000000000000000000000000000000000000006d1dd6d10000000000000000000000000000000000000000
6d6667d10000000000000000000000000000000000000000000000000000000000000000000000006d6667d10000000000000000000000000000000000000000
6dddddd10000006000000060000000600000006000000060000000600000006000000060000000606dddddd10000006000000060000000600000006000000060
11111111000000000000000000000000000000000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000
76666666000000000000000000000000000000000000000000000000000000000000000000000000766666660000000000000000000000000000000000000000
6dddddd10000000000000000000000000000000000000000000000000000000000000000000000006dddddd10000000000000000000000000000000000000000
6d1111d10000000000000000000000000000000000000000000000000000000000000000000000006d1111d10000000000000000000000000000000000000000
6d1dd6d10000000000000000000000000000000000000000000000000000000000000000000000006d1dd6d10000000000000000000000000000000000000000
6d1dd6d10000000000000000000000000000000000000000000000000000000000000000000000006d1dd6d10000000000000000000000000000000000000000
6d6667d10000000000000000000000000000000000000000000000000000000000000000000000006d6667d10000000000000000000000000000000000000000
6dddddd10000006000000060000000600000006000000060000000600000006000000060000000606dddddd10000006000000060000000600000006000000060
11111111000000000000000000000000000000000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000
76666666000000000000000000000000000000007666666600000000766666660000000000000000000000000000000000000000766666667666666600000000
6dddddd1000000000000000000000000000000006dddddd1000000006dddddd100000000000000000000000000000000000000006dddddd16dddddd100000000
6d1111d1000000000000000000000000000000006d1111d1000000006d1111d100000000000000000000000000000000000000006d1111d16d1111d100000000
6d1dd6d1000000000000000000000000000000006d1dd6d1000000006d1dd6d100000000000000000000000000000000000000006d1dd6d16d1dd6d100000000
6d1dd6d1000000000000000000000000000000006d1dd6d1000000006d1dd6d100000000000000000000000000000000000000006d1dd6d16d1dd6d100000000
6d6667d1000000000000000000000000000000006d6667d1000000006d6667d100000000000000000000000000000000000000006d6667d16d6667d100000000
6dddddd1000000600000006000000060000000606dddddd1000000606dddddd100000060000000600000006000000060000000606dddddd16dddddd100000060
11111111000000000000000000000000000000001111111100000000111111110000000000000000000000000000000000000000111111111111111100000000
76666666000000000000000000000000000000000000000000000000766666660000000000000000000000000000000000000000000000007666666600000000
6dddddd10000000000000000000000000000000000000000000000006dddddd10000000000000000000000000000000000000000000000006dddddd100000000
6d1111d10000000000000000000000000000000000000000000000006d1111d10000000000000000000000000000000000000000000000006d1111d100000000
6d1dd6d10000000000000000000000000000000000000000000000006d1dd6d10000000000000000000000000000000000000000000000006d1dd6d100000000
6d1dd6d10000000000000000000000000000000000000000000000006d1dd6d10000000000000000000000000000000000000000000000006d1dd6d100000000
6d6667d10000000000000000000000000000000000000000000000006d6667d10000000000000000000000000000000000000000000000006d6667d100000000
6dddddd10000006000000060000000600000006000000060000000606dddddd10000006000000060000000600000006000000060000000606dddddd100000060
11111111000000000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000000000001111111100000000
76666666766666667666666600000000000000007666666676666666766666667666666676666666000000000000000076666666766666667666666600000000
6dddddd16dddddd16dddddd100000000000000006dddddd16dddddd16dddddd16dddddd16dddddd100000000000000006dddddd16dddddd16dddddd100000000
6d1111d16d1111d16d1111d100000000000000006d1111d16d1111d16d1111d16d1111d16d1111d100000000000000006d1111d16d1111d16d1111d100000000
6d1dd6d16d1dd6d16d1dd6d100000000000000006d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d100000000000000006d1dd6d16d1dd6d16d1dd6d100000000
6d1dd6d16d1dd6d16d1dd6d100000000000000006d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d100000000000000006d1dd6d16d1dd6d16d1dd6d100000000
6d6667d16d6667d16d6667d100000000000000006d6667d16d6667d16d6667d16d6667d16d6667d100000000000000006d6667d16d6667d16d6667d100000000
6dddddd16dddddd16dddddd100000060000000606dddddd16dddddd16dddddd16dddddd16dddddd100000060000000606dddddd16dddddd16dddddd100000060
11111111111111111111111100000000000000001111111111111111111111111111111111111111000000000000000011111111111111111111111100000000
76666666000000000000000000000000000000000000000000000000766666660077770000000000000000000000000000000000000000007666666600000000
6dddddd10000000000000000000000000000000000000000000000006dddddd160ffff7000000000000000000000000000000000000000006dddddd100000000
6d1111d10000000000000000000000000000000000000000000000006d1111d1a05f5ff700000000000000000000000000000000000000006d1111d100000000
6d1dd6d10000000000000000000000000000000000000000000000006d1dd6d1a0fffff700000000000000000000000000000000000000006d1dd6d100000000
6d1dd6d10000000000000000000000000000000000000000000000006d1dd6d1f077777000000000000000000000000000000000000000006d1dd6d100000000
6d6667d10000000000000000000000000000000000000000000000006d6667d1a77a77f000000000000000000000000000000000000000006d6667d100000000
6dddddd10000006000000060000000600000006000000060000000606dddddd1a0aaa77000000060000000600000006000000060000000606dddddd100000060
1111111100000000000000000000000000000000000000000000000011111111a07a777700000000000000000000000000000000000000001111111100000000
76666666000000007666666600000000000000007666666600000000766666660000000076666666000000000000000076666666000000007666666600000000
6dddddd1000000006dddddd100000000000000006dddddd1000000006dddddd1000000006dddddd100000000000000006dddddd1000000006dddddd100000000
6d1111d1000000006d1111d100000000000000006d1111d1000000006d1111d1000000006d1111d100000000000000006d1111d1000000006d1111d100000000
6d1dd6d1000000006d1dd6d100000000000000006d1dd6d1000000006d1dd6d1000000006d1dd6d100000000000000006d1dd6d1000000006d1dd6d100000000
6d1dd6d1000000006d1dd6d100000000000000006d1dd6d1000000006d1dd6d1000000006d1dd6d100000000000000006d1dd6d1000000006d1dd6d100000000
6d6667d1000000006d6667d100000000000000006d6667d1000000006d6667d1000000006d6667d100000000000000006d6667d1000000006d6667d100000000
6dddddd1000000606dddddd100000060000000606dddddd1000000606dddddd1000000606dddddd100000060000000606dddddd1000000606dddddd100000060
11111111000000001111111100000000000000001111111100000000111111110000000011111111000000000000000011111111000000001111111100000000
76666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007666666600000000
6dddddd1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006dddddd100000000
6d1111d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006d1111d100000000
6d1dd6d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006d1dd6d100000000
6d1dd6d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006d1dd6d100000000
6d6667d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006d6667d100000000
6dddddd1000000600000006000000060000000600000006000000060000000600000006000000060000000600000006000000060000000606dddddd100000060
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100000000
76666666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007666666600000000
6dddddd1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006dddddd100000000
6d1111d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006d1111d100000000
6d1dd6d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006d1dd6d100000000
6d1dd6d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006d1dd6d100000000
6d6667d1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006d6667d100000000
6dddddd1000000600000006000000060000000600000006000000060000000600000006000000060000000600000006000000060000000606dddddd100000060
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111100000000
76666666000000000000000000000000000000000000000000000000766666660000000076666666000000000000000000000000000000007666666600000000
6dddddd10000000000000000000000000000000000000000000000006dddddd1000000006dddddd1000000000000000000000000000000006dddddd100000000
6d1111d10000000000000000000000000000000000000000000000006d1111d1000000006d1111d1000000000000000000000000000000006d1111d100000000
6d1dd6d10000000000000000000000000000000000000000000000006d1dd6d1000000006d1dd6d1000000000000000000000000000000006d1dd6d100000000
6d1dd6d10000000000000000000000000000000000000000000000006d1dd6d1000000006d1dd6d1000000000000000000000000000000006d1dd6d100000000
6d6667d10000000000000000000000000000000000000000000000006d6667d1000000006d6667d1000000000000000000000000000000006d6667d100000000
6dddddd10000006000000060000000600000006000000060000000606dddddd1000000606dddddd1000000600000006000000060000000606dddddd100000060
11111111000000000000000000000000000000000000000000000000111111110000000011111111000000000000000000000000000000001111111100000000
76666666000000000000000000000000000000000000000000000000766666660000000000000000000000000000000000000000000000007666666600000000
6dddddd10000000000000000000000000000000000000000000000006dddddd10000000000000000000000000000000000000000000000006dddddd100000000
6d1111d10000000000000000000000000000000000000000000000006d1111d10000000000000000000000000000000000000000000000006d1111d100000000
6d1dd6d10000000000000000000000000000000000000000000000006d1dd6d10000000000000000000000000000000000000000000000006d1dd6d100000000
6d1dd6d10000000000000000000000000000000000000000000000006d1dd6d10000000000000000000000000000000000000000000000006d1dd6d100000000
6d6667d10000000000000000000000000000000000000000000000006d6667d10000000000000000000000000000000000000000000000006d6667d100000000
6dddddd10000006000000060000000600000006000000060000000606dddddd10000006000000060000000600000006000000060000000606dddddd100000000
11111111000000000000000000000000000000000000000000000000111111110000000000000000000000000000000000000000000000001111111100000000
76666666766666667666666676666666766666667666666676666666766666667666666676666666766666667666666676666666766666667666666600000000
6dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd100000000
6d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d16d1111d100000000
6d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d100000000
6d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d16d1dd6d100000000
6d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d16d6667d100000000
6dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd16dddddd100000000
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000060000000600000006000000060000000600000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0001020001000100000000000000000001010101010101010000000000000000000000000000000000000000000000000404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0101010101010101010101010101010102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020202020201010202020202020102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102010202020201010202020201020102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020202020202020201020202020102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020202020202020201020202020102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020202010201010202020201020102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020202020201010202020202020102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010202010101010102020101010102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010202010101010102020101010102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102010202010201010102020102020102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020202020202020202020202020102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020202020202020202020202020102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020202020201010102020202020102020202020202020202020202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020202020201010202020202020100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0102020202020201010202020202020100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
