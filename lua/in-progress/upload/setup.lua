if (getScriptStorage()._cuf_gm == nil) then
	getScriptStorage()._cuf_gm = {}
	getScriptStorage()._cuf_gm._upload_slot = {}
end

getScriptStorage()._cuf_gm.upload_segment = function (slot, str)
	slots = getScriptStorage()._cuf_gm._upload_slot
	slots[slot] = slots[slot] .. str
	return slots[slot];
end

getScriptStorage()._cuf_gm.upload_end = function (slot)
	return load(getScriptStorage()._cuf_gm._upload_slot[slot])()
end