local S = minetest.get_translator("iasleep")

if minetest.settings:get_bool("enable_damage") then

iasleep = {}
iasleep.food = {}

-- HUD statbar values
iasleep.sleep = {}
iasleep.sleep_out = {}

-- Count number of poisonings a player has at once
iasleep.poisonings = {}

-- HUD item ids
local sleep_hud = {}

iasleep.HUD_TICK = 0.1

--Some sleep settings
iasleep.exhaustion = {} -- Exhaustion is experimental!

iasleep.HUNGER_TICK = 400 -- time in seconds after that 1 sleep point is taken
iasleep.SLEEP_TICK = 40 -- time in seconds after that 1 sleep point is taken
iasleep.EXHAUST_DIG = 3  -- exhaustion increased this value after digged node
iasleep.EXHAUST_PLACE = 1 -- exhaustion increased this value after placed
iasleep.EXHAUST_MOVE = 0.3 -- exhaustion increased this value if player movement detected
iasleep.EXHAUST_LVL = 160 -- at what exhaustion player rest gets lowerd
iasleep.SAT_MAX = 30 -- maximum rest points
iasleep.SAT_INIT = 20 -- initial rest points
iasleep.SAT_HEAL = 15 -- required rest points to start healing


--load custom settings
local set = io.open(minetest.get_modpath("iasleep").."/iasleep.conf", "r")
if set then 
	dofile(minetest.get_modpath("iasleep").."/iasleep.conf")
	set:close()
end

local function custom_hud(player)
	hb.init_hudbar(player, "rest", iasleep.get_sleep_raw(player))
end

dofile(minetest.get_modpath("iasleep").."/sleep.lua")
--dofile(minetest.get_modpath("iasleep").."/register_foods.lua")

-- register rest hudbar
local purple_tint = "#800080"
hb.register_hudbar("rest", 0xFFFFFF, S("Rest"), {
	--icon = "iasleep_icon.png",
	icon = "beds_bed.png",
	bgicon = "iasleep_bgicon.png",
	bar = "mana_bar.png^[colorize:"..purple_tint,
}, iasleep.SAT_INIT, iasleep.SAT_MAX, false, nil, { format_value = "%.1f", format_max_value = "%d" })

-- update hud elemtens if value has changed
local function update_hud(player)
	local name = player:get_player_name()
 --sleep
	local h_out = tonumber(iasleep.sleep_out[name])
	local h = tonumber(iasleep.sleep[name])
	if h_out ~= h then
		iasleep.sleep_out[name] = h
		hb.change_hudbar(player, "rest", h)
	end
end

iasleep.get_sleep_raw = function(player)
	local inv = player:get_inventory()
	if not inv then return nil end
	local hgp = inv:get_stack("sleep", 1):get_count()
	if hgp == 0 then
		hgp = 21
		inv:set_stack("sleep", 1, ItemStack({name=":", count=hgp}))
	else
		hgp = hgp
	end
	return hgp-1
end

iasleep.set_sleep_raw = function(player)
	local inv = player:get_inventory()
	local name = player:get_player_name()
	local value = iasleep.sleep[name]
	if not inv  or not value then return nil end
	if value > iasleep.SAT_MAX then value = iasleep.SAT_MAX end
	if value < 0 then value = 0 end
	
	inv:set_stack("sleep", 1, ItemStack({name=":", count=value+1}))

	return true
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local inv = player:get_inventory()
	inv:set_size("sleep",1)
	iasleep.sleep[name] = iasleep.get_sleep_raw(player)
	iasleep.sleep_out[name] = iasleep.sleep[name]
	iasleep.exhaustion[name] = 0
	iasleep.poisonings[name] = 0
	custom_hud(player)
	iasleep.set_sleep_raw(player)
end)

minetest.register_on_respawnplayer(function(player)
	-- reset sleep (and save)
	local name = player:get_player_name()
	iasleep.sleep[name] = iasleep.SAT_INIT
	iasleep.set_sleep_raw(player)
	iasleep.exhaustion[name] = 0
end)

