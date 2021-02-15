#ifndef SAMPLE_LIGHTING_TOON_INCLUDED
#define SAMPLE_LIGHTING_TOON_INCLUDED

// Basic toon lighting implementation

// Uncomment this if doing SRGB conversion to look the same as Built-in RP
//#ifdef UNITY_COLORSPACE_GAMMA
//#define SPECULAR_VALUE 0.22
//#else
//#define SPECULAR_VALUE 0.04
//#endif

#define SPECULAR_VALUE 0.04

// Diffuse
half3 GetLightingToonDiffuse(Light light, half3 normalWS, TEXTURE2D_PARAM(toonRampTex, toonRampTexSampler), float shadowRampBlend)
{
    float NDL = saturate(dot(normalWS, light.direction));

    // Sample toon ramp (assumes toon ramp tex is horizontal, dark -> light)
    float2 toonRampUV = float2(NDL, 0.5);
    half3 toonRamp = SAMPLE_TEXTURE2D(toonRampTex, toonRampTexSampler, toonRampUV).rgb;

    // Apply shadow attenuation (smoothstep)
    toonRamp *= smoothstep(0.5 - shadowRampBlend, 0.5 + shadowRampBlend, light.shadowAttenuation);

    return light.distanceAttenuation * toonRamp;
}

// Specular term
float GetSpecularTerm(half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS, float smoothness)
{
    // Based on UnityStandardBRDF.cginc

    float roughness = (1 - smoothness) * (1 - smoothness);

    float3 halfVector = normalize(lightDirectionWS + viewDirectionWS);
    float NDH = saturate(dot(normalWS, halfVector));
    float LDH = saturate(dot(lightDirectionWS, halfVector));

    float r2 = roughness * roughness;
    float d = NDH * NDH * (r2 - 1.0) + 1.00001;

    // Uncomment this if doing SRGB conversion to look the same as Built-in RP
//#ifdef UNITY_COLORSPACE_GAMMA
//    float normalizationTerm = roughness + 1.5;
//    float specularTerm = roughness / (d * max(0.32, LDH) * normalizationTerm);
//#else
//    float normalizationTerm = roughness * 4 + 2;
//    float specularTerm = r2 / ((d * d) * max(0.1, LDH * LDH) * normalizationTerm);
//#endif

    float normalizationTerm = roughness * 4 + 2;
    float specularTerm = r2 / ((d * d) * max(0.1, LDH * LDH) * normalizationTerm);

    return specularTerm;
}

// Specular
half3 GetLightingToonSpecular(Light light, half3 normalWS, half3 viewDirectionWS, half3 specularColor, float smoothness, TEXTURE2D_PARAM(toonRampTex, toonRampTexSampler))
{
    // Specular factors
    float specularFactor = GetSpecularTerm(normalWS, light.direction, viewDirectionWS, smoothness) * SPECULAR_VALUE;

    // Sample toon ramp (assumes toon ramp tex is horizontal, dark -> light)
    float2 toonRampUV = float2(saturate(specularFactor), 0.5);
    half3 toonRamp = SAMPLE_TEXTURE2D(toonRampTex, toonRampTexSampler, toonRampUV).rgb;

    return specularColor * toonRamp;
}

// Get lighting toon color
half3 GetLightingToonColor(half3 color, Light light, half3 normalWS, half3 viewDirectionWS, half3 specularColor, float smoothness, TEXTURE2D_PARAM(toonRampTex, toonRampTexSampler), float shadowRampBlend, half3 indirect)
{
    // Diffuse
    half3 diffuse = GetLightingToonDiffuse(light, normalWS, TEXTURE2D_ARGS(toonRampTex, toonRampTexSampler), shadowRampBlend);
    // Specular
    half3 specular = GetLightingToonSpecular(light, normalWS, viewDirectionWS, specularColor, smoothness, TEXTURE2D_ARGS(toonRampTex, toonRampTexSampler));

    color *= (1 - SPECULAR_VALUE);
    return (color + specular) * light.color * diffuse + indirect * color;
}

#endif