templates = {}
function returnSelf (self)
	return self
end
function ShipTemplate ()
	local data = {
		Type = "ship"
	}
	local ret = {
		setName = function (self,name)
			data.Name=name
			return self
		end,
		setModel = function (self,model)
			data.Model = model
			return self
		end,
		setRadarTrace = function (self,radarTrace)
			data.RadarTrace = radarTrace
			return self
		end,
		copy = function (self,name)
			return ShipTemplate()
				:setModel(data.Model)
				:setName(name)
				:setRadarTrace(data.RadarTrace)
				:setType(data.Type)
		end,
		setType = function (self, type)
			data.Type = type
			return self
		end,
		setLocaleName = returnSelf,
		setDescription = returnSelf,
		setHull = returnSelf,
		setShields = returnSelf,
		setClass = returnSelf,
		setSpeed = returnSelf,
		setDefaultAI = returnSelf,
		setBeam = returnSelf,
		setLocaleName = returnSelf,
		setImpulseSoundFile = returnSelf,
		setCombatManeuver = returnSelf,
		setEnergyStorage = returnSelf,
		setRepairCrewCount = returnSelf,
		addRoomSystem = returnSelf,
		addDoor = returnSelf,
		addDoor = returnSelf,
		setTubes = returnSelf,
		setTubeSize = returnSelf,
		setWeaponStorage = returnSelf,
		setTubeDirection = returnSelf,
		setWeaponTubeExclusiveFor = returnSelf,
		setBeamWeaponTurret = returnSelf,
		addRoom = returnSelf,
		setBeamWeapon = returnSelf,
		setWarpSpeed = returnSelf,
		weaponTubeDisallowMissle = returnSelf,
		setJumpDrive = returnSelf,
		weaponTubeAllowMissle= returnSelf,
		setJumpDriveRange = returnSelf,
		setDockClasses = returnSelf,
		setCloaking = returnSelf,
		setSharesEnergyWithDocked = returnSelf,
		setRepairDocked = returnSelf,
		setRestocksMissilesDocked = returnSelf,
		setRestocksScanProbes = returnSelf,
	}
	table.insert(templates,data)
	return ret
end
require("shipTemplates.lua")
return templates