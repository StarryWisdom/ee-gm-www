_ENV = getScriptStorage()._cuf_gm._ENV

function checkVariableDescription(arg_description)
	local arg_name = arg_description[1]
	assert(type(arg_name)=="string")
	assert(arg_name ~= "_this") -- description is reused elsewhere and is a problem to be an arg name TODO - old?
	local arg_type = arg_description[2]
	assert(type(arg_type)=="string")
	-- TODO no checking of default value
	assert(arg_type == "number" or arg_type == "string" or arg_type == "position" or arg_type == "npc_ship" or arg_type == "indirect_function","describeFunction requires the a type for each argument")
	for arg_name,arg_value in pairs(arg_description) do
		if arg_name == 1 or arg_name == 2 or arg_name == 3 then
		elseif arg_name == "min" then
			assert(arg_type == "number")
		elseif arg_name == "max" then
			assert(arg_type == "number")
		elseif arg_name == "ui_suppress" ~= nil then
			assert(arg_type == "indirect_function")
		else
			assert(false,"arg_description has a key that describeFunction doesnt about")
		end
	end
end

-- more fully describeAndExportFunctionForWeb, but there are going to be an absurd number
-- of these so brevity is important, I have no objection if a find and replace is desired

-- description format is
-- 1) name of the function as a string (the function call itself is pulled out of the global table)
--                         as such anonymous functions are presently not supported
-- 2) function description, which is a table or a string or nil
--              if it is a string then it is assumed as being function_description[1]
-- 2.1) function_description[1] is a description used for the web tool
-- TODO 2.2) function_description[2+] is a list of tags to be used for sorting on the web UI
-- 3) args_table a table of tables is an optional table describing each argument given to the function
-- 3.0) each inner table is defined as follows
-- 3.1) [1] name of the argument
-- 3.2) [2] type of the argument - see below for types
-- 3.3) [3] the default value for the argument, note this is not checked for type/value and is current web tool only
-- 3.4) the remainder of the table is optional tags based on type
-- for numbers -
-- min - minimum value expected
-- max - maximum value expected
-- for indirect_function
-- ui_suppress - the values this function provides for the function call (this will stop them being shown on the web tool)
--
-- types
-- string - a lua string - example = "the answer"
-- number - a lua number - example = 42
-- position - a table of 2 numbers - {x,y} - example = {x = 6, y = 9}
-- npc_ship - the template name for a npc ship, this can be set to valid softtemplates or stock templates - example "Adder MK4"
-- indirect_function - a table that will be used for calling indirectCall (at the time of execution, not definition) example = {call = getCpushipSoftTemplates}
function describeFunction(name,function_description,args_table)
	-- this is about 90% verifying that the data is good
	-- and 10% repacking the arguments to be used later in a more convient format
	assert(type(name)=="string")
	if type(function_description) ~= "table" then
		function_description = {function_description}
	end
	assert(type(function_description)=="table")
	args_table = args_table or {}
	assert(type(args_table)=="table")
	local fn = getScriptStorage()._cuf_gm._ENV[name]
	assert(type(fn)=="function",name)
	local description = {_this = function_description}
	for arg_num,arg_description in pairs(args_table) do
		checkVariableDescription(arg_description)
		description[arg_num] = arg_description
	end
	getScriptStorage()._cuf_gm.functions[name] = {fn = fn, args = description}
end

-- the indirect call is at least somewhat useful in chainging functions
-- it allows tables of parmeters to be completed and not to care about the order with which they are built
-- this is mostly a consideration for onGMClick and location
-- I think its possible this will be made obsolete in time though
function indirect_call(args)
	assert(type(args)=="table")
	assert(type(args.call)=="string")
	assert(getScriptStorage()._cuf_gm.functions[args.call] ~= nil, "attempted to call an undefined function " .. args.call)
	assert(type(getScriptStorage()._cuf_gm.functions[args.call].fn) == "function")
	assert(type(getScriptStorage()._cuf_gm.functions[args.call].args) == "table")
	local tbl = {}
	for _,arg in ipairs(getScriptStorage()._cuf_gm.functions[args.call].args) do
		-- todo check arguments are in the format described by describeFunction
		assert(args[arg[1]],"argument not in list")
		table.insert(tbl,args[arg[1]])
	end
	table.insert(tbl,args)
	return getScriptStorage()._cuf_gm.functions[args.call].fn(table.unpack(tbl))
end
describeFunction("indirect_call")
getScriptStorage()._cuf_gm.indirect_call = indirect_call

function getCpushipSoftTemplates()
	local unusual = {}
	local normal = {}
	for k,v in pairs(ship_template) do
		local get_ship_data = function (create,tbl)
			local ship = create("Human Navy",tbl.gm_name)
			tbl["type_name"] = ship:getTypeName()
			ship:destroy()
		end
		this_ship = {
			gm_name = k,
			strength = v.strength,
			gm_adder = v.adder,
			gm_missiler = v.gm_missiler,
			gm_beamer = v.beamer,
			gm_frigate = v.frigate,
			gm_chaser = v.chaser,
			gm_fighter = v.fighter,
			gm_drone = v.drone,
			gm_unusual = v.unusual,
			gm_base = v.base,
		}
		-- we sort the data here, at some point this probably should be done in the web interface
		-- but that wont be for a while yet
		if v.unusual then
			table.insert(unusual,this_ship)
		else
			table.insert(normal,this_ship)
		end
		get_ship_data(v.create,this_ship)
	end
	local ret = {}
	table.sort(normal,function (a,b) return a.gm_name < b.gm_name end)
	table.sort(unusual,function (a,b) return a.gm_name < b.gm_name end)
	for _,ship in ipairs(unusual) do
		table.insert(ret,ship)
	end
	for _,ship in ipairs(normal) do
		table.insert(ret,ship)
	end
	return ret
end
describeFunction("getCpushipSoftTemplates",
	{"get information of cpuships soft templates (note it temporarily creates all ship types)"})


models = {}
templates = {}

_ENV = _G
ModelDataOrig = ModelData
function ModelData ()
	local data = {
		BeamPosition = {}
	}

	local ret = {
		setName = function (self,name)
			data.Name=name
			return self
		end,
		setMesh = function (self,mesh)
			data.Mesh=mesh
			return self
		end,
		setTexture = function (self,texture)
			data.Texture=texture
			return self
		end,
		setSpecular = function (self,specular)
			data.Specular=specular
			return self
		end,
		setIllumination = function (self,illumination)
			data.Illumination = illumination
			return self
		end,
		setRenderOffset = function (self,x,y,z)
			data.RenderOffset = {x=x,y=y,z=z}
			return self
		end,
		setScale = function (self,scale)
			data.Scale = scale
			return self
		end,
		setRadius = function (self,radius)
			data.Radius = radius
			return self
		end,
		setCollisionBox = function (self,x,y)
			data.CollisionBox = {x=x, y=y, z=z}
			return self
		end,
		addBeamPosition = function (self,x,y,z)
			if data.BeamPosition == nil then
				data.BeamPosition = {}
			end
			table.insert(data.BeamPosition,{x=x, y=y, z=z})
			return self
		end,
		addEngineEmitter = function (self,x,y,z)
			if data.EngineEmitter == nil then
				data.EngineEmitter = {}
			end
			table.insert(data.EngineEmitter,{x=x, y=y, z=z})
			return self
		end,
		addTubePosition = function (self,x,y,z)
			if data.TubePosition == nil then
				data.TubePosition = {}
			end
			table.insert(data.TubePosition,{x=x, y=y, z=z})
			return self
		end
	}
	table.insert(getScriptStorage()._cuf_gm._ENV.models,data)
	return ret
end
require("model_data.lua")
ModelData = ModelDataOrig

ShipTemplateOrig = ShipTemplate
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
	table.insert(getScriptStorage()._cuf_gm._ENV.templates,data)
	return ret