local main_timer = 0
local timer = 0
local timer2 = 0
local timer3 = 0
minetest.register_globalstep(function(dtime)
	main_timer = main_timer + dtime
	timer = timer + dtime
	timer2 = timer2 + dtime
	timer3 = timer3 + dtime
	if main_timer > iasleep.HUD_TICK
	or timer > 4
	or timer2 > iasleep.HUNGER_TICK
	or timer3 > iasleep.SLEEP_TICK then

		if main_timer > iasleep.HUD_TICK then main_timer = 0 end

		for _,player in ipairs(minetest.get_connected_players()) do
			local name = player:get_player_name()

			local h = tonumber(iasleep.sleep[name])
			local hp = player:get_hp()
			if timer > 4 then
				-- heal player by 1 hp if not dead and rest is > iasleep.SAT_HEAL
				if h > iasleep.SAT_HEAL and hp > 0 and player:get_breath() > 0 then
					player:set_hp(hp+1)
					-- or damage player by 1 hp if rest is < 2
				elseif h <= 1 then
					if hp-1 >= 0 then player:set_hp(hp-1) end
				end
			end


			if beds.player[name] then
				--print('player in bed: '..name)
				--print('timer2: '..timer2)
				--print('hunger tick: '..iasleep.SLEEP_TICK)
				if timer3 > iasleep.SLEEP_TICK then
					print('increase rest')
					local sleep_change = 1
					-- Saturation
					if h < iasleep.SAT_MAX and sleep_change then
						h = h + sleep_change
						if h > iasleep.SAT_MAX then h = iasleep.SAT_MAX end
						iasleep.sleep[name] = h
						iasleep.set_sleep_raw(player)
					end
				end
				if timer2 > iasleep.HUNGER_TICK then
					local heal = 1
					-- Healing
					local hp_max = player:get_properties().hp_max or minetest.PLAYER_MAX_HP_DEFAULT or 20
					if hp < hp_max and heal then
						hp = hp + heal
						if hp > hp_max then hp = hp_max end
						player:set_hp(hp)
					end
				end
			else
				-- lower rest by 1 point after xx seconds
				if timer2 > iasleep.HUNGER_TICK then
					if h > 0 then
						h = h-1
						iasleep.sleep[name] = h
						iasleep.set_sleep_raw(player)
					end
				end
			end









			-- update all hud elements
			update_hud(player)
			
			local controls = player:get_player_control()
			-- Determine if the player is walking
			if controls.up or controls.down or controls.left or controls.right then
				iasleep.handle_node_actions(nil, nil, player)
			end
		end
	end
	if timer > 4 then timer = 0 end
	if timer2 > iasleep.HUNGER_TICK then timer2 = 0 end
	if timer3 > iasleep.SLEEP_TICK then timer3 = 0 end
end)

minetest.register_chatcommand("rest", {
	privs = {["server"]=true},
	params = S("[<player>] <rest>"),
	description = S("Set rest of player or yourself"),
	func = function(name, param)
		if minetest.settings:get_bool("enable_damage") == false then
			return false, S("Not possible, damage is disabled.")
		end
		local targetname, rest = string.match(param, "(%S+) (%S+)")
		if not targetname then
			rest = param
		end
		rest = tonumber(rest)
		if not rest then
			return false, S("Invalid rest!")
		end
		if not targetname then
			targetname = name
		end
		local target = minetest.get_player_by_name(targetname)
		if target == nil then
			return false, S("Player @1 does not exist.", targetname)
		end
		if rest > iasleep.SAT_MAX then
			rest = iasleep.SAT_MAX
		elseif rest < 0 then
			rest = 0
		end
		iasleep.sleep[targetname] = rest
		iasleep.set_sleep_raw(target)
		return true
	end,
})

end
