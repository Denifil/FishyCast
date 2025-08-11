local RS = game:GetService("RunService")

export type Trajectory = {
    StartTime: number;
    EndTime: number;
    Origin: Vector3;
    InitialVelocity: Vector3;
}

export type FCastSettings = {
   --Minicasts mean smaller casts being more accurate for throttled there are none,for default it does it on hit and for minicasts it's always on
    Performance:"THROTTLED"|"DEFAULT"|"MINICASTS";
    Acceleration:Vector3;
    LstTrajectory:Trajectory;
    Time:number;
}

export type FCaster = {
    MetaData:{
        ID:number;
        LinkedObj:Instance?;
    };
    
}

local FishyCast = {}
FishyCast.ObjectPool = {}


return FishyCast