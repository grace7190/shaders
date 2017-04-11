Shader "Custom/TerrainShaderWithAlpha"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_SpecMap ("Specular Map", 2D) = "bump" {}
		_Tiling("Tiling", Float) = 1.0
		_SpecMultiplier("SpecMulti", Range(0.0,1.0)) = 0.0
		_AlphaMap("Alpha Blending Map", 2D) = "alpha" {}
	}

	SubShader
	{
		Tags { "RenderType"="Transparent" }
		LOD 100

		// diffuse/texture pass
		Pass
		{
			Tags{ "LightMode" = "ForwardBase" }
			Blend SrcAlpha OneMinusSrcAlpha
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
				fixed3 ambient : COLOR1;
				fixed3 spec : COLOR2;
				float4 pos : SV_POSITION;
			};

			//from shader properties
			float _SpecMultiplier;
			float _Tiling;

			v2f vert(appdata_base v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				half3 worldNormal = UnityObjectToWorldNormal(v.normal);
				half nl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));
				o.diff = nl * _LightColor0.rgb;
				o.ambient = ShadeSH9(half4(worldNormal,1));

				//blinn-phong without specular
				half3 halfDir = normalize(_WorldSpaceLightPos0.xyz + normalize(WorldSpaceViewDir(v.vertex)));

				// compute shadows data
				TRANSFER_SHADOW(o)
				return o;
			}

			sampler2D _MainTex;
			sampler2D _SpecMap;
			sampler2D _AlphaMap;

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv * _Tiling);
				fixed4 speccol = tex2D(_SpecMap, i.uv * _Tiling);
				fixed4 alpha = tex2D(_AlphaMap, i.uv); 
				fixed shadow = SHADOW_ATTENUATION(i); //0.0-1.0 shadowed-lit
				fixed3 lighting = i.diff * shadow + i.ambient + shadow * speccol.rgb * _SpecMultiplier;
				col.rgb *= lighting;// *alpha.rgb;
				//col.aaaa = alpha;
				col.a = alpha.rgb;
				//return float4(1.0, 0.0, 0.0, 0.3);
				return col;
			}
			ENDCG
		}

		//// cast shadow pass
		//Pass
		//{
		//	Tags{ "LightMode" = "ShadowCaster" }

		//	CGPROGRAM
		//	#pragma vertex vert
		//	#pragma fragment frag
		//	#pragma multi_compile_shadowcaster
		//	#include "UnityCG.cginc"

		//	struct v2f {
		//	V2F_SHADOW_CASTER;
		//};

		//v2f vert(appdata_base v)
		//{
		//	v2f o;
		//	TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
		//		return o;
		//}

		//float4 frag(v2f i) : SV_Target
		//{
		//	SHADOW_CASTER_FRAGMENT(i)
		//}
		//	ENDCG
		//}

	}
}
