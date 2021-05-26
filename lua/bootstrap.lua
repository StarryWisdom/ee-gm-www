-- loaded first, must all fit in the EE upload limit
if (getScriptStorage()._cuf_gm == nil) then
	getScriptStorage()._cuf_gm = {
		uploads = {
			slots = {},
			slot_id = 0,
		},
	}
end

getScriptStorage()._cuf_gm.upload_segment = function (slot, str)
	slots = getScriptStorage()._cuf_gm.uploads.slots
	slots[slot] = slots[slot] .. str
	return slots[slot];
end

getScriptStorage()._cuf_gm.upload_end = function (slot)
	return load(getScriptStorage()._cuf_gm.uploads.slots[slot])()
end