end
require("shipTemplates.lua")
ShipTemplate = ShipTemplateOrig
_ENV = getScriptStorage()._cuf_gm._ENV

function getModelData()
	return models
end
describeFunction("getModelData")

function getExtraTemplateData()
	return templates
end
describeFunction("getExtraTemplateData")

PesudoMultiplayerID = 0

function getObjectPesudoMultiplayerID(obj)
	if obj:isValid() then
		if obj._pesudoMultiplayerID == nil then
			obj._pesudoMultiplayerID = PesudoMultiplayerID
			PesudoMultiplayerID = PesudoMultiplayerID +1
			if obj.typeName == nil then
				-- todo add to soft template list
			end
		end
		return obj._pesudoMultiplayerID
	end
end

function getObjectByPesudoMultiplayerID(ID)
end

function getUpdateData()
	local ret = {}
	-- note we shouldnt be plucking _update_objects out of the update_system
	for index = #update_system._update_objects,1,-1 do
		-- note this dies to circular loops inside of the update system
		local obj = update_system._update_objects[index]
		local get_description = function(obj)
			if obj.getCallSign and obj:getCallSign() ~= "" then
				return obj:getCallSign()
			elseif obj.typeName ~= nil then
				return obj.typeName
			else
				return "custom"
			end
		end
		table.insert(ret,{
				id = getObjectPesudoMultiplayerID(obj),
				description = get_description(obj)
		})
	end
	return ret
end
describeFunction("getUpdateData")

function get_descriptions()
	local ret = {}
	-- strip out the function itself
	for name,fn in pairs(getScriptStorage()._cuf_gm.functions) do
		local copy = {}
		for key,value in pairs(fn.args) do
			copy[key] = value
		end
		ret[name] = copy
	end
	return ret
end
describeFunction("get_descriptions");

function mirror_in_dev()
	getScriptStorage().fun = function ()
		print("1")
		initialGMFunctions()
	end
	addGMFunction("-return",getScriptStorage().fun)
end
describeFunction("mirror_in_dev")

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
function get_playership_softtemplate(ship_template)
	local ship = PlayerSpaceship():setTemplate(ship_template)
	local ret = getShipData(ship)
	ship:destroy()
	return ret
end
describeFunction("get_playership_softtemplate",nil,{{"ship_template","string"}})

function get_gm_click1()
	onGMClick(function (x,y)
		getScriptStorage().last_gm_click = {x=x,y=y}
	end)
end
describeFunction("get_gm_click1")

function get_gm_click2()
	return getScriptStorage().last_gm_click
end
describeFunction("get_gm_click2")

-- todo we need a safe wrapper around function calling here
-- and better documentation for functions
function gm_click_wrapper(args)
	-- todo type assert
	onGMClick(function (x,y)
		-- we dont want to change the parameters table as we may be called multiple times
		-- and if the internal value isn't copyied it would result in wrong locations
		local parameters = {}
		for k,v in pairs(args.args) do
			print(k,v)
			parameters[k] = v
		end
		parameters.location= {x = x, y = y}
		print(parameters.location.x,y)
		indirect_call(parameters)
	end)
end
describeFunction("gm_click_wrapper")

-- note there seems to be 1 frame where these are moved to 0,0
function sat_tmp(start,dest,speed,endCallback)
	local art = Artifact():setPosition(start.x,start.y)
	local time = distance(start.x,start.y,dest.x,dest.y)/speed
	dx,dy = vectorFromAngle(angleFromVectorNorth(start.x,start.y,dest.x,dest.y)+90,1)
	local atEnd = function ()
		art:destroy()
		endCallback.location = dest
		indirect_call(endCallback)
	end
	update_system:addLinear(art,dx,dy,speed)
	update_system:addPeriodicCallback(art,atEnd,time)
end
sat_tmp1 = sat_tmp
describeFunction("sat_tmp1",
	nil,
	{
		{"start", "position"},
		{"location", "position"}, -- todo fix naming location rather than user defined
		{"speed", "number", 4000},
		{"endCallback", "indirect_function", {call = "subspace_rift", max_time = 5, max_radius = 500, on_end = {call = "end_rift"}}, ui_suppress = {"location"}}
	})

sat_tmp2 = sat_tmp
describeFunction("sat_tmp2",
	nil,
	{
		{"start", "position"},
		{"location", "position"}, -- todo fix naming location rather than user defined
		{"speed", "number", 4000},
		{"endCallback", "indirect_function", {call = "subspace_rift", max_time = 5, max_radius = 500, on_end = {call =  "jammer_pulse", max_time = 60, max_range = 5000, onEndCallback = {call = "null_function"}}}, ui_suppress = {"location"}}
	})
sat_tmp3 = sat_tmp
describeFunction("sat_tmp3",
	nil,
	{
		{"start", "position"},
		{"location", "position"}, -- todo fix naming location rather than user defined
		{"speed", "number", 4000},
		{"endCallback", "indirect_function", {call = "subspace_rift", max_time = 5, max_radius = 500, on_end = {call = "spawn_kraylor_ship", template = "Adder MK4"}}, ui_suppress = {"location"}}
	})

function spawn_kraylor_ship(location,template)
	ship_template[template].create('Kraylor',template):setPosition(location.x,location.y)
end
describeFunction("spawn_kraylor_ship",
	nil,
	{
		{"location", "position"},
		{"template", "npc_ship"}
	})
function end_rift(args)
	local count = 15
	local dist_from_origin = 500
	local x = args.location.x
	local y = args.location.y
	local faction = "Kraylor"
	local missile_type = "HVLI"
	local size = "Small"
	local lifetime_scale = 0.5
	local start_angle = math.random(360)
	for i = 0,count do
		-- super pretty if you forget to add the start angle here but not later
		local spawn_x = x + math.sin(i*(math.pi*2/count)+(start_angle/360*2*math.pi))*dist_from_origin
		local spawn_y = y - math.cos(i*(math.pi*2/count)+(start_angle/360*2*math.pi))*dist_from_origin
		local missile = 0
		--[[
		due to not being able to set target angle non hvli dont really work at the moment
		if missile_type == "Nuke" then
			missile = Nuke()
		elseif missile_type == "EMP" then
			missile = EMPMissile()
		elseif missile_type == "HVLI" then
			missile = HVLI()
		elseif missile_type == "Homing" then
			missile = HomingMissile()
		else
			-- script error
			print("script error")
		end
		--]]
		local m = HVLI():setPosition(spawn_x,spawn_y):setHeading(i*(360/count)+start_angle):setFaction(faction):setMissileSize("Small")
		m:setLifetime(m:getLifetime()*lifetime_scale)-- targeting?
		m = HVLI():setPosition(spawn_x,spawn_y):setHeading(i*(360/count)+start_angle):setFaction(faction):setMissileSize("Medium")
		m:setLifetime(m:getLifetime()*lifetime_scale)
		m = HVLI():setPosition(spawn_x,spawn_y):setHeading(i*(360/count)+start_angle):setFaction(faction):setMissileSize("Large")
		m:setLifetime(m:getLifetime()*lifetime_scale)

		--[[
		mostly working, but useless without a target angle
		local possible_targets = missile:getObjectsInRange(5000)
		local current_best
		local current_best_value = 999999
		-- this wants to happen for non HVLI, but they are semi buggy right now, so deal with that later
		for i = 1, #possible_targets do
			local possible = possible_targets[i]
			if possible:isValid() and possible:isEnemy(missile) then
				if possible.typeName == "CpuShip" or possible.typeName == "PlayerSpaceship" or possible.typeName == "SpaceStation" then
					--local delta_angle=
					local x1,y1 = missile:getPosition()
					local x2,y2 = possible:getPosition()
					local dx,dy = x1-x2, y1-y2
					local current_value = math.sqrt(dx*dx+dy*dy)-- distance
					print(math.abs(math.atan2(dx,dy)),missile:getHeading()/360*math.pi)
					--print((math.abs(math.atan2(dy,dx))/math.pi)-(missile:getHeading()/360*math.pi))
					--current_value = current_value + ((math.abs(math.atan2(dy,dx))/math.pi)-(missile:getHeading()/360))*4000

					-- badness due to angle, debatably this is wrong in extreme cases
					-- on top of us but at a too sharp turn to make for instance
					if current_value < current_best_value then
						current_best_value = current_value
						current_best = possible
					end
				end
			end
		end
		if current_best then
			missile:setTarget(current_best)
			print(current_best:getCallSign())
		end --]]
	end
