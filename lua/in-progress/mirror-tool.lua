_ENV = getScriptStorage()._gm_cuf_env
getScriptStorage().fun = function ()
	print("1")
	initialGMFunctions()
end
addGMFunction("-return",getScriptStorage().fun)
