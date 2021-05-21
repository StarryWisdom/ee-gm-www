getScriptStorage().tmp_fn={}
for i=0,32 do
	local max_time = max_time -- we need to mirror the _ENV variables for when that is gc'ed
	local energy_cost = energy_cost
	local max_range = max_range
	local no_eng_msg = no_eng_msg
	getScriptStorage().tmp_fn[i] = getScriptStorage()._gm_cuf_env.wrapWithErrorHandling(function ()
		_ENV=getScriptStorage()._gm_cuf_env;
		local p = getPlayerShip(i)
		if p ~= nil then
			if p:getEnergyLevel() < energy_cost then
				p:addCustomMessage("Science","no_ene_s",no_eng_msg)
				p:addCustomMessage("Operations","no_ene_o",no_eng_msg)
				p:addCustomMessage("Single","no_ene_i",no_eng_msg)
			else
				local jammer = WarpJammer():setPosition(p:getPosition())
				local update_data = {
					update = function (self, obj, delta)
						self.t = self.t + delta
						if self.t > self.max_time then
							local a = Artifact():setPosition(obj:getPosition()):setDescription(obj:getDescription("simplescan"))
							obj:destroy()
						end
						obj:setRange(math.sin((self.t/self.max_time)*math.pi)*self.max_range)
					end,
					edit = {},
					t = 0,
					max_time = max_time,
					max_range = max_range,
					name = "dynamic warp jammer"
				}
				update_system:addUpdate(jammer,"dynamic jammer",update_data)
				p:setEnergyLevel(p:getEnergyLevel()-energy_cost)
				addGMMessage("sat button clicked on " .. p:getCallSign() .. "set result in artifact single scan")
			end
		end
	end)
end

for i=0,32 do
	if (getPlayerShip(i) ~= nil) then
		getPlayerShip(i):addCustomButton("Science","tmp_s",name,getScriptStorage().tmp_fn[i])
		getPlayerShip(i):addCustomButton("Operations","tmp_o",name,getScriptStorage().tmp_fn[i])
		getPlayerShip(i):addCustomButton("Single","tmp_i",name,getScriptStorage().tmp_fn[i])
	end
end