end
describeFunction("end_rift")

function subspace_rift(max_time,location,max_radius,on_end)
	-- we need graphical type at some point
	-- we also need to have a function for "run this each update"
	-- consideration needs to be given as to how to have a rift that never ends
-- we are going to require a central artifact
-- this requirement probably should be removed at some point
	local rift = getScriptStorage()._cuf_gm._ENV.newPhonySpaceObject()
-- merge with sandbox
	rift.destroy = function ()
		rift.valid = false
		-- I really need to check if these are valid before calling destroy
		rift.center:destroy()
		for j=#rift.all_elements,1,-1 do
			rift.all_elements[j]:destroy()
		end
	end
	rift.center = Artifact():setPosition(location.x,location.y):setCallSign("Subspace rift")
	rift.all_elements = {}
	rift.start_time = getScenarioTime()
	local number_in_ring = 20
	for i=number_in_ring,1,-1 do
		local clockwise_obj=Artifact()
		clockwise_obj.angle_offset=i*(3.14159*2/number_in_ring)
		clockwise_obj.orbit_speed=60/(2*math.pi)
		table.insert(rift.all_elements,clockwise_obj)
		local counterclockwise_obj=Artifact()
		counterclockwise_obj.angle_offset=i*(3.14159*2/number_in_ring)
		counterclockwise_obj.orbit_speed=-60/(2*math.pi)
		table.insert(rift.all_elements,counterclockwise_obj)
	end
	local update_data = {
	update = function (self, obj, delta)
		local max_radius = max_radius -- how large it is when it has reached the maxium size
		local max_time = math.abs(max_time) -- how long it takes to reach the maxium radius
		local current_radius = (getScenarioTime()-obj.start_time)*(max_radius/max_time)
		if current_radius > max_radius then
			if on_end ~= nil then
				on_end.location = location
				indirect_call(on_end)
			end
			rift:destroy()
			current_radius = max_radius
			return
		end
		for j=#obj.all_elements,1,-1 do
			local rift_element=obj.all_elements[j]
			if rift_element:isValid() then
				local orbit_pos=(getScenarioTime()/rift_element.orbit_speed)+rift_element.angle_offset
				rift_element:setPosition(location.x+(math.cos(orbit_pos)*current_radius),location.y+(math.sin(orbit_pos)*current_radius))
			else
				table.remove(obj.all_elements,j)
			end
		end
	end,
		edit = {},
	}
	update_system:addUpdate(rift,"subspace_rift",update_data)
end
describeFunction("subspace_rift",
	{"creates a tuneable rift effect, along with callback at end", "onclick"},
	{
		{"max_time", "number", 5, min = 0}, -- max?
		{"location", "position"},
		{"max_radius", "number", 500, min = 0}, -- max?
		{"on_end", "indirect_function", {call = "end_rift"}, ui_suppress = {"location"}}
	})

function rift_example(location,args) -- in time this should be removed
	local x = location.x
	local y = location.y
	local max_radius = args.c
	local max_time = args.d
	local onEnd = args.e
-- we are going to require a central artifact
-- this requirement probably should be removed at some point
	local rift = getScriptStorage()._cuf_gm._ENV.newPhonySpaceObject()
	rift.destroy = function ()
		rift.valid = false
		-- I really need to check if these are valid before calling destroy
		rift.center:destroy()
		for j=#rift.all_elements,1,-1 do
			rift.all_elements[j]:destroy()
		end
	end
	rift.center = Artifact():setPosition(x,y):setCallSign("Subspace rift")
	rift.all_elements = {}
	rift.start_time = getScenarioTime()
	local number_in_ring = 20
	for i=number_in_ring,1,-1 do
		local clockwise_obj=Artifact()
		clockwise_obj.angle_offset=i*(3.14159*2/number_in_ring)
		clockwise_obj.orbit_speed=60/(2*math.pi)
		table.insert(rift.all_elements,clockwise_obj)
		local counterclockwise_obj=Artifact()
		counterclockwise_obj.angle_offset=i*(3.14159*2/number_in_ring)
		counterclockwise_obj.orbit_speed=-60/(2*math.pi)
		table.insert(rift.all_elements,counterclockwise_obj)
	end
	local update_data = {
	update = function (self, obj, delta)
		local max_radius = max_radius -- how large it is when it has reached the maxium size
		local max_time = max_time -- how long it takes to reach the maxium radius
		local current_radius = (getScenarioTime()-obj.start_time)*(max_radius/max_time)
		if current_radius > max_radius then
			if onEnd ~= nil then
				indirect_call({call = onEnd})
			end
			rift:destroy()
			current_radius = max_radius
			return
		end
		for j=#obj.all_elements,1,-1 do
			local rift_element=obj.all_elements[j]
			if rift_element:isValid() then
				local orbit_pos=(getScenarioTime()/rift_element.orbit_speed)+rift_element.angle_offset
				rift_element:setPosition(x+(math.cos(orbit_pos)*current_radius),y+(math.sin(orbit_pos)*current_radius))
			else
				table.remove(obj.all_elements,j)
			end
		end
		local objs = getObjectsInRadius(x,y,current_radius)
		for i=#objs,1,-1 do
			if objs[i].typeName=="PlayerSpaceship" then
				local player_x,player_y = objs[i]:getPosition()
				local angle = (math.atan2(x-player_x,y-player_y)/math.pi*180)+90
				objs[i]:setSystemHealth("warp",objs[i]:getSystemHealth("warp")-1.5)
				objs[i]:setSystemHealth("jumpdrive",objs[i]:getSystemHealth("jumpdrive")-1.5)
				objs[i]:setSystemHealth("impulse",objs[i]:getSystemHealth("impulse")-0.5)
				objs[i]:setSystemHealth("reactor",objs[i]:getSystemHealth("reactor")-0.25)
				objs[i]:setSystemHealth("beamweapons",objs[i]:getSystemHealth("beamweapons")-0.1)
				objs[i]:setSystemHealth("missilesystem",objs[i]:getSystemHealth("missilesystem")-0.1)
				objs[i]:setSystemHealth("maneuver",objs[i]:getSystemHealth("maneuver")-0.5)
				objs[i]:setSystemHealth("frontshield",objs[i]:getSystemHealth("frontshield")-0.1)
				objs[i]:setSystemHealth("rearshield",objs[i]:getSystemHealth("rearshield")-0.1)
				setCirclePos(objs[i],player_x,player_y,-angle,max_radius*1.5)
			else
				if objs[i].typeName ~= "Artifact" then
					objs[i]:destroy()
				end
			end
		end
	end,
		edit = {},
	}
	update_system:addUpdate(rift,"subspace_rift",update_data)
end
describeFunction("rift_example",
	nil,
	{
		{"location", "position"}
	})
