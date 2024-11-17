#pragma once

static half Dither[16] =
{
    0.0, 0.5, 0.125, 0.625,
    0.75, 0.25, 0.875, 0.375,
    0.187, 0.687, 0.0625, 0.562,
    0.937, 0.437, 0.812, 0.312
};

float Hash11(float p)
{
    p = frac(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float Hash2to1(float2 p)
{
    float3 p3  = frac(float3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float Hash3to1(float3 p3)
{
    p3  = frac(p3 * .1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return frac((p3.x + p3.y) * p3.z);
}

float2 Hash1to2(float p)
{
    float3 p3 = frac(float3(p,p,p) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx+p3.yz)*p3.zy);
}
float2 Hash22(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return frac((p3.xx+p3.yz)*p3.zy);
}
float2 Hash3to2(float3 p3)
{
    p3 = frac(p3 * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx+p3.yz)*p3.zy);
}

float3 Hash1to3(float p)
{
    float3 p3 = frac(float3(p,p,p) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return frac((p3.xxy+p3.yzz)*p3.zyx); 
}
float3 Hash2to3(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yxz+33.33);
    return frac((p3.xxy+p3.yzz)*p3.zyx);
}

float3 Hash33(float3 pos)
{
    pos = frac(pos * float3(0.1031f, 0.1030f, 0.0973f));
    pos += dot(pos, pos.yxz + 33.33f);
    
    return frac((pos.xxy + pos.yxx) * pos.zyx);
}

float4 Hash1to4(float p)
{
    float4 p4 = frac(float4(p,p,p,p) * float4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return frac((p4.xxyz+p4.yzzw)*p4.zywx);
}
float4 Hash2to4(float2 p)
{
    float4 p4 = frac(float4(p.xyxy) * float4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return frac((p4.xxyz+p4.yzzw)*p4.zywx);
}
float4 Hash3to4(float3 p)
{
    float4 p4 = frac(float4(p.xyzx)  * float4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return frac((p4.xxyz+p4.yzzw)*p4.zywx);
}
float4 Hash44(float4 p4)
{
    p4 = frac(p4  * float4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return frac((p4.xxyz+p4.yzzw)*p4.zywx);
}


float2 RandN2(float2 pos, float2 random)
{
    return frac(sin(dot(pos.xy + random, float2(12.9898, 78.233))) * float2(43758.5453, 28001.8384));
}

#define NUM_SAMPLES 20
float2 disk[NUM_SAMPLES];

float rand_2to1(float2 uv ) 
{ 
    // 0 - 1
    const float a = 12.9898, b = 78.233, c = 43758.5453;
    float dt = dot( uv.xy, float2( a,b ) ), sn = fmod( dt, PI );
    return frac(sin(sn) * c);
}
void poissonDiskSamples(float2 randomSeed)
{
    // 初始弧度
    float angle = rand_2to1( randomSeed ) * PI * PI;
    // 初始半径
    float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );
    float radius = INV_NUM_SAMPLES;
    // 一步的弧度
    float ANGLE_STEP = 3.883222077450933;// (sqrt(5)-1)/2 *2PI
    // 一步的半径
    float radiusStep = radius;

    for( int i = 0; i < NUM_SAMPLES; i ++ ) {
        disk[i] = float2(cos(angle),sin(angle)) * pow( radius, 0.75 );
        radius += radiusStep;
        angle += ANGLE_STEP;
    }
}