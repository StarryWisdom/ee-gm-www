-- all of the scripting functions common between all scripts
_ENV = getScriptStorage()._gm_cuf_env

local add_function = getScriptStorage()._cuf_gm.add_function

add_function("get_gm_click1",function ()
	onGMClick(function (x,y)
		getScriptStorage().last_gm_click = {x=x,y=y}
	end)
end)

add_function("get_gm_click2",function ()
	return getScriptStorage().last_gm_click
end)