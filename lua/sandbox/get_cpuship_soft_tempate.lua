_ENV = getScriptStorage()._cuf_gm._ENV
local ret = {}
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
		gm_unusal = v.unusual,
		gm_base = v.base,
	}
	get_ship_data(v.create,this_ship)
	table.insert(ret,this_ship)
end
return ret
