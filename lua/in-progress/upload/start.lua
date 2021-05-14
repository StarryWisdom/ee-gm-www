for i=0,1000000 do
	if (getScriptStorage()._cuf_gm._upload_slot[i] == nil) then
		getScriptStorage()._cuf_gm._upload_slot[i] = ""
		return i
	end
end