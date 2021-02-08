#ifndef SAMPLE_LIGHTING_TOON_INCLUDED
#define SAMPLE_LIGHTING_TOON_INCLUDED

// Basic toon lighting implementation

// Diffuse
half3 GetLightingToonDiffuse(Light light, half3 normalWS, TEXTURE2D_PARAM(toonRampTex, toonRampTexSampler), float shadowRampBlend)
{
    float NDL = saturate(dot(normalWS, light.direction));

    // Sample toon ramp (assumes toon ramp tex is horizontal, dark -> light)
    float2 toonRampUV = float2(NDL, 0.5);
    half3 toonRamp = SAMPLE_TEXTURE2D(toonRampTex, toonRampTexSampler, toonRampUV).rgb;

    // Apply shadow attenuation (smoothstep)
    toonRamp *= smoothstep(0.5 - shadowRampBlend, 0.5 + shadowRampBlend, light.shadowAttenuation);

    return light.color * light.distanceAttenuation * toonRamp;
}

// Specular factor
float GetSpecularFactor(half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS, float smoothness)
{
    // Based on UnityStandardBRDF.cginc, without metallic consideration

    float roughness = (1 - smoothness) * (1 - smoothness);

    float3 halfVector = normalize(lightDirectionWS + viewDirectionWS);
    float NDH = saturate(dot(normalWS, halfVector));
    float LDH = saturate(dot(lightDirectionWS, halfVector));

    float r2 = roughness * roughness;
    float d = NDH * NDH * (r2 - 1.0) + 1.00001;

#ifdef UNITY_COLORSPACE_GAMMA
    float specularFactor = roughness / (max(0.32, LDH) * (1.5 + roughness) * d);
    half surfaceReduction = 0.28;
#else
    float specularFactor = r2 / (max(0.1f, LDH * LDH) * (roughness + 0.5f) * (d * d) * 4);
    half surfaceReduction = 0.064;
#endif

    return specularFactor * surfaceReduction;
}

// Specular
half3 GetLightingToonSpecular(Light light, half3 normalWS, half3 viewDirectionWS, half3 specularColor, float smoothness, TEXTURE2D_PARAM(toonRampTex, toonRampTexSampler))
{
    // Specular factors
    float specularFactor = GetSpecularFactor(normalWS, light.direction, viewDirectionWS, smoothness);

    // Sample toon ramp (assumes toon ramp tex is horizontal, dark -> light)
    float2 toonRampUV = float2(saturate(specularFactor), 0.5);
    half3 toonRamp = SAMPLE_TEXTURE2D(toonRampTex, toonRampTexSampler, toonRampUV).rgb;

    return light.color * specularColor * toonRamp;
}

// Get lighting toon color
half3 GetLightingToonColor(half3 color, Light light, half3 normalWS, half3 viewDirectionWS, half3 specularColor, float smoothness, TEXTURE2D_PARAM(toonRampTex, toonRampTexSampler), float shadowRampBlend, half3 indirect)
{
    // Diffuse
    half3 diffuse = GetLightingToonDiffuse(light, normalWS, TEXTURE2D_ARGS(toonRampTex, toonRampTexSampler), shadowRampBlend);
    // Specular
    half3 specular = GetLightingToonSpecular(light, normalWS, viewDirectionWS, specularColor, smoothness, TEXTURE2D_ARGS(toonRampTex, toonRampTexSampler));

    return (diffuse + indirect) * (specular + color);
}

#endif