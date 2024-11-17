#pragma once
#include "Assets/Resources/Library/Common.hlsl"
#include "Assets/Resources/Library/BRDF.hlsl"
#include "Assets/Resources/Library/HairBSDF.hlsl"

cbuffer UnityPerMaterial
{
    int _Enable_Albedo;
    int _Enable_Mask;
    int _Enable_Emission;
    int _Enable_Normal;
    int _Enable_Metallic;
    int _Enable_Roughness;
    int _Enable_AO;
    int _Enable_GI;

    float4 _Albedo;
    half4  _AlbedoTint;
    half   _AlbedoPow;
    half   _Mask;
    float3 _Emission;
    
    float3 _Normal;
    half    _NormalIntensity;
    
    float _Metallic;
    float _Roughness;
    float _AO;
    
    half    _Cutoff;
    
    float4 _AlbedoTex_ST;
    float4 _NormalTex_ST;

    // PreIntegrated Skin
    half3 _PreIntegratedSkinTint;
    half  _PreIntegratedSkinSpecularIntensity;
    half  _CurveFactor;
    int   _BlurNormalIntensity;

    // Subsurface Profile
    half  _LodeA;
    half  _LodeB;
    
}

Texture2D<float4> _AlbedoTex;
Texture2D<float>  _MaskTex;
Texture2D<float4> _NormalTex;
Texture2D<float>  _MetallicTex;
Texture2D<float>  _RoughnessTex;
Texture2D<float>  _AOTex;
Texture2D<float4> _EmissionTex;
Texture2D<float3> _PreIntegrateSSSLutTex;
Texture2D<float>  _SSSNDFLutTex;
Texture2D<float>  _AnisotropyTex;

samplerCUBE _DiffuseIBLTex;
samplerCUBE _SpecularIBLTex;
Texture2D<float3> _SpecularFactorLUTTex;

struct VSInput
{
    float3      posOS        : POSITION;

    float3       normalOS      : NORMAL;
    float4       tangentOS     : TANGENT;

    float2      uv           : TEXCOORD0;
};

struct PSInput
{
    float2      uv              : TEXCOORD0;

    float3      posWS           : TEXCOORD2;
    float4      posCS           : SV_POSITION;

    float3      normalWS        : NORMAL;
    float3      tangentWS       : TANGENT;
    float3      bitTangentWS    : TEXCOORD3;
};

struct PSOutput
{
    float4      color           : SV_TARGET;
};

PSInput PBRVS(VSInput i)
{
    PSInput o;
    
    o.posWS = mul(unity_ObjectToWorld, float4(i.posOS, 1.f));
    o.posCS = TransformObjectToHClip(i.posOS);

    const VertexNormalInputs vertexNormalData = GetVertexNormalInputs(i.normalOS, i.tangentOS);
    o.normalWS = vertexNormalData.normalWS;
    o.tangentWS = vertexNormalData.tangentWS;
    o.bitTangentWS = vertexNormalData.bitangentWS;

    o.uv = i.uv;

    return o;
}

