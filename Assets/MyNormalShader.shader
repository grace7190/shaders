// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/WorldNormals"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_BumpMap("Normal Map", 2D) = "bump" {}
		_Specular("Spec", Range(0.0,50.0)) = 0.0
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		//diffuse/texture pass


		// surface lighting pass
		Pass
		{
			Tags{ "LightMode" = "ForwardBase" }
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
			float _Specular;

			v2f vert(appdata_base v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				half3 worldNormal = UnityObjectToWorldNormal(v.normal);
				half nl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));
				o.diff = nl * _LightColor0.rgb;
				o.ambient = ShadeSH9(half4(worldNormal,1));

				//blinn-phong | halfDir=lightDir+viewDir
				half3 halfDir = normalize(_WorldSpaceLightPos0.xyz + normalize(WorldSpaceViewDir(v.vertex)));
				float specAngle = max(dot(halfDir, worldNormal), 0.0);
				o.spec = pow(specAngle, _Specular) * _LightColor0;

				// compute shadows data
				TRANSFER_SHADOW(o)
				return o;
			}

			sampler2D _MainTex;

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				fixed shadow = SHADOW_ATTENUATION(i); //0.0-1.0 shadowed-lit
				fixed3 lighting = i.diff * shadow + i.ambient + i.spec * shadow;
				col.rgb *= lighting;
				return col;
			}
			ENDCG
		}

		//normal pass
		Pass
		{
			Tags{ "LightMode" = "ForwardAdd" }
			Blend One One
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct v2f {
			half3 worldPos : TEXCOORD0;
			half3 tspace0 : TEXCOORD1; // tangent.x, bitangent.x, normal.x
			half3 tspace1 : TEXCOORD2; // tangent.y, bitangent.y, normal.y
			half3 tspace2 : TEXCOORD3; // tangent.z, bitangent.z, normal.z
										// texture coordinate for the normal map
			float2 uv : TEXCOORD4;
			float4 pos : SV_POSITION;
		};

		// vertex shader: takes object space normal as input too
		v2f vert(float4 vertex : POSITION, float3 normal : NORMAL, float4 tangent : TANGENT, float2 uv : TEXCOORD0)
		{
			v2f o;
			o.pos = UnityObjectToClipPos(vertex);
			o.worldPos = mul(unity_ObjectToWorld, vertex).xyz;
			half3 wNormal = UnityObjectToWorldNormal(normal);
			half3 wTangent = UnityObjectToWorldDir(tangent.xyz);
			// compute bitangent from cross product of normal and tangent
			half tangentSign = tangent.w * unity_WorldTransformParams.w;
			half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
			// tangent space matrix
			o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
			o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
			o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
			o.uv = uv;
			return o;
		}

		//from shader properties
		sampler2D _MainTex;
		sampler2D _BumpMap;

		fixed4 frag(v2f i) : SV_Target
		{
			// sample the normal map, and decode from the Unity encoding
			half3 tnormal = UnpackNormal(tex2D(_BumpMap, i.uv));
			// normal from tangent to world space
			half3 worldNormal;
			worldNormal.x = dot(i.tspace0, tnormal);
			worldNormal.y = dot(i.tspace1, tnormal);
			worldNormal.z = dot(i.tspace2, tnormal);

			//compute view dir and refl vector per pixel
			half3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
			half3 worldRefl = reflect(-worldViewDir, worldNormal);

			half4 skyData = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, worldRefl);
			half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR);
			fixed4 c = 0;
			c.rgb = skyColor;

			// modulate sky color with the base texture, and the occlusion map
			fixed3 baseColor = tex2D(_MainTex, i.uv).rgb;
			c.rgb = baseColor + tnormal*skyColor;

			return c;
			}
			ENDCG
		}

		// cast shadow pass
		Pass
		{
			Tags{ "LightMode" = "ShadowCaster" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"

			struct v2f {
			V2F_SHADOW_CASTER;
		};

		v2f vert(appdata_base v)
		{
			v2f o;
			TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				return o;
		}

		float4 frag(v2f i) : SV_Target
		{
			SHADOW_CASTER_FRAGMENT(i)
		}
			ENDCG
		}

	}
}