-- eff it short term one off code it is
function base0()
    Mine():setPosition(50548, 361587)
    Mine():setPosition(47788, 369839)
    Mine():setPosition(48502, 368983)
    Mine():setPosition(46414, 371503)
    Mine():setPosition(47050, 370731)
    Mine():setPosition(50054, 351924)
    Mine():setPosition(49090, 351208)
    Mine():setPosition(48127, 350493)
    Mine():setPosition(47164, 349777)
    Mine():setPosition(52920, 361217)
    Mine():setPosition(51734, 361402)
    Mine():setPosition(54105, 361032)
    Mine():setPosition(53368, 363356)
    Mine():setPosition(52676, 364130)
    Mine():setPosition(51972, 364927)
    Mine():setPosition(51252, 365752)
    Mine():setPosition(50513, 366608)
    Mine():setPosition(49363, 361772)
    Mine():setPosition(48177, 361957)
    Mine():setPosition(46991, 362142)
    Mine():setPosition(49862, 367370)
    Mine():setPosition(49192, 368161)
    Mine():setPosition(42891, 355079)
    Mine():setPosition(43051, 356268)
    Mine():setPosition(43211, 357457)
    Mine():setPosition(43371, 358647)
    Mine():setPosition(43531, 359836)
    Mine():setPosition(45806, 362327)
    Mine():setPosition(44058, 364090)
    Mine():setPosition(41964, 363103)
    Mine():setPosition(40769, 363220)
    Mine():setPosition(39575, 363338)
    Mine():setPosition(45757, 372304)
    Mine():setPosition(45319, 371179)
    Mine():setPosition(45109, 369997)
    Mine():setPosition(44898, 368816)
    Mine():setPosition(44688, 367634)
    Mine():setPosition(44478, 366453)
    Mine():setPosition(44268, 365271)
    Mine():setPosition(43691, 361025)
    SpaceStation():setTemplate("Small Station"):setFaction("Kraylor"):setCallSign("rift control"):setPosition(43933, 362534)
    Mine():setPosition(42490, 373019)
    Mine():setPosition(41296, 372906)
    Mine():setPosition(38906, 372680)
    Mine():setPosition(40101, 372793)
    Mine():setPosition(65567, 350962)
    Mine():setPosition(65179, 350606)
    Mine():setPosition(64740, 351765)
    Mine():setPosition(65729, 349070)
    Mine():setPosition(64668, 348963)
    Mine():setPosition(62370, 350861)
    Mine():setPosition(63506, 351018)
    Mine():setPosition(60639, 348461)
    Mine():setPosition(60908, 349958)
    Mine():setPosition(61350, 350699)
    Mine():setPosition(68145, 344799)
    Mine():setPosition(67063, 344758)
    Mine():setPosition(66649, 345525)
    Mine():setPosition(65568, 345446)
    Mine():setPosition(63855, 344517)
    Mine():setPosition(62128, 345346)
    Mine():setPosition(61127, 345174)
    Mine():setPosition(57065, 348359)
    Mine():setPosition(56368, 347576)
    Mine():setPosition(54673, 343806)
    Mine():setPosition(55036, 344783)
    Mine():setPosition(51086, 345271)
    Mine():setPosition(52455, 343627)
    Mine():setPosition(54009, 343075)
    Mine():setPosition(53974, 343118)
    Mine():setPosition(54389, 344056)
    Mine():setPosition(50754, 344086)
    Mine():setPosition(53248, 344008)
    Mine():setPosition(58554, 342019)
    Mine():setPosition(59945, 343336)
    Mine():setPosition(58818, 343017)
    Mine():setPosition(45265, 351813)
    Mine():setPosition(46031, 351000)
    Mine():setPosition(44483, 352629)
    Mine():setPosition(51017, 352639)
    Mine():setPosition(46785, 350185)
    Mine():setPosition(47532, 349364)
    Mine():setPosition(48274, 348534)
    Mine():setPosition(49016, 347691)
    Mine():setPosition(58716, 347714)
    Mine():setPosition(49762, 346830)
    Mine():setPosition(50420, 346060)
    Mine():setPosition(56530, 345724)
    Mine():setPosition(56956, 346671)
    Mine():setPosition(59653, 348145)
    Mine():setPosition(60121, 344869)
    Mine():setPosition(51980, 353355)
    Mine():setPosition(39123, 357901)
    Mine():setPosition(39967, 357100)
    Mine():setPosition(40781, 356319)
    Mine():setPosition(43783, 353347)
    Mine():setPosition(43065, 354073)
    Mine():setPosition(42327, 354808)
    Mine():setPosition(41566, 355556)
    Mine():setPosition(57059, 359399)
    Mine():setPosition(57854, 358580)
    Mine():setPosition(58565, 357857)
    Mine():setPosition(57760, 357648)
    Mine():setPosition(56797, 356933)
    Mine():setPosition(58723, 358364)
    Mine():setPosition(59687, 359080)
    Mine():setPosition(59292, 357124)
    Mine():setPosition(55833, 356217)
    Mine():setPosition(56276, 360215)
    Mine():setPosition(54870, 355502)
    Mine():setPosition(55501, 361035)
    Mine():setPosition(54729, 361864)
    Mine():setPosition(54051, 362602)
    Mine():setPosition(61611, 354822)
    Mine():setPosition(62441, 354007)
    Mine():setPosition(64493, 353664)
    Mine():setPosition(63727, 354410)
    Mine():setPosition(52944, 354071)
    Mine():setPosition(53907, 354786)
    Mine():setPosition(60040, 356376)
    Mine():setPosition(60812, 355610)
    Mine():setPosition(35098, 361623)
    Mine():setPosition(35993, 363691)
    Mine():setPosition(35961, 360835)
    Mine():setPosition(37187, 363574)
    Mine():setPosition(38381, 363456)
    Mine():setPosition(42905, 375819)
    Mine():setPosition(43655, 374891)
    Mine():setPosition(45080, 373135)
    Mine():setPosition(32933, 372115)
    Mine():setPosition(32847, 372626)
    Mine():setPosition(33026, 373812)
    Mine():setPosition(33206, 374999)
    Mine():setPosition(34798, 363809)
    Mine():setPosition(33604, 363927)
    Mine():setPosition(33587, 362992)
    Mine():setPosition(34354, 362298)
    Mine():setPosition(32795, 363705)
    Mine():setPosition(26960, 371550)
    Mine():setPosition(25765, 371437)
    Mine():setPosition(26318, 369460)
    Mine():setPosition(28154, 371663)
    Mine():setPosition(29349, 371776)
    Mine():setPosition(28723, 367344)
    Mine():setPosition(27923, 368054)
    Mine():setPosition(27134, 368750)
    Mine():setPosition(31951, 366693)
    Mine():setPosition(32130, 367880)
    Mine():setPosition(31142, 365185)
    Mine():setPosition(31772, 365506)
    Mine():setPosition(31593, 364320)
    Mine():setPosition(31978, 364438)
    Mine():setPosition(31738, 372002)
    Mine():setPosition(30544, 371889)
    Mine():setPosition(29496, 366655)
    Mine():setPosition(30356, 365888)
    Mine():setPosition(32489, 370253)
    Mine():setPosition(32668, 371439)
    Mine():setPosition(32310, 369066)
    Mine():setPosition(44379, 373996)
    Mine():setPosition(43685, 373132)
    Mine():setPosition(37712, 372567)
    Mine():setPosition(33385, 376185)
    Mine():setPosition(33743, 378558)
    Mine():setPosition(33564, 377372)
    Mine():setPosition(36517, 372454)
    Mine():setPosition(35322, 372341)
    Mine():setPosition(34128, 372228)
    Mine():setPosition(39402, 380092)
    Mine():setPosition(40142, 379204)
    Mine():setPosition(40845, 378351)
    Mine():setPosition(41483, 377573)
    Mine():setPosition(42169, 376730)
    Mine():setPosition(33922, 379745)
    Mine():setPosition(34102, 380932)
    Mine():setPosition(34281, 382118)
    Mine():setPosition(36750, 383220)
    Mine():setPosition(37402, 382456)
    Mine():setPosition(38090, 381649)
    Mine():setPosition(38745, 380874)
    Mine():setPosition(38373, 358605)
    Mine():setPosition(37597, 359328)
    Mine():setPosition(36794, 360071)
