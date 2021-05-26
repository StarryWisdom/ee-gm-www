-- loaded first, must all fit in the EE upload limit
if (getScriptStorage()._cuf_gm == nil) then
	local add_function = function (name, fun)
		getScriptStorage()._cuf_gm[name] = fun
	end
	getScriptStorage()._cuf_gm = {
		uploads = {
			slots = {},
			slot_id = 0,
			script_functions = {},
		},
		add_function = add_function,
	}
	add_function("upload_segment", function (slot, str)
		slots = getScriptStorage()._cuf_gm.uploads.slots
		slots[slot] = slots[slot] .. str
		return slots[slot];
	end)
	add_function("upload_end", function (slot)
		return load(getScriptStorage()._cuf_gm.uploads.slots[slot])()
	end)
	add_function("upload_start", function ()
		local slot_id = getScriptStorage()._cuf_gm.uploads.slot_id
		getScriptStorage()._cuf_gm.uploads.slots[slot_id] = ""
		getScriptStorage()._cuf_gm.uploads.slot_id = slot_id + 1
		return slot_id
	end)
end