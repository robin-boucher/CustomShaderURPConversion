Shader "Sample/ToonOutline"
{
    Properties
    {
        // Main texture and tint
        _Color("Main Color", Color) = (1, 1, 1, 1)
        _MainTex("Main Tex", 2D) = "white" {}

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
        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" }
        LOD 200

        // Forward base pass
        Pass
        {
            Name "ForwardBase"
            Tags { "LightMode" = "ForwardBase" }

            Blend Off
            ZWrite On
            Cull Back

            CGPROGRAM

            #pragma target 2.0

            // Vertex/fragment functions
            #pragma vertex vertToon
            #pragma fragment fragToon

            // GPU Instancing
            #pragma multi_compile_instancing
            // Shadows
            #pragma multi_compile _ SHADOWS_SCREEN
            // Fog
            #pragma multi_compile_fog

            // Unity includes
            #include "UnityCG.cginc"

            // Pass includes
            #include "Inc/LightingToonPass.cginc"

            ENDCG
        }

        // Forward add pass
        Pass
        {
            Name "ForwardAdd"
            Tags { "LightMode" = "ForwardAdd" }

            Blend One One
            ZWrite Off  // Don't write to depth twice
            //Cull Back

            CGPROGRAM

            #pragma target 2.0

            // Vertex/fragment functions
            #pragma vertex vertToon
            #pragma fragment fragToon

            // GPU Instancing
            #pragma multi_compile_instancing
            // Fog
            #pragma multi_compile_fog
            // Lighting variations
            #pragma multi_compile_fwdadd_fullshadows
            #pragma skip_variants DIRECTIONAL_COOKIE POINT_COOKIE SPOT_COOKIE
                        
            // Unity includes
            #include "UnityCG.cginc"

            // Indicate that this is forward add pass
            #define SAMPLE_ADD_PASS

            // Pass includes
            #include "Inc/LightingToonPass.cginc"
            
            ENDCG
        }

        // Outline pass
        Pass
        {
            Name "Outline"

            Blend Off
            Cull Front // For outline

            CGPROGRAM

            #pragma target 2.0

            // Vertex/fragment functions
            #pragma vertex vert
            #pragma fragment frag

            // GPU Instancing
            #pragma multi_compile_instancing
            // Fog
            #pragma multi_compile_fog

            // Unity includes
            #include "UnityCG.cginc"

            // Properties
            half4 _OutlineColor;
            half _OutlineThickness;

            // Vert input
            struct appdata
            {
                float4 vertex       : POSITION;  // Object-space position
                float3 normalOS     : NORMAL;    // Object-space normal

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // Vert output/Frag input
            struct v2f
            {
                float4 pos   : SV_POSITION; // Clip-space position

                UNITY_FOG_COORDS(1)
            };

            // Vertex function
            v2f vert(appdata v)
            {
                v2f o;

                UNITY_INITIALIZE_OUTPUT(v2f, o);

                // For GPU instancing
                UNITY_SETUP_INSTANCE_ID(v);

                // Transformations
                float3 normalCS = mul((float3x3) UNITY_MATRIX_VP, mul((float3x3) UNITY_MATRIX_M, v.normalOS));
                float4 positionCS = UnityObjectToClipPos(v.vertex);

                // Apply normal-based outline in clip space
                half2 outlineNormal = normalize(normalCS.xy); // Discard z
                positionCS.xy += (outlineNormal / _ScreenParams.xy) * _OutlineThickness * positionCS.w; // Expand vertex in normal direction

                // Set output
                o.pos = positionCS;
                UNITY_TRANSFER_FOG(o, positionCS);

                return o;
            }

            // Fragment function
            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 color = _OutlineColor;

                UNITY_APPLY_FOG(i.fogCoord, color);

                return color;
            }

            ENDCG
        }

        // ShadowCaster pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual

            CGPROGRAM

            #pragma target 2.0

            // Vertex/fragment functions
            #pragma vertex vert
            #pragma fragment frag

            // GPU Instancing
            #pragma multi_compile_instancing
            
            // Unity includes
            #include "UnityCG.cginc"

            // Vert input
            struct appdata
            {
                float4 vertex       : POSITION;   // Object-space position
                float3 normalOS     : NORMAL;     // Object-space normal

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // Vert output/Frag input
            struct v2f
            {
                float4 pos  : SV_POSITION; // Clip-space position
            };

            // Vertex function
            v2f vert(appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);

                // Transformations and shadow bias
                float4 positionCS = UnityClipSpaceShadowCasterPos(v.vertex.xyz, v.normalOS);
                positionCS = UnityApplyLinearShadowBias(positionCS);

                // Set output
                o.pos = positionCS;

                return o;
            }

            // Fragment function
            fixed4 frag(v2f i) : SV_Target
            {
                return 0;
            }

            ENDCG
        }
    }
}
