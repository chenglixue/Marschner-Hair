#pragma once
#include "BRDF.hlsl"
#include "Macros.hlsl"

#if defined (_SHADINGMODEL_MARSCHNERHAIR)
    #define HAIR_COMPONENT_R 1
    #define HAIR_COMPONENT_TT 1
    #define HAIR_COMPONENT_TRT 1
    #define HAIR_COMPONENT_MULTISCATTER 1

    #define HAIR_DITHER_OPACITY_MASK 1

    half _MarschnerHairSpecular;
    half _MarschnerHairScatter;
    half _MarschnerHairShift;
    half _MarschnerHairTransmitIntensity;
#endif

#if defined (_SHADINGMODEL_SCHEUERMANNHAIR)
    #define HAIR_DITHER_OPACITY_MASK 1

#endif

// 第一类修正贝塞尔函数 I0(x) 的实现
float ModifiedBesselI0(float x)
{
    // 处理特殊情况
    if (x == 0.f)
    {
        return 1.f;
    }

    float sum = 0.f;
    float term = 1.f; // 初始项 (x/2)^0 / 0!^2 = 1
    int k = 0;

    [unroll(64)]
    for(; term > FLT_EPS;)
    {
        sum += term;
        k++;
        term *= (x * x) / (4.0 * k * k);
    }

    return sum;
}

float Hair_g(float roughness, float Theta)
{
    return exp(-0.5f * pow2(Theta) / pow2(roughness)) / (sqrt(TWO_PI) * roughness);
}
float Hair_F(float CosTheta)
{
    const float n = 1.55;
    const float F0 = pow2((1 - n) / (1 + n));
    return F0 + (1 - F0) * pow5(1 - CosTheta);
}

float3 MarschnerDiffuse(float3 albedo, float metallic, float3 lightDir, float3 viewDir, float3 normal, float shadow)
{
    float3 fakeNormal = normalize(viewDir - normal * dot(viewDir, normal));
    normal = fakeNormal;
    float warp = 1;
    float NoL = saturate(dot(normal, lightDir) + warp) / pow2(1.f + warp);

    float KajiyaDiffuse = 1.f - abs(dot(normal, lightDir));
    
    // 漫反射项的另一种近似，考虑了表面金属度
    float diffuseScatter = lerp(NoL, KajiyaDiffuse, 0.33f) * metallic * INV_PI;

    float3 luma = Luma(albedo);
    float3 albedoOverLuma = abs(albedo / max(luma, 0.0001f));
    float3 scatterTint = shadow < 1.f ? pow(albedoOverLuma, 1.f - shadow) : 1.f;
    
    return sqrt(abs(albedo)) * diffuseScatter * scatterTint;
}
float3 ScheuermannDiffuse(float3 albedo, float3 normal, float3 lightDir)
{
    return lerp(0.25f, 1.f, dot(normal, lightDir)) * albedo;
}

FDirectLighting MarschnerHairShading(MyBRDFData brdf_data, MyLightData light_data, float3 lightDir, float shadow)
{
    FDirectLighting o = (FDirectLighting)0;

    #if defined (_SHADINGMODEL_MARSCHNERHAIR)
    float clampedRoughness = clamp(brdf_data.roughness, 1.f / 255.f, 1.f);
    
    const float VoL       = dot(light_data.viewDirWS, lightDir);
    const float sinThetaL = clamp(dot(brdf_data.normal, lightDir), -1.f, 1.f);
    const float sinThetaV = clamp(dot(brdf_data.normal, light_data.viewDirWS), -1.f, 1.f);
    const float cosThetaL = sqrt(1.f - pow2(sinThetaL));
    const float cosThetaV = sqrt(1.f - pow2(sinThetaV));
    // (散射角 - 入射角) * 0.5
    float cosThetaD       = cos( 0.5f * abs( asinFast( sinThetaV ) - asinFast( sinThetaL ) ) );
    
    const float3 Lp = lightDir - sinThetaL * brdf_data.normal;        // 入射光在法平面上投影线段
    const float3 Vp = light_data.viewDirWS - sinThetaV * brdf_data.normal;    // 出射光在法平面上投影线段
    // 散射方位角 - 入射方位角
    const float cosPhi = dot(Lp,Vp) * rsqrt( dot(Lp,Lp) * dot(Vp,Vp) + 1e-4 );
    const float cosHalfPhi = sqrt( saturate( 0.5 + 0.5 * cosPhi ) );
    
    float n = 1.55;                                         // 材质折射率
    float n_prime = 1.19 / cosThetaD + 0.36 * cosThetaD;    // 改良后的折射率

    float Shift = _MarschnerHairShift;
    float Alpha[] =
    {
        -Shift * 2,
        Shift,
        Shift * 4,
    };	

    #if (HAIR_COMPONENT_MULTISCATTER == 1)
        o.diffuse += max(MarschnerDiffuse(brdf_data.albedo, brdf_data.metallic, lightDir, light_data.viewDirWS, light_data.normalWS, shadow) * max(_MarschnerHairScatter, 0.f), 0.f);
    #endif

    float M = 0.f, N = 0.f, A = 0.f, T = 0.f, DP = 0.f;
    #if (HAIR_COMPONENT_R == 1)
        float R = 0.f;
    
        float v = pow2(clampedRoughness);
        M += rcp(v * exp(2.f / v));
        M *= exp((1.f - sinThetaL * sinThetaV) / v);
        M *= ModifiedBesselI0(sinThetaL + sinThetaV - Alpha[0] * cosThetaV / v);

        // 高斯近似
        const float sa = sin(Alpha[0]);
        const float ca = cos(Alpha[0]);
        float shift = 2 * sa * (ca * cosHalfPhi * sqrt(1 - pow2(sinThetaV)) + sa * sinThetaV);
        M = Hair_g(pow2(clampedRoughness) * cosHalfPhi * sqrt(2), sinThetaL + sinThetaV - shift);
    
        N = 0.25f * cosHalfPhi;

        A = Hair_F(sqrt(saturate(0.5f + 0.5f * VoL)));
        
        R += M * N * A  * max(_MarschnerHairSpecular, 0.f) * lerp(1, 0.5f, saturate(-VoL));

        o.specular += R;
    #endif

    #if (HAIR_COMPONENT_TT == 1)
        float TT = 0.f;
    
        M = Hair_g(0.5f * pow2(clampedRoughness), sinThetaL + sinThetaV - Alpha[1]);
    
        float a = rcp(n_prime);
        float hTT = cosHalfPhi * (1.f + a * (0.6f - 0.8f * cosPhi));
        T = pow(brdf_data.albedo, 0.5f * sqrt(1.f - pow2(hTT * a)) / cosThetaD);
        DP = exp(-3.65f * cosPhi - 3.98f);
        N = T * DP;

        float fTT = Hair_F(cosThetaD * sqrt(saturate(1.f - pow2(hTT))));
        A = pow2(1.f - fTT);
        
        TT += M * N * A * _MarschnerHairTransmitIntensity;
        o.specular += TT;
    #endif

    #if (HAIR_COMPONENT_TRT == 1)
        float TRT = 0.f;

        M = Hair_g(2.f * pow2(clampedRoughness), sinThetaL + sinThetaV - Alpha[2]);

        T = pow(brdf_data.albedo, 0.8f / cosThetaD);
        DP = exp(17.f * cosPhi - 16.78f);
        N = T * DP;

        float fTRT = Hair_F(cosThetaD * 0.5f);
        A = pow2(1.f - fTRT) * fTRT;

        TRT += M * N * A * 3;
        o.specular += TRT;
    #endif
         
    #endif
    
    return o;
}