end
describeFunction("base0")
function base1()
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(36259, 358047):orderRoaming()
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(36543, 363428)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(36647, 365293)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(37244, 367062)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(38404, 368677)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(40089, 369917)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(40981, 355890)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(42659, 355243)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(44471, 355035)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(46398, 355260)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(48024, 356099)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(49667, 369788)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(50950, 368691)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(52067, 367075)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(52722, 365131)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(52992, 363224)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(45067, 372934):orderRoaming()
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(53032, 357862):orderRoaming()
	Mine():setPosition(34532, 363181)
	Mine():setPosition(34601, 364435)
	Mine():setPosition(34620, 361928)
	Mine():setPosition(34828, 365670)
	Mine():setPosition(35207, 366867)
	Mine():setPosition(35734, 368007)
	Mine():setPosition(36399, 369072)
	Mine():setPosition(37192, 370046)
	Mine():setPosition(38101, 370912)
	Mine():setPosition(39112, 371657)
	Mine():setPosition(39235, 354771)
	Mine():setPosition(40208, 372270)
	Mine():setPosition(40339, 354174)
	Mine():setPosition(41510, 353721)
	Mine():setPosition(42729, 353417)
	Mine():setPosition(43976, 353269)
	Mine():setPosition(45232, 353278)
	Mine():setPosition(46477, 353444)
	Mine():setPosition(47691, 353765)
	Mine():setPosition(48855, 354236)
	Mine():setPosition(49828, 371735)
	Mine():setPosition(49951, 354849)
	Mine():setPosition(50850, 371005)
	Mine():setPosition(51771, 370152)
	Mine():setPosition(52579, 369190)
	Mine():setPosition(53259, 368134)
	Mine():setPosition(53802, 367002)
	Mine():setPosition(54199, 365810)
	Mine():setPosition(54443, 364579)
	Mine():setPosition(54461, 362072)
	Mine():setPosition(54531, 363326)
	SpaceStation():setTemplate("Small Station"):setFaction("Kraylor"):setCallSign("rift control"):setPosition(44527, 363403)
	WarpJammer():setFaction("Kraylor"):setPosition(41023, 365191)
	WarpJammer():setFaction("Kraylor"):setPosition(44382, 359059)
	WarpJammer():setFaction("Kraylor"):setPosition(48041, 364988)
end
describeFunction("base1")
function base2()
	local unmirrored = function ()
		WarpJammer():setFaction("Kraylor"):setPosition(44527, 363403)
		SpaceStation():setTemplate("Small Station"):setFaction("Kraylor"):setCallSign("rift control"):setPosition(44527, 363403)
	end

	local mirrored = function(xy)
		ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(xy(-51284, 74864))
		ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(xy(-52010, 75912))
		ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(xy(-52857, 76880))
		ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(xy(-53784, 77687))
		ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(xy(-54809, 78424))
		ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(xy(-55865, 78946))
		ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(xy(-56969, 79364))
		ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(xy(-58087, 79674))
	end

	for i=1,6 do
		local cx=-59996 -- cx & cy should be folded in when they can
		local cy=79917
		local rotation_angle = ((3.14159*2)/6)*i
		local xy = function(x, y)
		local dist = distance(cx,cy,x,y)
		local angle = math.atan2(y-cy,x-cx) + rotation_angle
		local ncx = 44527
		local ncy = 363403
			return ncx+(math.cos(angle)*dist),ncy+(math.sin(angle)*dist)
		end
		mirrored(xy)
	end
	unmirrored()
	end
describeFunction("base2")
function base3()
	SpaceStation():setTemplate("Small Station"):setFaction("Kraylor"):setCallSign("rift control"):setPosition(43834, 365100)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(35614, 363881)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(35981, 358514):orderRoaming()
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(36629, 365136)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(37837, 366412)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(38835, 351154):orderRoaming()
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(38861, 367660)
	ship_template["Missile Pod TI2"].create('Kraylor',"Missile Pod TI2"):setPosition(41439, 349389)
	ship_template["Missile Pod TI2"].create('Kraylor',"Missile Pod TI2"):setPosition(41521, 352690)
	ship_template["Missile Pod TI2"].create('Kraylor',"Missile Pod TI2"):setPosition(41983, 351122)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(44192, 369526):orderRoaming()
	ship_template["Missile Pod TI2"].create('Kraylor',"Missile Pod TI2"):setPosition(45796, 349257)
	ship_template["Missile Pod TI2"].create('Kraylor',"Missile Pod TI2"):setPosition(45829, 351089)
	ship_template["Missile Pod TI2"].create('Kraylor',"Missile Pod TI2"):setPosition(46324, 353070)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(48867, 351098):orderRoaming()
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(49076, 368536)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(50148, 367484)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(51192, 366421)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(52236, 365160)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(52662, 359883):orderRoaming()
	ship_template["Command Base"].create('Kraylor',"Command Base"):setPosition(33539, 353054):orderRoaming()
	ship_template["Command Base"].create('Kraylor',"Command Base"):setPosition(54234, 353691):orderRoaming()
	Mine():setPosition(31040, 351922)
	Mine():setPosition(31077, 353122)
	Mine():setPosition(31098, 351341)
	Mine():setPosition(31114, 354321)
	Mine():setPosition(31151, 355521)
	Mine():setPosition(31188, 356720)
	Mine():setPosition(31225, 357920)
	Mine():setPosition(31262, 359119)
	Mine():setPosition(31299, 360318)
	Mine():setPosition(31408, 361528)
	Mine():setPosition(31507, 362178)
	Mine():setPosition(32173, 350807)
	Mine():setPosition(32289, 363088)
	Mine():setPosition(33071, 363998)
	Mine():setPosition(33247, 350273)
	Mine():setPosition(33853, 364908)
	Mine():setPosition(34322, 349740)
	Mine():setPosition(34635, 365818)
	Mine():setPosition(35397, 349206)
	Mine():setPosition(35418, 366728)
	Mine():setPosition(36200, 367638)
	Mine():setPosition(36472, 348672)
	Mine():setPosition(36982, 368548)
	Mine():setPosition(37546, 348138)
	Mine():setPosition(37764, 369458)
	Mine():setPosition(38547, 370368)
	Mine():setPosition(38621, 347605)
	Mine():setPosition(39329, 371278)
	Mine():setPosition(39696, 347071)
	Mine():setPosition(40111, 372188)
	Mine():setPosition(40771, 346537)
	Mine():setPosition(40893, 373098)
	Mine():setPosition(41676, 374008)
	Mine():setPosition(41846, 346004)
	Mine():setPosition(42561, 374874)
	Mine():setPosition(43351, 375807)
	Mine():setPosition(44043, 376789)
	Mine():setPosition(44787, 375825)
	Mine():setPosition(45685, 374945)
	Mine():setPosition(45719, 345997)
	Mine():setPosition(46530, 374010)
	Mine():setPosition(46839, 346583)
	Mine():setPosition(47347, 373130)
	Mine():setPosition(47918, 347108)
	Mine():setPosition(48163, 372250)
	Mine():setPosition(48979, 371371)
	Mine():setPosition(48997, 347633)
	Mine():setPosition(49795, 370491)
	Mine():setPosition(50076, 348158)
	Mine():setPosition(50611, 369611)
	Mine():setPosition(51155, 348683)
	Mine():setPosition(51427, 368731)
	Mine():setPosition(52234, 349208)
	Mine():setPosition(52243, 367851)
	Mine():setPosition(53059, 366971)
	Mine():setPosition(53313, 349732)
	Mine():setPosition(53875, 366092)
	Mine():setPosition(54393, 350257)
	Mine():setPosition(54691, 365212)
	Mine():setPosition(55472, 350782)
	Mine():setPosition(55507, 364332)
	Mine():setPosition(56323, 363452)
	Mine():setPosition(56551, 351307)
	Mine():setPosition(56739, 351157)
	Mine():setPosition(56796, 352356)
	Mine():setPosition(56853, 353554)
	Mine():setPosition(56909, 354753)
	Mine():setPosition(56966, 355952)
	Mine():setPosition(57023, 357150)
	Mine():setPosition(57080, 358349)
	Mine():setPosition(57137, 359548)
	Mine():setPosition(57139, 362572)
	Mine():setPosition(57194, 360746)
	Mine():setPosition(57251, 361945)
	WarpJammer():setFaction("Kraylor"):setPosition(43780, 355428)
	WarpJammer():setFaction("Kraylor"):setPosition(43843, 362397)
