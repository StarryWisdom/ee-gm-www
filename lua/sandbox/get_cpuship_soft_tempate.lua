_ENV = getScriptStorage()._cuf_gm._ENV
local unusual = {}
local normal = {}
for k,v in pairs(ship_template) do
	local get_ship_data = function (create,tbl)
		local ship = create("Human Navy",tbl.gm_name)
		tbl["type_name"] = ship:getTypeName()
		ship:destroy()
	end
	this_ship = {
		gm_name = k,
		strength = v.strength,
		gm_adder = v.adder,
		gm_missiler = v.gm_missiler,
		gm_beamer = v.beamer,
		gm_frigate = v.frigate,
		gm_chaser = v.chaser,
		gm_fighter = v.fighter,
		gm_drone = v.drone,
		gm_unusual = v.unusual,
		gm_base = v.base,
	}
	if v.unusual then
		table.insert(unusual,this_ship)
	else
		table.insert(normal,this_ship)
	end
	get_ship_data(v.create,this_ship)
end
local ret = {}
table.sort(normal,function (a,b) return a.gm_name < b.gm_name end)
table.sort(unusual,function (a,b) return a.gm_name < b.gm_name end)
for _,ship in ipairs(unusual) do
	table.insert(ret,ship)
end
for _,ship in ipairs(normal) do
	table.insert(ret,ship)
end
return ret
