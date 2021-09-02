_ENV = getScriptStorage()._cuf_gm._ENV
getScriptStorage().fun = function ()
	print("1")
	initialGMFunctions()
end
addGMFunction("-return",getScriptStorage().fun)