end
describeFunction("base3")
function base4()
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(34891, 362666)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(34924, 361273)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(35714, 363203)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(35784, 360846)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(36916, 363689)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(36962, 360453)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(37263, 364845)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(37355, 359297)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(37771, 365838)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(38026, 358141)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(38464, 364015)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(38667, 360221)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(39690, 367919)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(39944, 356153)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(40289, 363813)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(40463, 360366)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(40823, 355645)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(40915, 368566)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(41651, 360597)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(41853, 363204)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(41853, 367259)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(41911, 356948)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(41998, 358628)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(41998, 365550)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(42071, 355344)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(42071, 368959)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(42462, 359902)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(42464, 354119)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(42533, 370138)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(42635, 363928)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(43150, 352914)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(43180, 371155)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(44521, 371178)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(44610, 352914)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(45011, 363842)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(45126, 359960)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(45145, 370115)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(45168, 354189)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(45538, 355368)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(45590, 365464)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(45611, 360769)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(45619, 358744)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(45655, 363319)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(45677, 356745)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(45677, 368867)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(45822, 367028)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(46786, 355830)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(46786, 368474)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(47062, 363759)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(47238, 360241)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(47641, 356338)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(47803, 367757)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(48733, 364067)
	ship_template["Missile Pod S1"].create('Kraylor',"Missile Pod S1"):setPosition(48777, 360109)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(49428, 358138)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(49555, 366064)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(50054, 359155)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(50061, 365008)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(50449, 360285)
	ship_template["Missile Pod D4"].create('Kraylor',"Missile Pod D4"):setPosition(50580, 363803)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(51625, 360656)
	ship_template["Missile Pod T1"].create('Kraylor',"Missile Pod T1"):setPosition(51751, 363275)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(52901, 362699)
	ship_template["Missile Pod D1"].create('Kraylor',"Missile Pod D1"):setPosition(52911, 361252)
	Mine():setPosition(31693, 357171)
	Mine():setPosition(31725, 357748)
	Mine():setPosition(31789, 356402)
	Mine():setPosition(31834, 366763)
	Mine():setPosition(31834, 367388)
	Mine():setPosition(31834, 368035)
	Mine():setPosition(31853, 355728)
	Mine():setPosition(31853, 358421)
	Mine():setPosition(31885, 355151)
	Mine():setPosition(31926, 366104)
	Mine():setPosition(31981, 359030)
	Mine():setPosition(31982, 365464)
	Mine():setPosition(31991, 368660)
	Mine():setPosition(32077, 354478)
	Mine():setPosition(32125, 369262)
	Mine():setPosition(32176, 364824)
	Mine():setPosition(32238, 359575)
	Mine():setPosition(32392, 369842)
	Mine():setPosition(32398, 353837)
	Mine():setPosition(32430, 360153)
	Mine():setPosition(32482, 364212)
	Mine():setPosition(32682, 370422)
	Mine():setPosition(32718, 353196)
	Mine():setPosition(32788, 363627)
	Mine():setPosition(32847, 360698)
	Mine():setPosition(32928, 370980)
	Mine():setPosition(33231, 352747)
	Mine():setPosition(33307, 371493)
	Mine():setPosition(33616, 352138)
	Mine():setPosition(33686, 372007)
	Mine():setPosition(34155, 372319)
	Mine():setPosition(34193, 351625)
	Mine():setPosition(34579, 372743)
	Mine():setPosition(34738, 351144)
	Mine():setPosition(35092, 373122)
	Mine():setPosition(35379, 350823)
	Mine():setPosition(35628, 373412)
	Mine():setPosition(35989, 350503)
	Mine():setPosition(36208, 373658)
	Mine():setPosition(36630, 350150)
	Mine():setPosition(36810, 373859)
	Mine():setPosition(37271, 349990)
	Mine():setPosition(37457, 374059)
	Mine():setPosition(37944, 349893)
	Mine():setPosition(38082, 374126)
	Mine():setPosition(38682, 349893)
	Mine():setPosition(38707, 374171)
	Mine():setPosition(39331, 374126)
	Mine():setPosition(39387, 349990)
	Mine():setPosition(39956, 374059)
	Mine():setPosition(40028, 349990)
	Mine():setPosition(40581, 373970)
	Mine():setPosition(40701, 350182)
	Mine():setPosition(41161, 373769)
	Mine():setPosition(41343, 350438)
	Mine():setPosition(41763, 373502)
	Mine():setPosition(41952, 350727)
	Mine():setPosition(42360, 373171)
	Mine():setPosition(42529, 350983)
	Mine():setPosition(45170, 373087)
	Mine():setPosition(45703, 350791)
	Mine():setPosition(45781, 373379)
	Mine():setPosition(46216, 350470)
	Mine():setPosition(46308, 373620)
	Mine():setPosition(46793, 350310)
	Mine():setPosition(46901, 373774)
	Mine():setPosition(47434, 350118)
	Mine():setPosition(47495, 373928)
	Mine():setPosition(48107, 350022)
	Mine():setPosition(48110, 374038)
	Mine():setPosition(48703, 374082)
	Mine():setPosition(48845, 349990)
	Mine():setPosition(49319, 374060)
	Mine():setPosition(49486, 349990)
	Mine():setPosition(49956, 374016)
	Mine():setPosition(50159, 350086)
	Mine():setPosition(50571, 373906)
	Mine():setPosition(50800, 350342)
	Mine():setPosition(51164, 373686)
	Mine():setPosition(51345, 350470)
	Mine():setPosition(51758, 373423)
	Mine():setPosition(51954, 350663)
	Mine():setPosition(52307, 373093)
	Mine():setPosition(52532, 351015)
	Mine():setPosition(52856, 372807)
	Mine():setPosition(53109, 351496)
	Mine():setPosition(53340, 372434)
	Mine():setPosition(53590, 351913)
	Mine():setPosition(53801, 372016)
	Mine():setPosition(54070, 352298)
	Mine():setPosition(54219, 371577)
	Mine():setPosition(54455, 352747)
	Mine():setPosition(54570, 371115)
	Mine():setPosition(54814, 360616)
	Mine():setPosition(54841, 353256)
	Mine():setPosition(54922, 370610)
	Mine():setPosition(54936, 363572)
	Mine():setPosition(55082, 353818)
	Mine():setPosition(55109, 359973)
	Mine():setPosition(55181, 370092)
	Mine():setPosition(55202, 364228)
	Mine():setPosition(55323, 354380)
	Mine():setPosition(55403, 359465)
	Mine():setPosition(55416, 369601)
	Mine():setPosition(55501, 364868)
	Mine():setPosition(55501, 369004)
	Mine():setPosition(55564, 354969)
	Mine():setPosition(55608, 365486)
	Mine():setPosition(55644, 358876)
	Mine():setPosition(55671, 355691)
	Mine():setPosition(55714, 368428)
	Mine():setPosition(55757, 366040)
	Mine():setPosition(55778, 367874)
	Mine():setPosition(55805, 356334)
	Mine():setPosition(55805, 356949)
	Mine():setPosition(55805, 357538)
	Mine():setPosition(55805, 358207)
	Mine():setPosition(55842, 367256)
	Mine():setPosition(55863, 366637)
	SpaceStation():setTemplate("Medium Station"):setFaction("Kraylor"):setPosition(43721, 362138):setCallSign("rift control")
	WarpJammer():setFaction("Kraylor"):setPosition(33706, 362112)
	WarpJammer():setFaction("Kraylor"):setPosition(36327, 369458)
	WarpJammer():setFaction("Kraylor"):setPosition(36358, 354485)
	WarpJammer():setFaction("Kraylor"):setPosition(38754, 356898)
	WarpJammer():setFaction("Kraylor"):setPosition(38837, 367160)
	WarpJammer():setFaction("Kraylor"):setPosition(43719, 362112)
	WarpJammer():setFaction("Kraylor"):setPosition(43719, 371959)
	WarpJammer():setFaction("Kraylor"):setPosition(43967, 352016)
	WarpJammer():setFaction("Kraylor"):setPosition(48850, 356981)
	WarpJammer():setFaction("Kraylor"):setPosition(48850, 367077)
	WarpJammer():setFaction("Kraylor"):setPosition(51316, 369529)
	WarpJammer():setFaction("Kraylor"):setPosition(51377, 354478)
	WarpJammer():setFaction("Kraylor"):setPosition(53732, 361946)