MyBRDFData SetBRDFData(float2 uv, float3 LightColor, float3 LightDir, inout MyLightData LightData)
{
    half3  albedoValue                     = _AlbedoTex.SampleLevel(Smp_RepeatU_RepeatV_Linear, uv * _AlbedoTex_ST.xy + _AlbedoTex_ST.zw, 0).rgb;
    float3 normalValue                     = UnpackNormalScale(_NormalTex.SampleLevel(Smp_RepeatU_RepeatV_Linear, uv * _NormalTex_ST.xy + _NormalTex_ST.zw, _BlurNormalIntensity), _NormalIntensity);
    half3  emissionValue                   = _EmissionTex.SampleLevel(Smp_RepeatU_RepeatV_Linear, uv, 0).rgb;
    half   metallicValue                   = _MetallicTex.SampleLevel(Smp_RepeatU_RepeatV_Linear, uv, 0).r;
    half   roughnessValue                  = _RoughnessTex.SampleLevel(Smp_RepeatU_RepeatV_Linear, uv, 0).r;
    half   AOValue                         = _AOTex.SampleLevel(Smp_RepeatU_RepeatV_Linear, uv, 0).r;
    half   maskValue                       = _MaskTex.SampleLevel(Smp_ClampU_ClampV_Linear, uv * _AlbedoTex_ST.xy + _AlbedoTex_ST.zw, 0).r;
    half   shift                           = _AnisotropyTex.SampleLevel(Smp_ClampU_ClampV_Linear, uv * _AlbedoTex_ST.xy + _AlbedoTex_ST.zw, 0) - 0.5f;
    if(_Enable_Albedo)    albedoValue      = _Albedo;
    if(_Enable_Normal)    normalValue      = _Normal;
    if(_Enable_Metallic)  metallicValue    = _Metallic;
    if(_Enable_Roughness) roughnessValue   = _Roughness;
    if(_Enable_AO)        AOValue          = _AO;
    if(_Enable_Emission)  emissionValue    = _Emission;
    if(_Enable_Mask)      maskValue        = _Mask;

    float3 FO = lerp(0.04, albedoValue, metallicValue);
    float3 radiance = LightColor;

    MyBRDFData o;
    o.albedo  = albedoValue * _AlbedoTint * _AlbedoPow;
    o.opacity = maskValue;
    o.normal = SafeNormalize(mul(normalValue, LightData.TBN));
    o.emission = emissionValue;
    o.specular = 0;
    o.metallic = metallicValue;
    o.roughness = roughnessValue;
    o.roughness2 = pow2(o.roughness);
    o.AO = AOValue;
    o.F0 = FO;
    o.radiance = radiance;

    float3 lightDir = SafeNormalize(LightDir);
    float3 halfVector = SafeNormalize(LightData.viewDirWS + lightDir);
    o.halfVector = halfVector;
    o.NoL = max(dot(o.normal, lightDir), FLT_EPS);
    o.NoV = max(dot(o.normal, LightData.viewDirWS), FLT_EPS);
    o.NoH = max(dot(o.normal, halfVector), FLT_EPS);
    o.HoV = max(dot(halfVector, LightData.viewDirWS), FLT_EPS);
    o.HoL = max(dot(halfVector, lightDir), FLT_EPS);
    o.HoX = max(dot(halfVector, LightData.tangentWS), FLT_EPS);
    o.HoY = max(dot(halfVector, LightData.bitTangentWS), FLT_EPS);
    o.LobeA = _LodeA;
    o.LobeB = _LodeB;
    #if defined(_SHADINGMODEL_SCHEUERMANNHAIR)
        o.shift = shift;
    #endif

    LightData.normalWS = o.normal;
    LightData.reflectDirWS = reflect(-LightData.viewDirWS, o.normal);

    return o;
}
MyLightData SetLightData(PSInput i)
{
    MyLightData lightData;
    
    lightData.viewDirWS = SafeNormalize(GetCameraPositionWS() - i.posWS);
    lightData.tangentWS = SafeNormalize(i.tangentWS);
    lightData.bitTangentWS = SafeNormalize(i.bitTangentWS);
    lightData.normalWS = SafeNormalize(i.normalWS);
    lightData.TBN = half3x3(lightData.tangentWS, lightData.bitTangentWS, lightData.normalWS);
    
    return lightData;
}
float DitherOpacityMask(float2 xy, float opacity)
{
    const float dither[64] =
    {
    0, 32, 8, 40, 2, 34, 10, 42,
    48, 16, 56, 24, 50, 18, 58, 26 ,
    12, 44, 4, 36, 14, 46, 6, 38 ,
    60, 28, 52, 20, 62, 30, 54, 22,
    3, 35, 11, 43, 1, 33, 9, 41,
    51, 19, 59, 27, 49, 17, 57, 25,
    15, 47, 7, 39, 13, 45, 5, 37,
    63, 31, 55, 23, 61, 29, 53, 21
    };

    int xMat = int(xy.x) & 7;
    int yMat = int(xy.y) & 7;

    float limit = (dither[yMat * 8 + xMat] + 11.0) / 64.0;
    return lerp(limit * opacity, 1.0, opacity);
}

