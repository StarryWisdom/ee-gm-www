_ENV = getScriptStorage()._gm_cuf_env
local ret = {}
-- note we shouldnt be plucking _update_objects out of the update_system
for index = #update_system._update_objects,1,-1 do
	-- note this dies to circular loops inside of the update system
	--table.insert(ret,update_system._update_objects[index])
end
return ret