#ifndef SAMPLE_LIGHTING_TOON_INCLUDED
#define SAMPLE_LIGHTING_TOON_INCLUDED

// Basic toon lighting implementation

#ifdef UNITY_COLORSPACE_GAMMA
#define SPECULAR_VALUE 0.22
#else
#define SPECULAR_VALUE 0.04
#endif

// Diffuse
fixed3 GetLightingToonDiffuse(UnityLight light, float distanceAttenuation, float shadowAttenuation, half3 normalWS, sampler2D toonRampTex, float shadowRampBlend)
{
    float NDL = saturate(dot(normalWS, light.dir));

    // Sample toon ramp (assumes toon ramp tex is horizontal, dark -> light)
    float2 toonRampUV = float2(NDL, 0.5);
    fixed3 toonRamp = tex2D(toonRampTex, toonRampUV).rgb;

    // Apply shadow attenuation (smoothstep)
    toonRamp *= smoothstep(0.5 - shadowRampBlend, 0.5 + shadowRampBlend, shadowAttenuation);

    return distanceAttenuation * toonRamp;
}

// Specular term
float GetSpecularTerm(half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS, float smoothness)
{
    // Based on UnityStandardBRDF.cginc

    float perceptualRoughness = (1 - smoothness);
    float roughness = perceptualRoughness * perceptualRoughness;

    float3 halfVector = normalize(lightDirectionWS + viewDirectionWS);
    float NDH = saturate(dot(normalWS, halfVector));
    float LDH = saturate(dot(lightDirectionWS, halfVector));

    float r2 = roughness * roughness;
    float d = NDH * NDH * (r2 - 1) + 1.00001;

#ifdef UNITY_COLORSPACE_GAMMA
    float normalizationTerm = roughness + 1.5;
    float specularTerm = roughness / (d * max(0.32, LDH) * normalizationTerm);
#else
    float normalizationTerm = roughness * 4 + 2;
    float specularTerm = r2 / ((d * d) * max(0.1, LDH * LDH) * normalizationTerm);
#endif

    return specularTerm;
}

// Specular
fixed3 GetLightingToonSpecular(UnityLight light, float shadowAttenuation, half3 normalWS, half3 viewDirectionWS, fixed3 specularColor, float smoothness, sampler2D toonRampTex)
{
    // Specular factor
    float specularFactor = GetSpecularTerm(normalWS, light.dir, viewDirectionWS, smoothness) * SPECULAR_VALUE;

    // Sample toon ramp (assumes toon ramp tex is horizontal, dark -> light)
    float2 toonRampUV = float2(saturate(specularFactor), 0.5);
    fixed3 toonRamp = tex2D(toonRampTex, toonRampUV).rgb;

    return specularColor * toonRamp;
}

// Get lighting toon color
fixed3 GetLightingToonColor(fixed3 color, UnityLight light, float distanceAttenuation, float shadowAttenuation, half3 normalWS, half3 viewDirectionWS, fixed3 specularColor, float smoothness, sampler2D toonRampTex, float shadowRampBlend, fixed3 ambient)
{
    // Diffuse
    fixed3 diffuse = GetLightingToonDiffuse(light, distanceAttenuation, shadowAttenuation, normalWS, toonRampTex, shadowRampBlend);
    // Specular
    fixed3 specular = GetLightingToonSpecular(light, shadowAttenuation, normalWS, viewDirectionWS, specularColor, smoothness, toonRampTex);

    color *= (1 - SPECULAR_VALUE);
    return (color + specular) * light.color * diffuse + ambient * color;
}

// Distance attenuation implementation taken from AutoLight.cginc
float DistanceAttenuation(float3 positionWS)
{
    float distanceAttenuation;

#if defined(POINT)
    float3 lightCoord = mul(unity_WorldToLight, float4(positionWS, 1)).xyz;
    distanceAttenuation = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).r;
#elif defined(SPOT)
    float4 lightCoord = mul(unity_WorldToLight, float4(positionWS, 1));
    distanceAttenuation = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * UnitySpotAttenuate(lightCoord.xyz);
#else
    distanceAttenuation = 1; // 1 for directional light
#endif

    return distanceAttenuation;
}

#endif