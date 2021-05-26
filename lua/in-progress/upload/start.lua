local slot_id = getScriptStorage()._cuf_gm.uploads.slot_id
getScriptStorage()._cuf_gm.uploads.slots[slot_id] = ""
getScriptStorage()._cuf_gm.uploads.slot_id = slot_id + 1
return slot_id