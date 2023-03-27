pico-8 cartridge // http://www.pico-8.com
version 38
__lua__
-- game state
function _init()
	frame = 0
	gamestates = {"standby","turn","collide","menu","cast"}
	gamestate = gamestates[1]
	walls = {0}
	item_sprites = {48,49,50,51}
	items = {}
	add(items,{x=4,y=4,id=2})
	
	dirx={-1,1,0,0,1,1,-1,-1}
	diry={0,0,-1,1,-1,1,1,-1}
	debug = {}
	--expected data {{{sprites}{{x,y},...}},...}
	ani_queue = {}
	mobs = {}
	tframe = -1
	move_complete = true
	ani_complete = true

	init_spellbook()
	init_player()
	init_cast()
	init_enemies()
	init_menu()
end

function _update()
	cls()
	frame += 1
	if gamestate == "standby" then
		update_player()
	elseif gamestate== "turn" then
		move_complete = move_all_mobs()
		tframe+=1
		if move_complete and ani_complete then
			set_state("standby")
		end
		--move enemies
	elseif gamestate=="menu" then
		update_menu()
	elseif gamestate=="cast" then
		update_cast()
	end
end

function _draw()
	map(0)
	-- print(gamestate,1,15,8)
	draw_items()
	draw_all_mobs()
	draw_enemy_health()
	draw_hp(0,0,0,6,6,true)
	draw_selected_spell()
	draw_debug()
	if gamestate == "turn" then
		ani_complete = animations(tframe)
	elseif gamestate == "menu" then
		draw_menu()
	elseif gamestate=="cast" then
		draw_cast()
	end
end

function set_state(state)
	if state == "standby" then
		gamestate = state
		tframe = -1
	elseif state == "turn" then
		update_enemies()
		gamestate = state
		tframe=1
	elseif state == "menu" then
		spell_menu_index = player.spell_index+1
		gamestate = state
	elseif state == "cast" then
		gamestate = state
	end
end

function draw_hp(x,y,cb,co,ct,withoutline)
	if withoutline then
		rectfill(x,y, x+get_hp_draw_offset()+29,y+8,cb)
		rect(x,y,x+get_hp_draw_offset()+29,y+8,co)
	end
	print("♥"..mobs[1].hp.."/"..mobs[1].maxhp, x+1,y+2,ct)
end

function draw_selected_spell()
	rectfill(118,0,127,9,1)
	rect(118,0,127,9,12)
	local spell = mobs[1].spells[mobs[1].spell_index]
	sspr(spell.icon.x,spell.icon.y,8,8,119,1,8,8)
end

function draw_debug()
	cursor(0,10)
	color(8)
	for txt in all(debug) do
		print(txt)
	end
end

