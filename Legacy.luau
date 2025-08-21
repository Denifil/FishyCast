--!strict
local ServerScript = game.ServerScriptService
local Mods = ServerScript.Modules
local TypedSignaller = require(Mods.TypedSignals)
local RS = game:GetService("RunService")
local SimulationType = RS.PostSimulation

local CasterFuncs = {}
CasterFuncs.__index = CasterFuncs

export type Signal = TypedSignaller.Signal;
export type Connection = TypedSignaller.Connection;

export type Trajectory = {
	StartTime: number,
	Origin: Vector3,
	InitVelocity: Vector3,
}
export type CastRuntimeInfo = {
	LstTrajectory:Trajectory;
	DistanceTravel:number;
	LifeTime:number?;
	TotalDeltaT:number;
}
export type FCast = {
	RunTimeInfo:CastRuntimeInfo;
	Caster:FCasterObj;
	Behaviour:CasterBehaviour;--Copied from caster
	InitData:{
		Origin:Vector3;
		InitVelocity:Vector3;
		Dir:Vector3?;
	};
	Connection:RBXScriptConnection?;
}

export type CasterBehaviour = {
	RayParams:RaycastParams;
	PrecisionMode:"HIT_VERIFY"|"OFF"|"ALWAYS";
	PrecisionSubSize:number;
	MaxDistance:number?;
	Acceleration:Vector3;
	PierceEvalFunc:(Cast:FCast,RayCast:RaycastResult,Velocity:Vector3)->boolean;
}
export type FCasterObj = typeof(setmetatable({},CasterFuncs)) & {--Add metatable to typing and & to intersect adding two types
	Behaviour:CasterBehaviour;
	--Events
	OnHit:Signal;
	OnPierce:Signal;
	OnTick:Signal;
	OnEnd:Signal;
}

export type GeneralCasterOBJ = FCasterObj|CasterBehaviour

local FishyCasting = {}

local function EvaluatePosAtTime(Time:number,Origin:Vector3,InitVelocity:Vector3,Acceleration:Vector3)
	--Derived from s = ut + 1/2(a*t^2)
	local Displacement:Vector3 = (InitVelocity*Time) + (0.5*Time^2*Acceleration)  
	return Origin + Displacement
end

local function EvaluateVelAtTime(Time:number,InitVelocity:Vector3,Acceleration:Vector3)
	--V = u + a*t
	return InitVelocity + Acceleration*Time
end

function FishyCasting.new(ObjType:"Caster"|"Behaviour"):GeneralCasterOBJ?
	if ObjType == "Caster" then
		return FishyCasting.NewCaster()
	elseif ObjType == "Behaviour" then
		return FishyCasting.NewBehaviour()
	end;return nil
end

function FishyCasting.NewCaster():FCasterObj
	local Caster = setmetatable({
		OnHit = TypedSignaller.new();
		OnPierce = TypedSignaller.new();
		OnTick = TypedSignaller.new();
		OnEnd = TypedSignaller.new();	
	},CasterFuncs) :: FCasterObj
	Caster.Behaviour = {} :: CasterBehaviour
	return Caster
end

function FishyCasting.NewBehaviour():CasterBehaviour
	return {--Default Behviour
		RayParams = RaycastParams.new();
		PrecisionMode = "HIT_VERIFY";
		PrecisionSubSize = 0.1;
		MaxDistance = 1000;
		Acceleration = Vector3.new(0,-workspace.Gravity,0);
		PierceEvalFunc = function() return false end;
	}
