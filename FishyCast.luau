local RS = game:GetService("RunService")

export type Trajectory = {
    InitPos:Vector3;
    InitVelocity:Vector3;
    
}

export type FCastSettings = {
   --Minicasts mean smaller casts being more accurate for throttled there are none,for default it does it on hit and for minicasts it's always on
    Performance:"THROTTLED"|"DEFAULT"|"MINICASTS";
    
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