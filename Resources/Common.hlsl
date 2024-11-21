#pragma once
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

#include "Assets/Resources/Library/Math.hlsl"
#include "Assets/Resources/Library/Transform.hlsl"
#include "Assets/Resources/Library/Color.hlsl"

SamplerState Smp_ClampU_ClampV_Linear;
SamplerState Smp_ClampU_RepeatV_Linear;
SamplerState Smp_RepeatU_RepeatV_Linear;
SamplerState Smp_RepeatU_ClampV_Linear;
SamplerState Smp_ClampU_ClampV_Point;
SamplerState Smp_ClampU_RepeatV_Point;
SamplerState Smp_RepeatU_RepeatV_Point;
SamplerState Smp_RepeatU_ClampV_Point;