Shader "Custom/BlacklightShader"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_BlacklightMap ("UVLight Alpha", 2D) = "white" {}
		_Tiling("Tiling", Float) = 1.0
		_BlacklightMulti("UVLight Multi", Range(0.0,2.0)) = 0.0

	}

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		// diffuse/texture pass
		Pass
		{
			Tags{ "LightMode" = "ForwardAdd" }
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "Lighting.cginc"

			// compile shader into multiple variants, with and without shadows
			#pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
			#include "AutoLight.cginc"

			struct v2f
			{
				float2 uv : TEXCOORD0;
				SHADOW_COORDS(1) // put shadows data into TEXCOORD1
				fixed3 diff : COLOR0;
				float4 pos : SV_POSITION;
			};

			//from shader properties
			
			float _Tiling;

			v2f vert(appdata_base v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord * _Tiling;
				half3 worldNormal = UnityObjectToWorldNormal(v.normal);
				half nl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));
				o.diff = nl * _LightColor0.rgb;

				half3 halfDir = normalize(_WorldSpaceLightPos0.xyz + normalize(WorldSpaceViewDir(v.vertex)));

				// compute shadows data
				TRANSFER_SHADOW(o)
				return o;
			}

			sampler2D _MainTex;
			sampler2D _SpecMap;

			float4 _Color;
			sampler2D _BlacklightMap;
			float _BlacklightMulti;

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 col = _Color;
				fixed4 alpha = tex2D(_BlacklightMap, i.uv);
				fixed shadow = SHADOW_ATTENUATION(i); //0.0-1.0 shadowed-lit
				
				col.rgb *= (_BlacklightMulti-i.diff * shadow * 3) * alpha; //add more glow in shadow areas
				col.b += 0.1; //add 'blacklight' glow
				return col;
			}
			ENDCG
		}


	}
}
