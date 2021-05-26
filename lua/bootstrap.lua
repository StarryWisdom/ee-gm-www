-- loaded first, must all fit in the EE upload limit
if (getScriptStorage()._cuf_gm == nil) then
	getScriptStorage()._cuf_gm = {
		uploads = {
			slots = {},
			slot_id = 0,
			script_functions = {},
		},
		upload_segment = function (slot, str)
			slots = getScriptStorage()._cuf_gm.uploads.slots
			slots[slot] = slots[slot] .. str
			return slots[slot];
		end,
		upload_end = function (slot)
			return load(getScriptStorage()._cuf_gm.uploads.slots[slot])()
		end,
		upload_start = function ()
			local slot_id = getScriptStorage()._cuf_gm.uploads.slot_id
			getScriptStorage()._cuf_gm.uploads.slots[slot_id] = ""
			getScriptStorage()._cuf_gm.uploads.slot_id = slot_id + 1
			return slot_id
		end,
	}
end