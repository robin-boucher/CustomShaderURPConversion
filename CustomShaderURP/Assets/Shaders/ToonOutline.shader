Shader "Sample/ToonOutline"
{
    Properties
    {
        // Main texture and tint
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _BaseMap("Base Map", 2D) = "white" {}

        // Normal map
        [Normal] _NormalTex("Normal Tex", 2D) = "bump" {}

        // Toon ramp
        _ToonRampTex("Toon Ramp Tex", 2D) = "white" {}

        // Shadow ramp
        _ShadowRampBlend("Shadow Ramp Blend", Range(0, 0.5)) = 0.2

        // Specular
        _SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
        _Smoothness("Smoothness", Range(0, 1)) = 0.5

        // Outline
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineThickness("Outline Thickness", Float) = 3.5
    }
    SubShader
    {
        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" }
        LOD 200

        // Forward base pass
        Pass
        {
            Name "ForwardBase"
            Tags { "LightMode" = "UniversalForward" }

            Blend Off
            ZWrite On
            Cull Back

            HLSLPROGRAM

            // Required to compile gles 2.0 with standard SRP library
            #pragma prefer_hlslcc gles
            #pragma target 2.0

            // Vertex/fragment functions
            #pragma vertex vertToon
            #pragma fragment fragToon

            // GPU Instancing
            #pragma multi_compile_instancing
            // Fog
            #pragma multi_compile_fog

            // Enable shadows on main light
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            // Shadow cascades
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            // Enable additional lights
            // Also add _ADDITIONAL_LIGHTS_VERTEX if doing vertex lighting with additional lights
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            // Enable shadows on additional lights
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            // Soft shadows
            #pragma multi_compile _ _SHADOWS_SOFT
            
            // URP includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Pass includes
            #include "Inc/LightingToonPass.hlsl"

            ENDHLSL
        }

        // Outline pass
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }

            Blend Off
            Cull Front // For outline

            HLSLPROGRAM

            // Required to compile gles 2.0 with standard SRP library
            #pragma prefer_hlslcc gles
            #pragma target 2.0

            // Vertex/fragment functions
            #pragma vertex vert
            #pragma fragment frag

            // GPU Instancing
            #pragma multi_compile_instancing
            // Fog
            #pragma multi_compile_fog

            // URP includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Properties (needs to be same across all passes for SRP batcher compatibility)
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

            // Vert input
            struct Attributes
            {
                float4 vertex       : POSITION;  // Object-space position
                float3 normalOS     : NORMAL;    // Object-space normal

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // Vert output/Frag input
            struct Varyings
            {
                half fogFactor  : TEXCOORD0;   // Fog factor
                float4 pos      : SV_POSITION; // Clip-space position
            };

            // Vertex function
            Varyings vert(Attributes input)
            {
                Varyings output;

                // For GPU instancing
                UNITY_SETUP_INSTANCE_ID(input);

                // Transformations
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                float3 normalCS = TransformWorldToHClipDir(normalWS);
                float4 positionCS = TransformObjectToHClip(input.vertex.xyz);

                // Apply normal-based outline in clip space
                half2 outlineNormal = normalize(normalCS.xy); // Discard z
                positionCS.xy += (outlineNormal / _ScreenParams.xy) * _OutlineThickness * positionCS.w; // Expand vertex in normal direction

                // Set output
                output.pos = positionCS;
                output.fogFactor = ComputeFogFactor(positionCS.z);

                return output;
            }

            // Fragment function
            half4 frag(Varyings input) : SV_Target
            {
                half4 color = _OutlineColor;

                // Mix fog
                color.rgb = MixFog(color.rgb, input.fogFactor);

                return color;
            }

            ENDHLSL
        }

        // Shadow caster pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

            // Required to compile gles 2.0 with standard SRP library
            #pragma prefer_hlslcc gles
            #pragma target 2.0

            // GPU Instancing
            #pragma multi_compile_instancing

            // Vertex/fragment functions used by ShadowCasterPass.hlsl
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // URP includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // Required by URP ShadowCasterPass.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            // Properties (needs to be same across all passes for SRP batcher compatibility)
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

            // URP Shadow caster pass
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            ENDHLSL
        }
    }
}
