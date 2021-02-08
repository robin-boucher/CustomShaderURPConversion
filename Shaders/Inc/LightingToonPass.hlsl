#ifndef SAMPLE_LIGHTING_TOON_PASS_INCLUDED
#define SAMPLE_LIGHTING_TOON_PASS_INCLUDED

// URP includes
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// Custom includes
#include "LightingToon.hlsl"

// Properties
CBUFFER_START(UnityPerMaterial)
    half4 _BaseColor;
    float4 _BaseMap_ST;

    float _ShadowRampBlend;

    half3 _SpecularColor;
    float _Smoothness;

    half4 _OutlineColor;
    half _OutlineThickness;

    // Properties required by URP ShadowCasterPass.hlsl
    half _Cutoff;
CBUFFER_END

// Texture samplers
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

TEXTURE2D(_ToonRampTex);
SAMPLER(sampler_ToonRampTex);

TEXTURE2D(_NormalTex);
SAMPLER(sampler_NormalTex);

// Vert input
struct AttributesToon
{
    float2 uv           : TEXCOORD0;
    float4 vertex       : POSITION; // Object-space position
    float3 normalOS     : NORMAL;   // Object-space normal
    float4 tangentOS    : TANGENT;  // Object-space tangent

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// Vert output/Frag input
struct VaryingsToon
{
    float2 uv               : TEXCOORD0;
    float3 positionWS       : TEXCOORD1;   // World-space position
    half3 normalWS          : TEXCOORD2;   // World-space normal
    half3 viewDirectionWS   : TEXCOORD3;   // World-space view direction
    half3 tangentWS         : TEXCOORD4;   // World-space tangent
    half3 bitangentWS       : TEXCOORD5;   // World-space bitangent

#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    float4 shadowCoord      : TEXCOORD6;   // Vertex shadow coords if required
#endif

    half fogFactor          : TEXCOORD7;   // Fog factor

    float4 pos              : SV_POSITION; // Clip-space position
};

// Vertex function
VaryingsToon vertToon(AttributesToon input)
{
    VaryingsToon output;

    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(input);

    // Transformations
    float3 positionWS = TransformObjectToWorld(input.vertex.xyz);
    half3 normalWS = TransformObjectToWorldNormal(input.normalOS);
    half3 tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
    half3 bitangentWS = cross(normalWS, tangentWS) * input.tangentOS.w;
    float4 positionCS = TransformObjectToHClip(input.vertex.xyz);

    // Set output
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.pos = positionCS;
    output.normalWS = normalWS;
    output.tangentWS = tangentWS;
    output.bitangentWS = bitangentWS;
    output.positionWS = positionWS;
    output.viewDirectionWS = normalize(GetCameraPositionWS() - positionWS);
#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    // Vertex shadow coords if required
    output.shadowCoord = TransformWorldToShadowCoord(positionWS);
#endif
    output.fogFactor = ComputeFogFactor(positionCS.z);

    return output;
}

// Fragment function
half4 fragToon(VaryingsToon input) : SV_Target
{
    float2 uv = input.uv;

    half4 color;

    // Main tex
    half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);

    half4 mainColor = baseMap * _BaseColor;

    // Unpack normals from normal map
    half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, uv));
    half3 normalWS = normalize(mul(normalTS, float3x3(input.tangentWS, input.bitangentWS, input.normalWS)));

    // Indirect light
    half3 indirect = SampleSH(normalWS);
//#if UNITY_COLORSPACE_GAMMA
//    // SRGB conversion if color space is Gamma
//    indirect = FastLinearToSRGB(indirect);
//#endif

    // Main light
#ifdef _MAIN_LIGHT_SHADOWS
    // Receiving shadows
#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    // Use vertex shadow coords if required
    float4 shadowCoord = input.shadowCoord;
#else
    // Otherwise, get per-pixel shadow coords
    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
#endif
    Light mainLight = GetMainLight(shadowCoord);
#else
    // No shadows
    Light mainLight = GetMainLight();
#endif

    // Get lighting color
    color.rgb = GetLightingToonColor(
        mainColor.rgb,
        mainLight,
        normalWS,
        input.viewDirectionWS,
        _SpecularColor,
        _Smoothness,
        TEXTURE2D_ARGS(_ToonRampTex, sampler_ToonRampTex),
        _ShadowRampBlend,
        indirect
    );

    // Additional lights
#ifdef _ADDITIONAL_LIGHTS
    // Get additional light count
    int additionalLightCount = GetAdditionalLightsCount();

    // Loop through additional lights
    for (int lightIndex = 0; lightIndex < additionalLightCount; lightIndex++)
    {
        // Get additional light data by index
        // Shadows will be computed if _ADDITIONAL_LIGHT_SHADOWS is defined
        Light additionalLight = GetAdditionalLight(lightIndex, input.positionWS);

        // Add lighting color
        color.rgb += GetLightingToonColor(
            mainColor.rgb,
            additionalLight,
            normalWS,
            input.viewDirectionWS,
            _SpecularColor,
            _Smoothness,
            TEXTURE2D_ARGS(_ToonRampTex, sampler_ToonRampTex),
            _ShadowRampBlend,
            0 // Only add indirect lighting during main light
        );
    }
#endif
    
    color.a = mainColor.a;

    // Mix fog
    color.rgb = MixFog(color.rgb, input.fogFactor);

    return color;
}

#endif