Shader "SilVR Experimental/Normal Calculation Phys. Based"
{
	Properties
	{
		_MainTex ("Normal Out (Render Texture)", 2D) = "white" {}
		_imgWidth("Image Width", float) = 540
		_imgHeight("Image Height", float) = 540
		_WaveSpeed("Wave speed", float) = 1
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _imgWidth;
			float _imgHeight;
			float _WaveSpeed;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv);

			// determine the distance to check outwards when generating a normal map.
				float3 q = float3(1 / _imgWidth * _WaveSpeed, 1 / _imgHeight * _WaveSpeed, 0);
	
				// generate the coordinates for checking outward when generating a normal map
				float2 uv = i.uv;	
				float2 cauv = uv + q.zy;
				float2 cbuv = uv - q.zy;
				float2 ccuv = uv + q.xz;
				float2 cduv = uv - q.xz;

	
				// sample the renderplane as a height map at outward points to generate a normal map
				float2 weights = float2(1, -1);
	
				float ca = dot(tex2D(_MainTex, cauv).xz, weights);
				float cb = dot(tex2D(_MainTex, cbuv).xz, weights);
				float cc = dot(tex2D(_MainTex, ccuv).xz, weights);
				float cd = dot(tex2D(_MainTex, cduv).xz, weights);
	
				// calculate the difference (approximation of a partial derivative) across the x and y axis to generate a normal vector
				float2 diff = float2(ca - cb, cc - cd);
				float2 halves = float2(0.5, 0.5);

				float4 c = float4(halves - diff*0.5, 1, .5);
				//c = normalize(c);

				// apply fog
				//UNITY_APPLY_FOG(i.fogCoord, col);
				return c;
			}
			ENDCG
		}
	}
}
