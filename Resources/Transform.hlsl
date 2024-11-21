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

inline float4 TransformUVToWS(float2 uv, float rawDepth, float4x4 Matrix_I_VP)
{
    float4 positionCS = GetPositionNDC(uv, rawDepth);
    
    float4 positionWS = mul(Matrix_I_VP, positionCS);
    positionWS /= positionWS.w;
    #if (UNITY_UV_STARTS_AT_TOP == 1)
    positionWS.y *= -1;
    #endif

    return positionWS;
}

inline float2 TransformWSToUV(float3 positionWS, float4x4 Matrix_VP)
{
    float4 positionCS = mul(Matrix_I_VP, float4(positionWS, 1.f));

    #if UNITY_UV_STARTS_AT_TOP
        positionCS.y = -positionCS.y;
    #endif

    positionCS *= rcp(positionCS.w);
    positionCS.xy = positionCS.xy * 0.5 + 0.5;

    return positionCS.xy;
}