models = {}
function ModelData ()
	local data = {}
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
	table.insert(models,data)
	return ret
end
require("model_data.lua")
return models
