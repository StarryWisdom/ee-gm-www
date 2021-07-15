-- loaded first, must all fit in the EE upload limit
if (getScriptStorage()._cuf_gm == nil) then
	getScriptStorage()._cuf_gm = {
		uploads = {
			slots = {},
			slot_id = 0,
			script_functions = {},
		},
		functions = {
			-- an array of elements with a fn and args element
		},
		get_function = function (name)
			assert(type(name)=="string")
			return getScriptStorage()._cuf_gm.functions[name].fn
		end
	}
	local add_function = function (name, fun, args)
		assert(type(name)=="string")
		assert(type(fun)=="function")
		getScriptStorage()._cuf_gm.functions[name] = {fn = fun, args = args}
	end
	add_function("add_function",add_function)
	add_function("upload_segment", function (args)
		local slot = args.slot
		slots = getScriptStorage()._cuf_gm.uploads.slots
		slots[slot] = slots[slot] .. args.str
		return slots[slot];
	end)
	add_function("upload_end", function (args)
		local fn, err = load(getScriptStorage()._cuf_gm.uploads.slots[args.slot])
		if fn then
			return fn()
		else
			print(err)
			error(err)
		end
	end)
	add_function("upload_start", function ()
		local slot_id = getScriptStorage()._cuf_gm.uploads.slot_id
		getScriptStorage()._cuf_gm.uploads.slots[slot_id] = ""
		getScriptStorage()._cuf_gm.uploads.slot_id = slot_id + 1
		return slot_id
	end)
	add_function("indirect_call",function (args)
		assert(type(args)=="table")
		assert(type(args.call)=="string")
		assert(getScriptStorage()._cuf_gm.functions[args.call] ~= nil)
		assert(type(getScriptStorage()._cuf_gm.functions[args.call].fn) == "function")
		-- todo check arguments are in the format described by describe_function
		return getScriptStorage()._cuf_gm.functions[args.call].fn(args)
	end)
	getScriptStorage()._cuf_gm.indirect_call = getScriptStorage()._cuf_gm.get_function("indirect_call")
	getScriptStorage()._cuf_gm.upload_start = getScriptStorage()._cuf_gm.get_function("upload_start")
	getScriptStorage()._cuf_gm.upload_segment = getScriptStorage()._cuf_gm.get_function("upload_segment")
	getScriptStorage()._cuf_gm.upload_end = getScriptStorage()._cuf_gm.get_function("upload_end")
end