#pragma once

half4 _MainTex_TexelSize;
float4x4 Matrix_V;
float4x4 Matrix_I_V;
float4x4 Matrix_P;
float4x4 Matrix_I_P;
float4x4 Matrix_VP;
float4x4 Matrix_I_VP;

inline float4 GetPositionNDC(float2 uv, float rawDepth)
{
    return float4(uv * 2 - 1, rawDepth, 1.f);
}

inline float4 GetPositionVS(float4 positionNDC, float4x4 Matrix_I_P)
{
    float4 positionVS = mul(Matrix_I_P, positionNDC);
    positionVS /= positionVS.w;
    #if (UNITY_UV_STARTS_AT_TOP == 1)
    positionVS.y *= -1;
    #endif

    return positionVS;
}

inline float4 GetPositionWS(float4 positionVS, float4x4 Matrix_I_V)
{
    return mul(Matrix_I_V, positionVS);
}

inline float4 TransformNDCToWS(float4 positionNDC, float4x4 Matrix_I_VP)
{
    float4 positionWS = mul(Matrix_I_VP, positionNDC);
    positionWS /= positionWS.w;
    #if (UNITY_UV_STARTS_AT_TOP == 1)
    positionWS.y *= -1;
    #endif

    return positionWS;
}