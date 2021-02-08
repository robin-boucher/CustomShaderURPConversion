#ifndef SAMPLE_LIGHTING_TOON_INCLUDED
#define SAMPLE_LIGHTING_TOON_INCLUDED

// Basic toon lighting implementation

// Diffuse
fixed3 GetLightingToonDiffuse(UnityLight light, float distanceAttenuation, float shadowAttenuation, half3 normalWS, sampler2D toonRampTex, float shadowRampBlend)
{
    float NDL = saturate(dot(normalWS, light.dir));

    // Sample toon ramp (assumes toon ramp tex is horizontal, dark -> light)
    float2 toonRampUV = float2(NDL, 0.5);
    fixed3 toonRamp = tex2D(toonRampTex, toonRampUV).rgb;

    // Apply shadow attenuation (smoothstep)
    toonRamp *= smoothstep(0.5 - shadowRampBlend, 0.5 + shadowRampBlend, shadowAttenuation);

    return light.color * distanceAttenuation * toonRamp;
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
fixed3 GetLightingToonSpecular(UnityLight light, float shadowAttenuation, half3 normalWS, half3 viewDirectionWS, fixed3 specularColor, float smoothness, sampler2D toonRampTex)
{
    // Specular factor
    float specularFactor = GetSpecularFactor(normalWS, light.dir, viewDirectionWS, smoothness);

    // Sample toon ramp (assumes toon ramp tex is horizontal, dark -> light)
    float2 toonRampUV = float2(saturate(specularFactor), 0.5);
    fixed3 toonRamp = tex2D(toonRampTex, toonRampUV).rgb;

    return light.color * specularColor * toonRamp;
}

// Get lighting toon color
fixed3 GetLightingToonColor(fixed3 color, UnityLight light, float distanceAttenuation, float shadowAttenuation, half3 normalWS, half3 viewDirectionWS, fixed3 specularColor, float smoothness, sampler2D toonRampTex, float shadowRampBlend, fixed3 indirect)
{
    // Diffuse
    fixed3 diffuse = GetLightingToonDiffuse(light, distanceAttenuation, shadowAttenuation, normalWS, toonRampTex, shadowRampBlend);
    // Specular
    fixed3 specular = GetLightingToonSpecular(light, shadowAttenuation, normalWS, viewDirectionWS, specularColor, smoothness, toonRampTex);

    return (diffuse + indirect) * (specular + color);
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