end
-----------------------CASTER FUNCS-----------------------
function CasterFuncs:Fire(Origin:Vector3,Dir:Vector3,InitVelocity:Vector3):FCast
	local self:FCasterObj = self
	local Cast:FCast = {
		Caster = self;
		Behaviour = self.Behaviour;
		RunTimeInfo = CasterFuncs.NewRuntimeInfo();
		InitData = {
			Origin=Origin;
			InitVelocity=InitVelocity;
			Dir = Dir;
		};
	}
	--Add the initial trajectory
	Cast.RunTimeInfo.LstTrajectory = {
		StartTime = 0;
		Origin = Origin;
		InitVelocity = InitVelocity;
	}
	--Start the connection
	local function Simulate(dt)
		local LstDelta = Cast.RunTimeInfo.TotalDeltaT
		Cast.RunTimeInfo.TotalDeltaT += dt
		local LstTrajectory = Cast.RunTimeInfo.LstTrajectory
		local NewTrajectory:Trajectory = {
			StartTime = Cast.RunTimeInfo.TotalDeltaT;
			Origin = EvaluatePosAtTime(Cast.RunTimeInfo.TotalDeltaT,LstTrajectory.Origin,LstTrajectory.InitVelocity,self.Behaviour.Acceleration);
			InitVelocity = EvaluateVelAtTime(Cast.RunTimeInfo.TotalDeltaT,LstTrajectory.InitVelocity,self.Behaviour.Acceleration);
		}
		--Cast Between Points 
		--By first getting Dir and then using Origin and precoded Params
		local Dir = (NewTrajectory.Origin - LstTrajectory.Origin).Unit * NewTrajectory.InitVelocity.Magnitude * dt
		local RayCast = workspace:Raycast(LstTrajectory.Origin,Dir,self.Behaviour.RayParams)
		
		local EndPoint = RayCast and RayCast.Position or NewTrajectory.Origin
		local Displacement = (EndPoint - LstTrajectory.Origin).Magnitude
		self.OnTick:Fire(Cast,EndPoint,Dir,Displacement, NewTrajectory.InitVelocity)
		
		if not RayCast then return end
		--On Hit
		local SubVel = NewTrajectory.InitVelocity
		if Cast.Behaviour.PrecisionMode == "HIT_VERIFY" then
			--Break down the cast into Behaviour.PrecisionSubSize
			local DivLengths = math.floor(Displacement/Cast.Behaviour.PrecisionSubSize)
			local NewOrigin = (DivLengths*Cast.Behaviour.PrecisionSubSize) * (EndPoint - LstTrajectory.Origin).Unit
			NewTrajectory.Origin = NewOrigin
			--We undershoot a bit but we don't care since we will just start the next cast from this undershoot anyways
			local TimeIncr = dt/DivLengths
			local Elapsed = LstDelta
			for _ = 1,DivLengths do
				Elapsed += TimeIncr
				local SubPos = EvaluatePosAtTime(Elapsed,LstTrajectory.Origin,LstTrajectory.InitVelocity,self.Behaviour.Acceleration)
				SubVel =  EvaluateVelAtTime(Elapsed,LstTrajectory.InitVelocity,self.Behaviour.Acceleration)
				Cast.RunTimeInfo.LstTrajectory = {
					StartTime = Elapsed;
					Origin = SubPos;
					InitVelocity = SubVel;
				}
				--Check for hits
				local RayCast = workspace:Raycast(SubPos,SubVel.Unit*SubVel.Magnitude,self.Behaviour.RayParams)
				if RayCast then Cast.RunTimeInfo.LstTrajectory = NewTrajectory;break end
			end
		end
		--Now we can check for pierce
		if Cast.Behaviour.PierceEvalFunc(Cast, RayCast, SubVel) then self.OnPierce:Fire(Cast, RayCast, SubVel)
		else self.OnHit:Fire(Cast, RayCast, SubVel) end
	end
	Cast.Connection = SimulationType:Connect(Simulate)
	return Cast
end

function CasterFuncs.NewRuntimeInfo():CastRuntimeInfo
	return {
		LstTrajectory = {} :: Trajectory;
		CurrTrajectory = {} :: Trajectory;
		DistanceTravel = 0;
		LifeTime = nil;
		TotalDeltaT = 0;
	} :: CastRuntimeInfo
end

return FishyCasting