float3 DualSpecularGGX(float AverageRoughness, float Lobe0Roughness, float Lobe1Roughness, float LobeMix, MyBRDFData brdfData)
{
    float AverageAlpha2 = Pow4(AverageRoughness);
    float Lobe0Alpha2 = Pow4(Lobe0Roughness);
    float Lobe1Alpha2 = Pow4(Lobe1Roughness);

    // Generalized microfacet specular
    float D = lerp(NDF_GGX(Lobe0Alpha2, brdfData.NoH), NDF_GGX(Lobe1Alpha2, brdfData.NoH), LobeMix);
    float G = Vis_SmithJointApprox(AverageAlpha2, brdfData.NoV, brdfData.NoL);
    float3 F = SchlickFresnel(brdfData.HoV, brdfData.F0);

    return D * G * F;
}

FDirectLighting ShadeDirectLight(MyBRDFData brdfData, MyLightData lightData, Light light, float3 positionWS, float shadow, float2 uv)
{
    FDirectLighting o = (FDirectLighting)0;
    #if defined (_SHADINGMODEL_DEFAULTLIT)
        const float NDF     = NDF_GGX(brdfData.roughness2, brdfData.NoH);
        const float G       = Geometry_Smiths_SchlickGGX(brdfData.NoV, brdfData.NoL, brdfData.roughness);
        const float3 F      = Fresnel_UE4(brdfData.HoV, brdfData.F0);
        const float denom   = 4.f * brdfData.NoL * brdfData.NoV + 0.0001f;
        float3 specular     = NDF * G * F * rcp(denom);

        const float3 Ks = F;                            // 计算镜面反射部分，等于入射光线被反射的能量所占的百分比
        float3 Kd       = (1.f - Ks);                   // 折射光部分可以直接由镜面反射部分计算得出
        Kd              *= 1.f - brdfData.metallic;     // 金属没有漫反射
        float3 diffuse  = Kd * brdfData.albedo;
    
        o.diffuse  += diffuse * brdfData.NoL;
        o.specular += specular * brdfData.NoL;
    
    #elif defined(_SHADINGMODEL_PREINTEGRATEDSKIN)
        if(brdfData.NoL > 0.f)
        {
            float curve = saturate(_CurveFactor * length(fwidth(brdfData.normal)) / length(fwidth(positionWS)));
            float3 diffuse = _PreIntegrateSSSLutTex.SampleLevel(Smp_ClampU_ClampV_Linear, float2(brdfData.NoL * 0.5f + 0.5f, curve), 0);
            o.diffuse += diffuse * brdfData.albedo * _PreIntegratedSkinTint;

            #if defined (_PREINTEGRATEDSKINQUALITY_LOW)
                float3 halfVectorUnNor = lightDir + (GetCameraPositionWS() - positionWS);
                float NoH = dot(lightData.normalWS, halfVectorUnNor);
                float NDF = pow(2.f * _SSSNDFLutTex.SampleLevel(Smp_ClampU_ClampV_Linear, float2(NoH, brdfData.roughness), 0), 10);
                float F = SchlickFresnel(brdfData.HoV, brdfData.F0);
                float G = dot(halfVectorUnNor, halfVectorUnNor);
                float3 specular = max(NDF * F * rcp(G), FLT_EPS);
                o.specular += specular * brdfData.NoL * _PreIntegratedSkinSpecularIntensity * 0.5f;
            
            #elif defined (_PREINTEGRATEDSKINQUALITY_HIGH)
                float lobeARoughness = brdfData.roughness * brdfData.LobeA;
                lobeARoughness = lerp(1.f, lobeARoughness, saturate(brdfData.opacity * 10.0f));
                float lobeBRoughness = brdfData.roughness * brdfData.LobeB;
                lobeBRoughness = lerp(1.f, lobeBRoughness, saturate(brdfData.opacity * 10.0f));
                float lobeMix = 0.15f;
                float3 specular = DualSpecularGGX(brdfData.roughness, lobeARoughness, lobeBRoughness, lobeMix, brdfData);
                o.specular += specular * brdfData.NoL * _PreIntegratedSkinSpecularIntensity;
            #endif
        }

    #elif defined(_SHADINGMODEL_SUBSURFACEPROFILE)
        if(brdfData.NoL > 0.f)
        {
            float3 diffuse = Diffuse_Burley(brdfData.albedo, brdfData.roughness, brdfData.NoV, brdfData.NoL, brdfData.HoV);
            o.diffuse += diffuse * brdfData.NoL;
        }
    #elif defined(_SHADINGMODEL_MARSCHNERHAIR)
        o = MarschnerHairShading(brdfData, lightData, light.direction, shadow);
    #endif
    
    return o;
}
float3 ShadeGI(float3 alebdo, float metallic, float roughness, float3 normal, float3 reflectDir, float NoV, float F0)
{
    if(_Enable_GI == 0) return 0;
    
    // -----------------
    //GI Diffuse
    // -----------------
    float3 F_IBL      = FresnelSchlickRoughness(NoV, F0, roughness);
    float KD_IBL      = (1 - F_IBL) * (1 - metallic);
    float3 irradiance = texCUBE(_DiffuseIBLTex, normal).rgb;
    float3 GIDiffuse  = KD_IBL * alebdo * irradiance;
    
    #if defined(_SHADINGMODEL_SUBSURFACEPROFILE)
        return GIDiffuse;
    #endif

    // -----------------
    //GI Specular
    // -----------------
    float rgh                = roughness * (1.7 - 0.7 * roughness);
    float lod                = 6.f * rgh;
    float3 GISpecularColor   = texCUBElod(_SpecularIBLTex, float4(reflectDir, lod)).rgb;
    float3 GISpecularFactor  = _SpecularFactorLUTTex.SampleLevel(Smp_RepeatU_RepeatV_Linear, float2(NoV, roughness), 0).rgb;
    float3 GISpecular        = (GISpecularFactor.r * F0 + GISpecularFactor.g) * GISpecularColor;
    
    return GIDiffuse + GISpecular;
}

