-- ship_template
function getShipShields(p)
	local shields = {}
	for i=0,p:getShieldCount()-1 do
		table.insert(shields,
			{
				max=p:getShieldMax(i)
			}
		)
	end
	return shields
end
function getBeamData(p)
	local beams = {}
	for i=0,15 do -- 16 beams should be max beam number
		table.insert(beams,
			{
				Arc=p:getBeamWeaponArc(i),
				Direction=p:getBeamWeaponDirection(i),
				Range=p:getBeamWeaponRange(i),
				TurretArc=p:getBeamWeaponTurretArc(i),
				TurretDirection=p:getBeamWeaponDirection(i),
				CycleTime=p:getBeamWeaponCycleTime(i),
				Damage=p:getBeamWeaponDamage(i),
				Energy=p:getBeamWeaponEnergyPerFire(i),
				Heat=p:getBeamWeaponHeatPerFire(i)
			}
		)
	end
	return beams
end
function getShipData(p)
	return { 
		TypeName = p:getTypeName(),
		ShieldMax = getShipShields(p),
		Beams = getBeamData(p)
	}
end
ship=PlayerSpaceship():setTemplate(ship_template)
ret=getShipData(ship)
ship:destroy()
return ret