end
describeFunction("base4")
function base5()
	SpaceStation():setTemplate("Medium Station"):setFaction("Kraylor"):setPosition(43865, 362200):setCallSign("rift control")
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(24362, 365090)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(24514, 359113)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(25905, 365049)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(26021, 359200)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(27466, 364797)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(27498, 359417)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(28774, 359941)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(28840, 364413)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(30081, 363821)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(30114, 360516)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(31122, 361308)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(31122, 362689)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(32529, 355958)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(32529, 368230)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(37524, 350946)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(37714, 373415)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(40218, 362316)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(40891, 381571)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(41111, 342771)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(41137, 380176)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(41209, 344164)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(41381, 345665)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(41610, 378889)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(41920, 377492)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(41925, 347260)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(42497, 376345)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(42510, 348717)
	ship_template["Missile Pod S4"].create('Kraylor',"Missile Pod S4"):setPosition(42675, 361220)
	ship_template["Missile Pod S4"].create('Kraylor',"Missile Pod S4"):setPosition(42751, 363312)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(43290, 375590)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(43308, 349462)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(43798, 358438)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(43844, 366062)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(44179, 349462)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(44285, 375569)
	ship_template["Missile Pod S4"].create('Kraylor',"Missile Pod S4"):setPosition(44821, 363375)
	ship_template["Missile Pod S4"].create('Kraylor',"Missile Pod S4"):setPosition(44867, 361175)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(44901, 376531)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(45013, 348676)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(45429, 377613)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(45510, 347260)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(45842, 378912)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(46119, 345630)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(46282, 380111)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(46355, 344162)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(46402, 342711)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(46466, 381450)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(47633, 362273)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(50003, 373388)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(50336, 350872)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(55122, 368789)
	CpuShip():setFaction("Kraylor"):setTemplate("Defense platform"):setPosition(55201, 355855)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(57168, 361672)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(57190, 362974)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(58113, 363828)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(58114, 360953)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(59177, 364469)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(59357, 360429)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(60492, 364815)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(60495, 359974)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(61783, 359575)
	ship_template["Missile Pod T2"].create('Kraylor',"Missile Pod T2"):setPosition(61783, 365083)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(63271, 365230)
	ship_template["Missile Pod D2"].create('Kraylor',"Missile Pod D2"):setPosition(63273, 359369)
	ship_template["Command Base"].create('Kraylor',"Command Base"):setPosition(37613, 368219):orderRoaming()
	ship_template["Command Base"].create('Kraylor',"Command Base"):setPosition(37688, 356218):orderRoaming()
	ship_template["Command Base"].create('Kraylor',"Command Base"):setPosition(49392, 356259):orderRoaming()
	ship_template["Command Base"].create('Kraylor',"Command Base"):setPosition(49975, 368123):orderRoaming()
	Mine():setPosition(20085, 359251)
	Mine():setPosition(20522, 365676)
	Mine():setPosition(20933, 358402)
	Mine():setPosition(20934, 360099)
	Mine():setPosition(21371, 364827)
	Mine():setPosition(21371, 366524)
	Mine():setPosition(21781, 357553)
	Mine():setPosition(21782, 359250)
	Mine():setPosition(22219, 365676)
	Mine():setPosition(22219, 367373)
	Mine():setPosition(22629, 356704)
	Mine():setPosition(22630, 358401)
	Mine():setPosition(23068, 366524)
	Mine():setPosition(23068, 368221)
	Mine():setPosition(23477, 355855)
	Mine():setPosition(23478, 357552)
	Mine():setPosition(23916, 367373)
	Mine():setPosition(23916, 369070)
	Mine():setPosition(24325, 355006)
	Mine():setPosition(24326, 356703)
	Mine():setPosition(24765, 368221)
	Mine():setPosition(24765, 369918)
	Mine():setPosition(25173, 354157)
	Mine():setPosition(25174, 355854)
	Mine():setPosition(25613, 369070)
	Mine():setPosition(25613, 370767)
	Mine():setPosition(26021, 353308)
	Mine():setPosition(26022, 355005)
	Mine():setPosition(26462, 369918)
	Mine():setPosition(26462, 371615)
	Mine():setPosition(26869, 352458)
	Mine():setPosition(26870, 354156)
	Mine():setPosition(27310, 370767)
	Mine():setPosition(27310, 372464)
	Mine():setPosition(27717, 351609)
	Mine():setPosition(27718, 353306)
	Mine():setPosition(28159, 371615)
	Mine():setPosition(28159, 373312)
	Mine():setPosition(28565, 350760)
	Mine():setPosition(28566, 352457)
	Mine():setPosition(29007, 372464)
	Mine():setPosition(29007, 374161)
	Mine():setPosition(29413, 349911)
	Mine():setPosition(29414, 351608)
	Mine():setPosition(29856, 373312)
	Mine():setPosition(29856, 375009)
	Mine():setPosition(30261, 349062)
	Mine():setPosition(30262, 350759)
	Mine():setPosition(30704, 374161)
	Mine():setPosition(30704, 375858)
	Mine():setPosition(31109, 348213)
	Mine():setPosition(31110, 349910)
	Mine():setPosition(31553, 375009)
	Mine():setPosition(31553, 376706)
	Mine():setPosition(31957, 347364)
	Mine():setPosition(31958, 349061)
	Mine():setPosition(32401, 375858)
	Mine():setPosition(32401, 377555)
	Mine():setPosition(32805, 346515)
	Mine():setPosition(32806, 348212)
	Mine():setPosition(33250, 376706)
	Mine():setPosition(33250, 378403)
	Mine():setPosition(33653, 345666)
	Mine():setPosition(33654, 347363)
	Mine():setPosition(34098, 377555)
	Mine():setPosition(34098, 379252)
	Mine():setPosition(34501, 344817)
	Mine():setPosition(34502, 346514)
	Mine():setPosition(34947, 378403)
	Mine():setPosition(34947, 380101)
	Mine():setPosition(35349, 343968)
	Mine():setPosition(35350, 345665)
	Mine():setPosition(35796, 379252)
	Mine():setPosition(35796, 380949)
	Mine():setPosition(36197, 343119)
	Mine():setPosition(36198, 344816)
	Mine():setPosition(36644, 380101)
	Mine():setPosition(36644, 381798)
	Mine():setPosition(37045, 342270)
	Mine():setPosition(37046, 343967)
	Mine():setPosition(37493, 380949)
	Mine():setPosition(37493, 382646)
	Mine():setPosition(37893, 341421)
	Mine():setPosition(37894, 343118)
	Mine():setPosition(38341, 381798)
	Mine():setPosition(38341, 383495)
	Mine():setPosition(38741, 340572)
	Mine():setPosition(38742, 342269)
	Mine():setPosition(39190, 382646)
	Mine():setPosition(39190, 384343)
	Mine():setPosition(39589, 339723)
	Mine():setPosition(39590, 341420)
	Mine():setPosition(40038, 383495)
	Mine():setPosition(40038, 385192)
	Mine():setPosition(40437, 338873)
	Mine():setPosition(40438, 340571)
	Mine():setPosition(40887, 384343)
	Mine():setPosition(40887, 386040)
	Mine():setPosition(41286, 339721)
	Mine():setPosition(41735, 385192)
	Mine():setPosition(45951, 339358)
	Mine():setPosition(46250, 384745)
	Mine():setPosition(46799, 340207)
	Mine():setPosition(46800, 338510)
	Mine():setPosition(47097, 385594)
	Mine():setPosition(47099, 383897)
	Mine():setPosition(47647, 341056)
	Mine():setPosition(47648, 339359)
	Mine():setPosition(47947, 384746)
	Mine():setPosition(47948, 383049)
	Mine():setPosition(48494, 341905)
	Mine():setPosition(48496, 340208)
	Mine():setPosition(48796, 383899)
	Mine():setPosition(48798, 382201)
	Mine():setPosition(49342, 342754)
	Mine():setPosition(49344, 341057)
	Mine():setPosition(49645, 383051)
	Mine():setPosition(49647, 381354)
	Mine():setPosition(50190, 343603)
	Mine():setPosition(50192, 341906)
	Mine():setPosition(50495, 382203)
	Mine():setPosition(50496, 380506)
	Mine():setPosition(51038, 344453)
	Mine():setPosition(51039, 342756)
	Mine():setPosition(51344, 381355)
	Mine():setPosition(51345, 379658)
	Mine():setPosition(51886, 345302)
	Mine():setPosition(51887, 343605)
	Mine():setPosition(52193, 380507)
	Mine():setPosition(52195, 378810)
	Mine():setPosition(52734, 346151)
	Mine():setPosition(52735, 344454)
	Mine():setPosition(53043, 379660)
	Mine():setPosition(53044, 377963)
	Mine():setPosition(53582, 347000)
	Mine():setPosition(53583, 345303)
	Mine():setPosition(53892, 378812)
	Mine():setPosition(53893, 377115)
	Mine():setPosition(54430, 347849)
	Mine():setPosition(54431, 346152)
	Mine():setPosition(54741, 377964)
	Mine():setPosition(54743, 376267)
	Mine():setPosition(55278, 348698)
	Mine():setPosition(55279, 347001)
	Mine():setPosition(55590, 377116)
	Mine():setPosition(55592, 375419)
	Mine():setPosition(56126, 349547)
	Mine():setPosition(56127, 347850)
	Mine():setPosition(56440, 376269)
	Mine():setPosition(56441, 374572)
	Mine():setPosition(56974, 350396)
	Mine():setPosition(56975, 348699)
	Mine():setPosition(57289, 375421)
	Mine():setPosition(57290, 373724)
	Mine():setPosition(57822, 351245)
	Mine():setPosition(57823, 349548)
	Mine():setPosition(58138, 374573)
	Mine():setPosition(58140, 372876)
	Mine():setPosition(58670, 352095)
	Mine():setPosition(58671, 350398)
	Mine():setPosition(58988, 373725)
	Mine():setPosition(58989, 372028)
	Mine():setPosition(59518, 352944)
	Mine():setPosition(59519, 351247)
	Mine():setPosition(59837, 372878)
	Mine():setPosition(59838, 371181)
	Mine():setPosition(60366, 353793)
	Mine():setPosition(60367, 352096)
	Mine():setPosition(60686, 372030)
	Mine():setPosition(60688, 370333)
	Mine():setPosition(61214, 354642)
	Mine():setPosition(61215, 352945)
	Mine():setPosition(61535, 371182)
	Mine():setPosition(61537, 369485)
	Mine():setPosition(62062, 355491)
	Mine():setPosition(62063, 353794)
	Mine():setPosition(62385, 370334)
	Mine():setPosition(62386, 368637)
	Mine():setPosition(62910, 356340)
	Mine():setPosition(62911, 354643)
	Mine():setPosition(63234, 369487)
	Mine():setPosition(63236, 367789)
	Mine():setPosition(63757, 357189)
	Mine():setPosition(63759, 355492)
	Mine():setPosition(64083, 368639)
	Mine():setPosition(64085, 366942)
	Mine():setPosition(64605, 358038)
	Mine():setPosition(64607, 356341)
	Mine():setPosition(64933, 367791)
	Mine():setPosition(64934, 366094)
	Mine():setPosition(65453, 358887)
	Mine():setPosition(65455, 357190)
	Mine():setPosition(65782, 366943)
	Mine():setPosition(65783, 365246)
	Mine():setPosition(66301, 359737)
	Mine():setPosition(66302, 358040)
	Mine():setPosition(66631, 366095)
	Mine():setPosition(66633, 364398)
	Mine():setPosition(67150, 358889)
	Mine():setPosition(67480, 365248)
	WarpJammer():setFaction("Kraylor"):setPosition(26331, 362254)
	WarpJammer():setFaction("Kraylor"):setPosition(34997, 353254)
	WarpJammer():setFaction("Kraylor"):setPosition(35158, 370882)
	WarpJammer():setFaction("Kraylor"):setPosition(43736, 379711)
	WarpJammer():setFaction("Kraylor"):setPosition(43805, 344713)
	WarpJammer():setFaction("Kraylor"):setPosition(43865, 362200)
	WarpJammer():setFaction("Kraylor"):setPosition(52655, 371014)
	WarpJammer():setFaction("Kraylor"):setPosition(52673, 353298)
	WarpJammer():setFaction("Kraylor"):setPosition(61374, 362198)
