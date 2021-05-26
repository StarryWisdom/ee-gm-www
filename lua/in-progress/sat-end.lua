for i=0,32 do
	if (getPlayerShip(i) ~= nil) then
		local p=getPlayerShip(i)
		p:removeCustom("tmp_s")
		p:removeCustom("tmp_o")
		p:removeCustom("tmp_i")
	end
end