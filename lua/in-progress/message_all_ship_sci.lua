for i=0,32 do
	if (getPlayerShip(i) ~= nil) then
		getPlayerShip(i):addCustomMessage("Science","injected_msg_s",msg)
		getPlayerShip(i):addCustomMessage("Operations","injected_msg_o",msg)
		getPlayerShip(i):addCustomMessage("Single","injected_msg_i",msg)
	end
end