end
describeFunction("base5")
function call_list(args)
	assert(type(args.call_list)=="table")
	for i=1, #args.call_list do
		indirect_call(args.call_list[i])
	end
end
describeFunction("call_list")

function old_test_end()
	_ENV = getScriptStorage()._cuf_gm._ENV
	fleet_custom:removeCustom("tmp")
end
describeFunction("old_test_end")

function null_function()
end
describeFunction("null_function")

function jammer_pulse(max_time,max_range,location,onEndCallback)
	local jammer = WarpJammer():setPosition(location.x,location.y)
	local update_data = {
		update = function (self, obj, delta)
			self.t = self.t + delta
			if self.t > self.max_time then
				indirect_call(onEndCallback)
				obj:destroy()
			end
			obj:setRange(math.sin((self.t/self.max_time)*math.pi)*self.max_range)
		end,
		edit = {},
		t = 0,
		max_time = max_time,
		max_range = max_range,
	}
	update_system:addUpdate(jammer,"dynamic jammer",update_data)
end
describeFunction("jammer_pulse",
	nil,
	{
		{"max_time", "number", 60},
		{"max_range", "number", 5000},
		{"location", "position"},
		{"onEndCallback", "indirect_function", {call = "null_function"}} -- change to function
	})

function old_test_start(args)
	_ENV = getScriptStorage()._cuf_gm._ENV

	local max_time = args.max_time
	local energy_cost = args.max_range
	local max_range = args.max_range
	local no_eng_msg = args.no_eng_msg
	fleet_custom:addCustomButton("Science","tmp",args.name,wrapWithErrorHandling(function (p)
		if p ~= nil then
			if p:getEnergyLevel() < args.energy_cost then
				p:wrappedAddCustomMessage("Science","no_ene",no_eng_msg)
			else
				local jammer = WarpJammer():setPosition(p:getPosition())
				local update_data = {
					-- todo this should be using jammer_pulse
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
				}
				update_system:addUpdate(jammer,"dynamic jammer",update_data)
				p:setEnergyLevel(p:getEnergyLevel()-energy_cost)
				addGMMessage("sat button clicked on " .. p:getCallSign() .. "set result in artifact single scan")
			end
		end
	end))
end
describeFunction("old_test_start")

function old_test_comms(args)
	local msg = args.msg
	fleet_custom:addCustomMessage("Science","injected_msg",msg)
end
describeFunction("old_test_comms")

function set_timer_purpose(reason)
	assert(type(reason)=="string")
	timer_purpose = reason
end
describeFunction("set_timer_purpose",
	nil,
	{
		{"reason", "string"},
	})