function animations(tframe)
	local unfinished = false
	if tframe < 0 then
		return true
	end
	for pair in all(ani_queue) do
		local sprite = get_frame(tframe-1,pair[1],2)
		for point in all(pair[2]) do
			spr(sprite,point.x*8,point.y*8,1,1)
		end	
		if sprite == pair[1][#pair[1]] or #pair[2]==0 then
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

function collect_item(x,y)
	local item = false
	for i in all(items) do
		if i.x == x and i.y == y then
			item = i
		end
	end
	if item then
		if item.id == 1 then
			player.maxhp+=25
			player.hp+=25
		else
			player.items[item.id-1] += 1
		end
		del(items,item)
	end
end

function use_item(item_index)
	if player.items[item_index] > 0 then
		player.items[item_index] -= 1
		if item_index == 2 then
			player.hp = player.maxhp
		elseif item_index == 3 then
			for spell in all(player.spells) do
				spell.uses = spell.maxuses
			end
		end
	end
end

function draw_items()
	for item in all(items) do
		spr(item_sprites[item.id],item.x*8,item.y*8)
	end
end



-->8
-- helper functions

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

function get_frame(sframe,sprites,speed)
 return	sprites[flr(sframe/speed)%#sprites+1]
end

function detect_collision(mob)
	sprite = mget(mob.x,mob.y)
	if fget(sprite,0) then
			return true
	end
	for m in all(mobs) do
		if m!=mob and mob.x == m.x and mob.y==m.y then
			return m
		end
	end
	return false
end

function detect_collision(x,y)
	sprite = mget(x,y)
	if fget(sprite,0) then
			return true
	end
	for m in all(mobs) do
		if x == m.x and y==m.y then
			return m
		end
	end
	return false
end

function shallowcopy(t)
	local t2 = {}
	for k,v in pairs(t) do
	  t2[k] = v
	end
	return t2
end

function deepcopy(t)
	local t2 = {}
	for k,v in pairs(t) do
		if type(v) == "table" then
			t2[k] = deepcopy(v)
		else
			t2[k] = v
		end
	end
	return t2
end

function fov(x,y,r)
	local dx,dy
	local visible = {}
	for i=0,360 do
		dx=cos(i/360)
		dy=sin(i/360)
		local result = dofov(dx,dy,x,y,r)
		for point in all(result) do
			if not includes_point(visible, point) then
					add(visible,point)
				end
		end
	end
	return visible
end

function dofov(x,y,px,py,r)
	local ox,oy
	local visible = {}
	ox=px+0.5
	oy=py+0.5
	for i=0,r do
		local flag = fget(mget(ox,oy))
		if flag != 1 then
			add(visible,{x=flr(ox),y=flr(oy)})
		else
			break	
		end
		ox+=x
		oy+=y
	end
	return visible
end


function distance(x,y,x1,y1)
	local dx = x1-x
	local dy = y1-y
	return sqrt((dx*dx)+(dy*dy))
end

function in_circle(r,cx,cy,x,y) 
	local xpart=x-cx
	local ypart=y-cy
	local result = (xpart*xpart)+(ypart*ypart)
	return result<=r*r
end

function normalize(x,y)
	local magnitude = flr(sqrt(x*x+y*y))
	return x/magnitude, y/magnitude
end

function get_circle_points(cx,cy,r)
	local circp = {}
	add(circp,{x=cx,y=cy})	
	for x=cx-r,cx do
		for y=cy-r, cy do
			if(((x-cx)*(x-cx)+(y-cy)*(y-cy))<=r*r) then
				xsym = cx - (x-cx)
				ysym = cy - (y-cy)
				add(circp, {x=x,y=y})
				add(circp, {x=x,y=ysym})
				add(circp, {x=xsym, y=y})
				add(circp, {x=xsym, y=ysym})
			end
		end
	end
	return circp
end

--TODO: do better
function get_line_points(x1,y1,x2,y2)
	local path = {{x=x1,y=y1}}
	local i=2
	while not includes_point(path, {x=x2,y=y2}) do 
		local x,y = getcloser(path[i-1].x, path[i-1].y, x2,y2)
		add(path,{x=x,y=y})
		i+=1
	end
	return path
end

function line_points(x1,y1,x2,y2)
	local r = distance(x1,y1,x2,y2)
	local dx,dy
	local visible = {}
	local sgnx, sgny = sgn(x2-x1),sgn(y2-y1)
	local startang, endang
	if sgnx==-1 then
		if sgny == -1 then
			startang = 90
			endang = 180
		else
			startang = 180
			endang = 270
		end
	else
		if sgny == -1 then
			startang=0
			endang=90
		else
			startang=270
			endang=360
		end
	end
	for i=startang,endang do
		dx=cos(i/360)
		dy=sin(i/360)
		local result = dofov(dx,dy,x1,y1,r)
		if includes_point(result,{x=x2,y=y2}) then
			for point in all(result) do
				if not includes_point(visible, point) then
					add(visible,point)
				end
			end
			break
		end
	end
	if #visible < 1 then
		return get_line_points(x1,y1,x2,y2)
	end
	return visible
end

function inTriangle(x,y,x1,y1,x2,y2,px,py)
	local s1 = y2-y
	local s2 = x2-x
	local s3 = y1-y
	local s4 = py-y
	local w1 = (x*s1+s4*s2-px*s1)/(s3*s2-(x1-x)*s1)
	local w2 = (s4-w1*s4)/s1
	return w1>=0 and w2 >=0 and (w1+w2)<=1
end

-- wa is width in terms of degrees
function get_cone_points(x,y,x1,y1,wa,r)
	local visible = {}
	local deltax,deltay = x1-x,y1-y
	local angle = atan2(deltax,deltay)
	local degang = angle*360
	local s = degang - wa/2
	local e = degang + wa/2
	local countdir = sgn(e-s)
	for i=s,e,countdir do
		local dx=cos(i/360)
		local dy=sin(i/360)
		local result = dofov(dx,dy,x,y,r)
		for point in all(result) do
			if not includes_point(visible, point) then
				add(visible,point)
			end
		end
	end
	del(visible,{x=x,y=y})
	return visible
end


function includes_point(array, v)
	if #array == 0 then
		return false
	end
	for item in all(array) do
		if item == v then
			return true
		elseif item.x == v.x and item.y == v.y then
			return true
		end
	end
	return false
end

function getcloser(x1,y1,x2,y2)
	local bdst,bx,by =999,0,0
	for i=1, 4 do
		local dx,dy = dirx[i],diry[i]
		local dist = distance(x1+dx,y1+dy,x2,y2)
		if dist<bdst and fget(mget(x1+dx,y1+dy))!=1 then
			bdst = dist
			bx=x1+dx
			by=y1+dy
		end
	end
	return bx,by
end

-->8
-- menu

function init_menu()
	spell_menu_index = 1
	upgrade_menu_index=1
	item_menu_index=2
	in_upgrade_menu = false
end

function update_menu()
	if btnp(3) then
		if not in_upgrade_menu then
			if spell_menu_index == #spellbook+1 then
				spell_menu_index=1
				item_menu_index=2
			elseif spell_menu_index==1 then
				item_menu_index=1
				spell_menu_index+=1
			else
				spell_menu_index+=1
			end
		else
			local upgrades = player.spells[spell_menu_index-1].upgrades
			if upgrade_menu_index == #upgrades then
				upgrade_menu_index = 1
			else
				upgrade_menu_index+=1
			end
		end
		
	elseif btnp(2) then
		if not in_upgrade_menu then
			if spell_menu_index == 1 then
				spell_menu_index = #spellbook+1
				item_menu_index=2
			elseif spell_menu_index == 2 then
				spell_menu_index-=1
				item_menu_index=2
			else
				spell_menu_index-=1
			end
		else
			local upgrades = player.spells[spell_menu_index-1].upgrades
			if upgrade_menu_index == 1 then
				upgrade_menu_index = #upgrades
			else
				upgrade_menu_index-=1
			end
		end
		
	elseif btnp(0) then
		if spell_menu_index==1 then
			if item_menu_index==2 then
				item_menu_index=3
			else
				item_menu_index-=1
			end
		elseif spell_menu_index<=#player.spells+1 then
			in_upgrade_menu = not in_upgrade_menu
		end
	elseif btnp(1) then
		if spell_menu_index==1 then
			if item_menu_index==3 then
				item_menu_index=2
			else
				item_menu_index+=1
			end
		elseif spell_menu_index<=#player.spells+1 then
			in_upgrade_menu = not in_upgrade_menu
		end
	elseif btnp(5) then
		spell_menu_index=player.spell_index+1
		item_menu_index=1
		set_state("standby")
	elseif btnp(4) then
		--select spell then standby
		if item_menu_index==1 and spell_menu_index>1 and spell_menu_index<=#player.spells+1 then
			player.spell_index = spell_menu_index-1
		elseif spell_menu_index==1 then
			use_item(item_menu_index)
		elseif spell_menu_index>#player.spells and spellbook[spell_menu_index-1].spcost <= player.items[1] then
			player.items[1]-= spellbook[spell_menu_index-1].spcost
			add(player.spells, deepcopy(spellbook[spell_menu_index-1]));
		elseif in_upgrade_menu and player.spells[spell_menu_index - 1].upgrades[upgrade_menu_index].owned == false and player.spells[spell_menu_index - 1].upgrades[upgrade_menu_index].cost<player.items[1] then
			local spell = player.spells[spell_menu_index - 1]
			spell.upgrades[upgrade_menu_index].owned = true
			
			if upgrade_menu_index == 1 then
				spell.dmg += spell.upgrades[1].mod
			elseif upgrade_menu_index == 2 then
				spell.range += spell.upgrades[2].mod
			elseif upgrade_menu_index == 3 then
				spell.uses += spell.upgrades[3].mod
				spell.maxuses += spell.upgrades[3].mod
			end

		end
	end
end

-- todo: add variables for menu
-- colors, and text colors
-- maybe location/size
function draw_menu()
	draw_spell_menu()
	draw_spell_description()
	draw_item_menu()
	draw_spell_upgrades()
end

function draw_spell_menu()
	rect(2,13,64,125,12)
	rectfill(3,14,63,124,1)
	for i=1, count(spellbook) do
		-- highlight spell looked at
		if i==spell_menu_index-1 and frame%30>15 and spell_menu_index!=1 and not in_upgrade_menu then
			rectfill(3,14+7*(i-1),63,14+6+7*(i-1),13)
		elseif i==player.spell_index then
			rectfill(3,14+7*(player.spell_index-1),63,14+6+7*(player.spell_index-1),13)
		end
		if i<=#player.spells then
			print(spellbook[i].name,4,15+7*(i-1),7)
		else
			print(spellbook[i].name,4,15+7*(i-1),5)
		end
		if i<=#player.spells then
			if player.spells[i].uses<10 then
				if player.spells[i].maxuses<10 then
					print(player.spells[i].uses.."/"..player.spells[i].maxuses,52,15+7*(i-1),7)
				else
					print(player.spells[i].uses.."/"..player.spells[i].maxuses,48,15+7*(i-1),7)
				end
			else
				print(player.spells[i].uses.."/"..player.spells[i].maxuses,44,15+7*(i-1),7)
			end
		else
			if spellbook[i].spcost<10 then
				print(''..spellbook[i].spcost..'sp',52,15+7*(i-1),5)
			else
				print(''..spellbook[i].spcost..'sp',48,15+7*(i-1),5)
			end
		end
	end
end

function draw_item_menu()
	rect(2,2,125,13,12)
	rectfill(3,3,124,12,1)
	draw_hp(3,3,0,0,7,false)
	for i=3, #item_sprites do
		if spell_menu_index==1 and i-1==item_menu_index and frame%30<15 then
			rectfill(27+get_hp_draw_offset()+18*(i-2),3,43+get_hp_draw_offset()+18*(i-2),12,13)
		end
		spr(item_sprites[i],34+get_hp_draw_offset()+18*(i-2),4)
		print(player.items[i-1], 29+get_hp_draw_offset()+18*(i-2),5,7)
	end
	spr(item_sprites[2],116,4)
	print(player.items[1], 111,5,7)
end

function draw_spell_description()
	rect(64,13,125,75,12)
	rectfill(65,14,124,74,1)
	local spell = {}
	if spell_menu_index==1 then
		spell = player.spells[player.spell_index]
	elseif spell_menu_index<=#player.spells then
		spell = player.spells[spell_menu_index-1]
	else
		spell = spellbook[spell_menu_index-1]
	end
	sspr(spell.icon.x,spell.icon.y,8,8,66,15,16,16)
	print(spell.name, 88, 19, 7)
	cursor(66,33)
	print(spell.description,7)
	print('')
	print('uses: '..spell.uses..'/'..spell.maxuses, 7)
	print('dmg: '..spell.dmg, 7)
	print('range: '..spell.range,7)
	if spell.spelltype == "ball" then
		print('radius: '..spell.radius, 7)
	elseif spell.spelltype == "bolt" then
		
	elseif spell.spelltype == "fan" then
		-- angle isn't really relevent to player
		print('spread: '..spell.angle,7)
	end
end

function draw_spell_upgrades()
	rect(64,75,125,125,12)
	rectfill(65,76,124,124,1)
	if spell_menu_index > 1 then
		local spell_known = spell_menu_index <= #player.spells
		print('upgrades:',66,77,7)
		local upgrades
		if spell_known then
			upgrades = player.spells[spell_menu_index-1].upgrades
		else
			upgrades = spellbook[spell_menu_index-1].upgrades
		end
		for i=1, #upgrades do
			if i==upgrade_menu_index and frame%30<15 and in_upgrade_menu then
				rectfill(66,83+((i-1)*7),124,88+((i-1)*7),13)
			end
			if upgrades[i].owned then
				print(upgrades[i].name,66,83+((i-1)*7),11)
				print(upgrades[i].cost,121,83+((i-1)*7),11)
			else
				print(upgrades[i].name,66,83+((i-1)*7),7)
				print(upgrades[i].cost,121,83+((i-1)*7),7)
			end
		end
	end
end
-->8
-- cast
function init_cast()
	 points = {}
	 target = {}
	 targetp = {x=player.x,y=player.y}
	 origin = {x=player.x,y=player.y}
end

function update_cast()
	if(#points==0 or origin.x!=player.x or origin.y!=player.y) then
	 reset_range()
		points=fov(player.x,player.y,player.spells[player.spell_index].range)
		origin.x = player.x
		origin.y = player.y
	end
	if #target == 0 then
		if player.spells[player.spell_index].spelltype == "ball" then
			target = get_circle_points(targetp.x,targetp.y,player.spells[player.spell_index].radius)
		elseif player.spells[player.spell_index].spelltype == "bolt" then
			target = line_points(player.x,player.y, targetp.x, targetp.y)
		elseif player.spells[player.spell_index].spelltype == "fan" then
			target = get_cone_points(player.x,player.y,targetp.x,targetp.y,player.spells[player.spell_index].angle, player.spells[player.spell_index].range)
		end
	end
	if(btnp(5))then
		reset_range()
		reset_target()
		set_state("standby")
		
	elseif(btnp(4))then
		if player.spells[player.spell_index].uses > 0 then
			cast_spell(player.spells[player.spell_index])

			reset_range()
			reset_target()
			set_state("turn")
		else
			reset_range()
			reset_target()
			-- play oom sound
		end
		
		
	elseif(btnp(0))then
		local newx = targetp.x - 1
		if includes_point(points,{x=newx,y=targetp.y}) then
			targetp.x = newx
		end
		reset_target()
	elseif(btnp(1))then
		local newx = targetp.x + 1
		if includes_point(points,{x=newx,y=targetp.y}) then
			targetp.x = newx
		end
		reset_target()
	elseif(btnp(2))then
		local newy = targetp.y - 1
		if includes_point(points,{x=targetp.x,y=newy}) then
			targetp.y = newy
		end
		reset_target()
	elseif(btnp(3))then
		local newy = targetp.y + 1
		if includes_point(points,{x=targetp.x,y=newy}) then
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
		mset(point.x,point.y,3)
	end
end

function highlight_target()
	for point in all(target) do
		local flag = fget(mget(point.x,point.y))
		if flag != 1 then
			mset(point.x,point.y,5)
		else
			mset(point.x,point.y,6)
		end
	end
	if frame%30<15 then
		mset(targetp.x, targetp.y, 7)
	else
		mset(targetp.x, targetp.y, 5)
	end
end

function reset_target()
	for point in all(target) do
		local flag = fget(mget(point.x,point.y))
		if flag != 1 then
			mset(point.x,point.y,2)
		else
			mset(point.x,point.y,1)
		end
	end
	target = {}
end

function reset_range()
	for point in all(points) do
			mset(point.x,point.y,2)
	end
end

function dmg(damage, targets)
	for mob in all(mobs) do
		if mob != player and includes_point(targets,{x=mob.x,y=mob.y})  then
			mob.hp -= damage
		end
	end
end

function cast_spell(spell, targets)
	spell.uses -= 1
	add(ani_queue, {spell.ani, target})
	dmg(spell.dmg, target)
end


-->8
-- mob
function init_player()
	player = {
		x=10,
		y=8,
		ox=0,
		oy=0,
		dir=1,
		sprites={240, 241},
		flipx=false,
		hp = 50,
		maxhp = 50,
		spell_index=1,
		spells={},
		-- {item=spriteNum, ammt=num}
		items={0,1,1},
		collide=false
	}
	add(player.spells,deepcopy(spellbook[1]))
	add(player.spells,deepcopy(spellbook[2]))
	add(player.spells,deepcopy(spellbook[3]))
	add(mobs,player)
end

function update_player()
	if(btnp(2)) then
		update_mob_pos(player, player.x,player.y-1)
		collect_item(player.x,player.y)
		set_state("turn")
	elseif(btnp(3)) then
		update_mob_pos(player, player.x,player.y+1)
		collect_item(player.x,player.y)
		set_state("turn")
	elseif(btnp(0)) then
		update_mob_pos(player, player.x-1,player.y)
		collect_item(player.x,player.y)
		set_state("turn")
	elseif(btnp(1)) then
		update_mob_pos(player, player.x+1,player.y)
		collect_item(player.x,player.y)
		set_state("turn")
	elseif(btnp(4)) then
		set_state("menu")
	elseif(btnp(5)) then
		set_state("cast")
		init_cast()
	end
	
end

function update_mob_pos(mob, x,y)
	local collide = detect_collision(x,y)
	local dx,dy = mob.x-x,mob.y-y
	
	if(dy>0) then
		if not collide then
			mob.y=y
			mob.oy=8
		elseif mob==player then
			mob.collide=true
		end
		mob.dir=3
	elseif(dy<0) then
		if not collide then
			mob.y=y
			mob.oy=-8
		elseif mob==player then
			mob.collide=true
		end
		mob.dir=4
	elseif(dx>0) then
		if not collide then
			mob.x=x
			mob.ox=8
		elseif mob==player then
			mob.collide=true
		end
		mob.flip =false
		mob.dir=1
	elseif(dx<0) then
		if not collide then
			mob.x=x
			mob.ox=-8
		elseif mob==player then
			mob.collide=true
		end
		mob.flip =false
		mob.dir=2
	end
	if mob != player and collide==player then
		player.hp -= mob.meleedmg
		mob.collide=true
	end
end

function move_mob(mob)
	if mob.collide and tframe <= 4 then
		mob.ox+=dirx[mob.dir]
		mob.oy+=diry[mob.dir]
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
			mob.collide=false
			return true
		else
			return false
		end
	end
end

function draw_mob(mob)
 local sprite = get_frame(frame,mob.sprites,8)
	spr(sprite,(mob.x*8)+mob.ox,(mob.y*8)+mob.oy,1,1,mob.flip)
end

function init_enemies()
	enemyid=1
	enemy_types = {
		{
			id=-1,
			x=12,
			y=12,
			dir=1,
			ox=0,
			oy=0,
			sprites={192, 193},
			flipx=false,
			hp = 10,
			maxhp = 10,
			spell_index=1,
			meleedmg=2,
			spells={},
			cooldown=0,
			collide=false
		}
	}
	add_enemy(11,11,1)
	add_enemy(11,12,1)
	add_enemy(11,13,1)
	add_enemy(12,11,1)
	add_enemy(12,12,1)
	add_enemy(12,13,1)
end

function add_enemy(x,y,type)
	local id = enemyid + 1
	local baseenemy = enemy_types[type]
	local enemy = shallowcopy(baseenemy)
	enemy.id=id
	enemy.x=x
	enemy.y=y
	add(mobs,enemy)
	enemyid=id
end

function update_enemies()
	for mob in all(mobs) do
		if mob.hp <= 0 then
			del(mobs,mob)
		else
			update_enemy_pos(mob)
		end
	end
end

function update_enemy_pos(mob)
	if mob != player then
		local x,y = getcloser(mob.x,mob.y, player.x,player.y)
		update_mob_pos(mob, x, y)
	end
end

function draw_enemy_health()
	for mob in all(mobs) do
		if mob != player then
			if mob.collide then
				spr(176,mob.x*8,mob.y*8+1)
				line(mob.x*8+1,mob.y*8+7, mob.x*8+(mob.hp/mob.maxhp)*6, mob.y*8+7)
			else
				spr(176,mob.x*8+mob.ox,mob.y*8+1+mob.oy)
				line(mob.x*8+1+mob.ox,mob.y*8+7+mob.oy, mob.x*8+(mob.hp/mob.maxhp)*6+mob.ox, mob.y*8+7+mob.oy)
			end
		end
	end
end

-->8
--map gen
function init_world()
	level = 1
	
end

function read_room_options()
	rooms = []
	for i=0, 15, 8 do
		for x=0, 7 do
			add(rooms, [])
			for y=32, 39 do
				local color = sget(x,y)
				if (color == 5) then
					add(rooms[#rooms], 1)
				elseif (color == 7) then

				end
			end
		end

	end
end

-->8
-- spellbook
function init_spellbook()
	spelltypes = {"ball", "bolt","fan"}
	spellbook = {
			{
				name="sparks",
				spcost=1,
				maxuses=15,
				uses=15,
				description="sparks fizzle from your staff",
				icon={x=0,y=64},
				ani={160,161,162,163},
				spelltype = spelltypes[1],
				radius=0.5,
				mtype="heal",
				range=4,
				dmg=0,
				cooldown=3,
				upgrades={
					{name="damage",owned=false,cost=1, mod=3},
					{name="range",owned=false,cost=1,mod=1},
					{name="uses",owned=false,cost=1, mod=4},
				},
				additional_effect = function () end
			},
			--different heal levels that cause enemy status effects
			--different shield levels
			--direct damage spells
			{
				name="holy bolt",
				spcost=1,
				maxuses=30,
				uses=3,
				icon={x=8,y=64},
				description="deals 8 dmg",
				spelltype= spelltypes[2],
				ani={144,145,146,147},
				range=6,
				radius=1,
				dmg=8,
				upgrades={
					{name="damage",owned=false,cost=1, mod=3},
					{name="range",owned=false,cost=1,mod=1},
					{name="uses",owned=false,cost=1, mod=4},
				},
			},
			{
				name="fire fan",
				spcost=3,
				maxuses=15,
				uses=15,
				description="fire but fan",
				icon={x=32,y=64},
				ani={160,161,162,163},
				spelltype = spelltypes[3],
				-- in fan type spells radius is an angle in degrees
				angle=30,
				mtype="heal",
				range=4,
				dmg=5,
				upgrades={
					{name="damage",owned=false,cost=1, mod=3},
					{name="range",owned=false,cost=1,mod=1},
					{name="uses",owned=false,cost=1, mod=4},
				},
			},
			{
				name="fire ball",
				spcost=1,
				maxuses=9,
				uses=9,
				description="fire but ball",
				icon={x=40,y=64},
				ani={148,149,150,151},
				spelltype = spelltypes[1],
				radius=2,
				mtype="heal",
				range=4,
				dmg=5,
				upgrades={
					{name="damage",owned=false,cost=1, mod=3},
					{name="range",owned=false,cost=1,mod=1},
					{name="uses",owned=false,cost=1, mod=4},
				},
			},
		}
end
__gfx__
000000007666666600000000ccccccccccccccccbbbbbbbbbbbbbbbb333333330000000000000000000000000000000000000000000000000000000000000000
000000006dddddd100000000cccccccccdddddd1bbbbbbbbbdddddd1333333330000000000000000000000000000000000000000000000000000000000000000
007007006d1111d100000000cccccccccd1111d1bbbbbbbbbd1111d1333333330000000000000000000000000000000000000000000000000000000000000000
000770006d1dd6d100000000cccccccccd1ddcd1bbbbbbbbbd1ddbd1333333330000000000000000000000000000000000000000000000000000000000000000
000770006d1dd6d100000000cccccccccd1ddcd1bbbbbbbbbd1ddbd1333333330000000000000000000000000000000000000000000000000000000000000000
007007006d6667d100000000cccccccccdccccd1bbbbbbbbbdbbbbd1333333330000000000000000000000000000000000000000000000000000000000000000
000000006dddddd100000060cccccccccdddddd1bbbbbbbbbdddddd1333333330000000000000000000000000000000000000000000000000000000000000000
000000001111111100000000cccccccc11111111bbbbbbbb11111111333333330000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07700770007777000777777007777770002222000022220000000000000000000000000000000000000000000000000000000000000000000000000000000000
7887788707bbbb700744447007444470002dd200002ee20000000000000000000000000000000000000000000000000000000000000000000000000000000000
788888877bbbbbb7007777000077770002dddd2002eeee2000000000000000000000000000000000000000000000000000000000000000000000000000000000
788888877bbbbbb70788887007cccc7002dddd2002eeee2000000000000000000000000000000000000000000000000000000000000000000000000000000000
078888707bbbbbb70788887007cccc7002dddd2002eeee2000000000000000000000000000000000000000000000000000000000000000000000000000000000
078888707bbbbbb70788887007cccc7002dddd2002eeee2000000000000000000000000000000000000000000000000000000000000000000000000000000000
0078870007bbbb700788887007cccc70002dd200002ee20000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000007777000077770000777700002222000022220000000000000000000000000000000000000000000000000000000000000000000000000000000000
55577555555775550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57777775555775550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57777775555775550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
777e7777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57777775555775550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57777775555775550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55577555555775550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a000a000777777000aaaa0000bbbb00080800080008800000000000000000000000000000000000000000000000000000000000000000000000000000000000
aaa00a00777767770a00a0a00b0000b0800080800088880000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a00aaa077766770a00aaa0ab000000b880880880088980000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aaaaa077aa000a000a00ab000000b898888980889988000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000aaa0000aa000a00a000ab000000ba889988a889a998000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a00a000000aa00a0aaa00ab000000b0a8888a0899aa98800000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa0a0000000a000a0a00a00b0000b000a88a0089a9a99800000000000000000000000000000000000000000000000000000000000000000000000000000000
00a0000000000a0000aaaa0000bbbb00000aa00008a77a8000000000000000000000000000000000000000000000000000000000000000000000000000000000
a000000000a00a000aa0a0a00a00a0a0000000000000000000000000000880000000000000000000000000000000000000000000000000000000000000000000
a000000000a00a000a00a0a00a00a0a0000000000000000000008000008888000000000000000000000000000000000000000000000000000000000000000000
a00000000aa0aa000a00a0a0aa0aa0a0000000000000000000088880008898000000000000000000000000000000000000000000000000000000000000000000
aa0000000a00a0000a00a0a0a00a0a00000000000000880000089980088998800000000000000000000000000000000000000000000000000000000000000000
0aa000000a00a0000aa0a00aa0aa0a0a000000000008880008889980889a99800000000000000000000000000000000000000000000000000000000000000000
00a000000a0a000000a0a00aa0a00a0a000088000088998008999998899aa9880000000000000000000000000000000000000000000000000000000000000000
00a00000aa0a00000aa0aa0a00a0a0aa00088800008999800899aaa889a9a9980000000000000000000000000000000000000000000000000000000000000000
00a00000a0aa00000a000a0000a0a0a0000898000089aa80089aa7a808a77a800000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000aaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000aaaa000a0000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000aa0000a0000a0a000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aa00000a00a000a0000a0a000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aa00000a00a000a0000a0a000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000aa0000a0000a0a000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000aaaa000a0000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000aaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800008008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02a8a820008888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2288822222a8a8220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00288200028882200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00002020002882000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60777700007777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0ffff7060ffff700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a05f5ff7a05f5ff70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f0fffff7a0fffff70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a7777770f07777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a07a77f0a77a77f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0aaa770a0aaa7700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007a7770a07a77770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0001020001000100000000000000000000000000000000000000000000000000000000000000000000000000000000000404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
