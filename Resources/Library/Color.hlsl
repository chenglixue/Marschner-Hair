#pragma once

inline float Luma4(float3 Color)
{
    return (Color.g * 2.0) + (Color.r + Color.b);
}

inline float3 Luma(float3 Color)
{
    return dot( Color, float3( 0.3, 0.59, 0.11 ) );
}

/// 计算权重值，用于调整颜色亮度以适应HDR显示
//  Exposure : 调整亮度计算结果
inline half HDRWeight4(half3 Color, half Exposure)
{
    return rcp(Luma4(Color) * Exposure + 4);
}