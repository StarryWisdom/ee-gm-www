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
		local args = args or {arguments = {}}
		getScriptStorage()._cuf_gm.functions[name] = {fn = fun, args = args}
	end
	add_function("add_function",add_function)
	-- currently describe_function isnt finalised enough to live here
	-- until then we are going to build the args table by hand here
	-- which is ugly tbh
	add_function("upload_segment", function (args)
		assert(type(args)=="table")
		assert(type(args.slot)=="number")
		assert(getScriptStorage()._cuf_gm.uploads.slots[args.slot] ~= nil)
		assert(type(args.part)=="number")
		assert(getScriptStorage()._cuf_gm.uploads.slots[args.slot].parts[args.part] == nil)
		assert(type(args.str)=="string")
		getScriptStorage()._cuf_gm.uploads.slots[args.slot].parts[args.part] = args.str
	end,
	{arguments = {"arguments"}}
	)
	add_function("upload_end", function (args)
		assert(type(args)=="table")
		assert(type(args.slot)=="number")
		assert(getScriptStorage()._cuf_gm.uploads.slots[args.slot] ~= nil)
		local end_str = ""
		for i = 1, getScriptStorage()._cuf_gm.uploads.slots[args.slot].total_parts do
			assert(type(getScriptStorage()._cuf_gm.uploads.slots[args.slot].parts[i])=="string")
			end_str = end_str .. getScriptStorage()._cuf_gm.uploads.slots[args.slot].parts[i]
		end
		getScriptStorage()._cuf_gm.uploads.slots[args.slot].str = end_str
		getScriptStorage()._cuf_gm.uploads.slots[args.slot].parts = nil
		local fn, err = load(end_str)
		if fn then
			return fn()
		else
			print(err)
			error(err)
		end
	end,
	{arguments = {"arguments"}}
	)
	add_function("upload_start", function (args)
		assert(type(args)=="table")
		assert(type(args.parts)=="number")
		local slot_id = getScriptStorage()._cuf_gm.uploads.slot_id
		getScriptStorage()._cuf_gm.uploads.slots[slot_id] = {total_parts = args.parts, parts = {}}
		getScriptStorage()._cuf_gm.uploads.slot_id = slot_id + 1
		return slot_id
	end,
	{arguments = {"arguments"}}
	)
	-- the indirect call is at least somewhat useful in chainging functions
	-- it allows tables of parmeters to be completed and not to care about the order with which they are built
	-- this is mostly a consideration for onGMClick and location
	-- I think its possible this will be made obsolete in time though
	add_function("indirect_call",function (args)
		assert(type(args)=="table")
		assert(type(args.call)=="string")
		assert(getScriptStorage()._cuf_gm.functions[args.call] ~= nil, "attempted to call an undefined function")
		assert(type(getScriptStorage()._cuf_gm.functions[args.call].fn) == "function")
		assert(type(getScriptStorage()._cuf_gm.functions[args.call].args.arguments) == "table")
		assert(type(getScriptStorage()._cuf_gm.functions[args.call].args) == "table")
		local tbl = {}
		for _,arg in ipairs(getScriptStorage()._cuf_gm.functions[args.call].args.arguments) do
			if arg == "arguments" then
				table.insert(tbl,args)
			else
				-- todo check arguments are in the format described by describe_function
				table.insert(tbl,args[arg])
			end
		end
		return getScriptStorage()._cuf_gm.functions[args.call].fn(table.unpack(tbl))
	end,
	{arguments = {"arguments"}}
	)
	getScriptStorage()._cuf_gm.indirect_call = getScriptStorage()._cuf_gm.get_function("indirect_call")
	getScriptStorage()._cuf_gm.upload_start = getScriptStorage()._cuf_gm.get_function("upload_start")
	getScriptStorage()._cuf_gm.upload_segment = getScriptStorage()._cuf_gm.get_function("upload_segment")
	getScriptStorage()._cuf_gm.upload_end = getScriptStorage()._cuf_gm.get_function("upload_end")
end