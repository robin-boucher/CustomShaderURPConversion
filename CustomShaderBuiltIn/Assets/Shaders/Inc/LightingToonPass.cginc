#ifndef SAMPLE_LIGHTING_TOON_PASS_INCLUDED
#define SAMPLE_LIGHTING_TOON_PASS_INCLUDED

// Unity includes
#include "UnityLightingCommon.cginc"
#include "AutoLight.cginc"

// Custom includes
#include "LightingToon.cginc"

// Properties
fixed4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;

sampler2D _ToonRampTex;

float _ShadowRampBlend;

sampler2D _NormalTex;

fixed3 _SpecularColor;
float _Smoothness;

// Vert input
struct appdata_toon
{
    float2 uv           : TEXCOORD0;
    float4 vertex       : POSITION; // Object-space position
    float3 normalOS     : NORMAL;   // Object-space normal
    float4 tangentOS    : TANGENT;  // Object-space tangent

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// Vert output/Frag input
struct v2f_toon
{
    float2 uv               : TEXCOORD0;
    float3 positionWS       : TEXCOORD1;   // World-space position
    half3 normalWS          : TEXCOORD2;   // World-space normal
    half3 viewDirectionWS   : TEXCOORD3;   // World-space view direction
    half3 tangentWS         : TEXCOORD4;   // World-space tangent
    half3 bitangentWS       : TEXCOORD5;   // World-space bitangent
    float4 pos              : SV_POSITION; // Clip-space position

    UNITY_SHADOW_COORDS(6)
    UNITY_FOG_COORDS(7)
};

// Vertex function
v2f_toon vertToon(appdata_toon v)
{
    v2f_toon o;

    UNITY_INITIALIZE_OUTPUT(v2f_toon, o);

    // For GPU instancing
    UNITY_SETUP_INSTANCE_ID(v);

    // Transformations
    float3 positionWS = mul(unity_ObjectToWorld, v.vertex).xyz;
    half3 normalWS = UnityObjectToWorldNormal(v.normalOS);
    half3 tangentWS = UnityObjectToWorldDir(v.tangentOS.xyz);
    half3 bitangentWS = cross(normalWS, tangentWS) * v.tangentOS.w;
    float4 positionCS = UnityObjectToClipPos(v.vertex);

    // Set output
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    o.pos = positionCS;
    o.normalWS = normalWS;
    o.tangentWS = tangentWS;
    o.bitangentWS = bitangentWS;
    o.positionWS = positionWS;
    o.viewDirectionWS = normalize(_WorldSpaceCameraPos - positionWS);
    UNITY_TRANSFER_SHADOW(o, v.uv);
    UNITY_TRANSFER_FOG(o, positionCS);

    return o;
}

// Fragment function
fixed4 fragToon(v2f_toon i) : SV_Target
{
    float2 uv = i.uv;

    fixed4 color;

    // Main tex
    fixed4 mainTex = tex2D(_MainTex, uv);

    fixed4 mainColor = mainTex * _Color;

    // Unpack normals from normal map
    half3 normalTS = UnpackNormal(tex2D(_NormalTex, uv));
    half3 normalWS = normalize(mul(normalTS, float3x3(i.tangentWS, i.bitangentWS, i.normalWS)));

    // Construct light data
    UnityLight light;
    light.color = _LightColor0;
#if defined(POINT) || defined(SPOT)
    light.dir = normalize(_WorldSpaceLightPos0.xyz - i.positionWS);  // Direction to light source
#else
    light.dir = _WorldSpaceLightPos0.xyz;  // Pos is direction for directional lights
#endif
    float distanceAttenuation = DistanceAttenuation(i.positionWS);  // Distance attenuation
    float shadowAttenuation = UNITY_SHADOW_ATTENUATION(i, i.positionWS); // Shadow attenuation

    // Ambient light (only ForwardBase pass)
#ifdef SAMPLE_AMBIENT
    fixed3 ambient = max(0, ShadeSH9(half4(normalWS, 1)));
#else
    fixed3 ambient = 0;
#endif

    // Get lighting color
    color.rgb = GetLightingToonColor(
        mainColor.rgb,
        light,
        distanceAttenuation,
        shadowAttenuation,
        normalWS,
        i.viewDirectionWS,
        _SpecularColor,
        _Smoothness,
        _ToonRampTex,
        _ShadowRampBlend,
        ambient
    );

    color.a = mainColor.a;

    // Fog
    UNITY_APPLY_FOG(i.fogCoord, color);

    return color;
}

#endif