void PBRPS(PSInput i, out PSOutput o)
{
    o = (PSOutput)0;
    float3 color = 0.f;
    
    MyLightData lightData;
    MyBRDFData  brdfData;
    lightData       = SetLightData(i);
    Light mainLight = GetMainLight();
    brdfData        = SetBRDFData(i.uv, mainLight.color, mainLight.direction, lightData);
    #if defined(HAIR_DITHER_OPACITY_MASK)
    brdfData.opacity = DitherOpacityMask(i.uv * _ScreenSize.xy + _Time.yz * 100.f, brdfData.opacity);
    #endif
    clip(brdfData.opacity - _Cutoff);

    
    #if defined(_SHADINGMODEL_UNLIT)
        o.color = float4(brdfData.emission, brdfData.opacity);
    #else
        FDirectLighting shadeDirect = ShadeDirectLight(brdfData, lightData, mainLight, i.posWS, mainLight.shadowAttenuation, i.uv);
        color += (shadeDirect.diffuse + shadeDirect.specular)* mainLight.color * mainLight.shadowAttenuation * mainLight.distanceAttenuation;
        float3 GI = ShadeGI(brdfData.albedo, brdfData.metallic, brdfData.roughness, brdfData.normal, lightData.reflectDirWS, brdfData.NoV, brdfData.F0);
        color += (GI + brdfData.emission) * brdfData.AO;
        o.color = float4(color, brdfData.opacity);
    #endif
}