// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "SilVR/Mirror Cutout"
{
	Properties
	{
		_MainTex("Base (RGB)", 2D) = "white" {}
		_Color("Color (supports transparency)", Color) = (1,1,1,1)
		_AlphaMask("Alpha mask", 2D) = "white" {}
		[HideInInspector] _ReflectionTex0("", 2D) = "white" {}
		[HideInInspector] _ReflectionTex1("", 2D) = "white" {}
	}
	SubShader
	{
		Tags{ "Queue" = "Transparent" "RenderType" = "Transparent" }
		LOD 100
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityStandardCore.cginc"

			sampler2D _ReflectionTex0;
			sampler2D _ReflectionTex1;
			sampler2D _AlphaMask;
			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 refl : TEXCOORD1;
				float4 pos : SV_POSITION;
			};

			v2f vert(VertexInput v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv0, _MainTex);
				o.refl = ComputeNonStereoScreenPos(o.pos);

				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed4 tex = tex2D(_MainTex, i.uv);
				fixed4 refl = unity_StereoEyeIndex == 0 ? tex2Dproj(_ReflectionTex0, UNITY_PROJ_COORD(i.refl)) : tex2Dproj(_ReflectionTex1, UNITY_PROJ_COORD(i.refl));
				return tex * refl * _Color * float4(1,1,1,tex2D(_AlphaMask, i.uv).y);
			}
			ENDCG
		}
	}
}