#pragma once
#include "Assets/Resources/Library/Common.hlsl"

inline float2 GetCameraMotionVector(float rawDepth, float2 uv,
    float4x4 Matrix_I_VP, float4x4 _Pre_Matrix_VP, float4x4 Matrix_VP)
{
    float4 positionNDC = GetPositionNDC(uv, rawDepth);
    float4 positionWS  = TransformNDCToWS(positionNDC, Matrix_I_VP);

    float4 currPosCS = mul(Matrix_VP, positionWS);
    float4 prePosCS  = mul(_Pre_Matrix_VP, positionWS);

    float2 currPositionSS = currPosCS.xy / currPosCS.w;
    currPositionSS = (currPositionSS + 1) * 0.5f;
    float2 prePositionSS  = prePosCS.xy / prePosCS.w;
    prePositionSS  = (prePositionSS + 1) * 0.5f;

    return currPositionSS - prePositionSS;
}

inline void ResolverAABB(Texture2D<float4> currColor, float ExposureScale, float AABBScale, float2 uv,
    inout float Variance, inout float4 MinColor, inout float4 MaxColor, inout float4 FilterColor)
{
    const int2 sampleOffset[9] =
    {
        int2(-1.0, -1.0), int2(0.0, -1.0), int2(1.0, -1.0), int2(-1.0, 0.0), int2(0.0, 0.0), int2(1.0, 0.0), int2(-1.0, 1.0), int2(0.0, 1.0), int2(1.0, 1.0)
    };

    float4 sampleColors[9];
    for(uint i = 0; i < 9; ++i)
    {
        sampleColors[i] = currColor.SampleLevel(Smp_ClampU_ClampV_Linear, uv + sampleOffset[i], 0);
    }

    float sampleWeight[9];
    for(uint i = 0; i < 9; ++i)
    {
        sampleWeight[i] = HDRWeight4(sampleColors[i].rgb, ExposureScale);
    }

    float totalWeight = 0.f;
    for(uint i = 0; i < 9; ++i)
    {
        totalWeight += sampleWeight[i];
    }

    sampleColors[4] = (sampleColors[0] * sampleWeight[0] + sampleColors[1] * sampleWeight[1] + sampleColors[2] * sampleWeight[2]
        + sampleColors[3] * sampleWeight[3] + sampleColors[4] * sampleWeight[4] + sampleColors[5] * sampleWeight[5]
        + sampleColors[6] * sampleWeight[6] + sampleColors[7] * sampleWeight[7] + sampleColors[8] * sampleWeight[8]) * rcp(totalWeight);

    float4 m1 = 0.f, m2 = 0.f;
    for(uint x = 0; x < 9; ++x)
    {
        m1 += sampleColors[x];
        m2 += sampleColors[x] * sampleColors[x];
    }

    float4 mean = m1 * rcp(9.f);
    float4 stddev = sqrt(m2 * rcp(9.f) - pow2(mean));

    MinColor = mean - AABBScale * stddev;
    MaxColor = mean + AABBScale * stddev;

    FilterColor = sampleColors[4];
    MinColor = min(MinColor, FilterColor);
    MaxColor = max(MaxColor, FilterColor);

    float4 totalVariance = 0.f;
    for(uint i = 0; i < 9; ++i)
    {
        totalVariance += pow2(Luminance(sampleColors[i]) - Luminance(mean));
    }

    Variance = saturate(totalVariance / 9.f * 256.f);
    Variance *= FilterColor.a;
}