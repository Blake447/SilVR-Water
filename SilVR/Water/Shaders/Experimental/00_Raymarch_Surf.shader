Shader "SilVR Experimental/Raymarched Water Surface"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_Matte("Matte", Range(0,1)) = 0
		_Cubemap("Cubemap", Cube) = "black" {}
		_Epsilon("Epsilon", range(.00001, .01)) = .01
		_LX("Light X position", range(-1,1)) = 1
		_LY("Light Y position", range(0,1)) = 1
		_LZ("Light Z position", range(-1,1)) = 1

		_AlphaMask("Alpha mask", 2D) = "white" {}

		_Alpha("Transparency", range(0,1)) = 1
		_AlphaBase("Alpha baseline", range(0,1)) = 0
		_WaveHeight("Wave height", float) = 1

		_ImgRes("Image Resolution", float) = 720

		_CheckDistance("Base check distance", float) = 1
		_AverageDistance("Average distance multiplier", float) = 1
		_LightDistance("Light distance multiplier", float) = 0.66667
		_NormalDistance("Normal distance multiplier", float) = 1

		_Smoothing("Smoothing", Range(0,1)) = 1

		_LightDensity("Light Density", Range(0,1)) = 0.9

	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent-1" }
		LOD 100
		Cull Front
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#define PI 3.14159265
			#define ROOT_HALF .707106781
			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 wpos : TEXCOORD0;
				//float3 light : TEXCOORD1;
			};

			struct fragOut
			{
				float4 color : SV_Target;
				float depth : SV_Depth;
			};

			sampler2D _MainTex;
			sampler2D_float _CameraDepthTexture;
			samplerCUBE _Cubemap;
			fixed4 _Color;
			float _Matte;
			float _LX;
			float _LY;
			float _LZ;

			float _Epsilon;

			float _Alpha;
			float _AlphaBase;
			float _Iterations;
			float _WaveHeight;


			float _CheckDistance;
			float _AverageDistance;
			float _LightDistance;
			float _NormalDistance;

			sampler2D _AlphaMask;

			float _ImgRes;
			float _Smoothing;

			float _LightDensity;

			fixed withinBounds(float2 uv)
			{
				float retval = 1;
				if (uv.x > 1 || uv.x < 0 || uv.y > 1 || uv.y < 0)
				{
					retval = 0;
				}
				return retval;

			}

			float4 averageSample(sampler2D image, float2 uv, float epsilon)
			{
				float2 uv1 = uv + float2 ( 1,  0) * epsilon;
				float2 uv2 = uv + float2 (-1,  0) * epsilon;
				float2 uv3 = uv + float2 ( 0,  1) * epsilon;
				float2 uv4 = uv + float2 ( 0, -1) * epsilon;

				float4 col = tex2D(image, uv) * withinBounds(uv);
				float4 col1 = tex2D(image, uv1) * withinBounds(uv1);
				float4 col2 = tex2D(image, uv2) * withinBounds(uv2);
				float4 col3 = tex2D(image, uv3) * withinBounds(uv3);
				float4 col4 = tex2D(image, uv4) * withinBounds(uv4);

				float4 color = (col + col1 + col2 + col3 + col4) * 0.2;

				return color;
			}

			float3 intersectYPlane(float3 cam, float3 ray, float h)
			{
				float x = (ray.x / ray.y) * (h - cam.y) + cam.x;
				float z = (ray.z / ray.y) * (h - cam.y) + cam.z;
				return float3(x, h, z);
			}

			float2 worldToUV(float3 p, float3 center, float3 dim)
			{
				float u = -(p.x - center.x) / dim.x + 0.5;
				float v = -(p.z - center.z) / dim.z + 0.5;
				return float2(u, v);
			}


			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				//o.light = normalize(_WorldSpaceLightPos0.xyz);
				o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
			}


			fragOut frag(v2f i)
			{
				//Heyy Neen, I'm taking the time to comment this for you :)
				fragOut f;

				//Alright so this just defines the maximum amount of steps we'll use, I probably don't
				//have to explain something as simple as this but whatever :D
				float maxStep = 32;
				float4 clipPos = float4(0,0,0,0);
				float clipDepth = 0;
				float3 normal = float3(0, 1, 0);

				//alright, let's get straight into raycasting, getting the direction and origin of the
				//ray is super easy, for the direction you just take the vector between the camera position
				//and the world position of the current pixel that's processed and tada, you got the direction
				//normalize this shit and you're good to go
				float3 ray = normalize(i.wpos - _WorldSpaceCameraPos.xyz);
				//the position the ray starts is just as easy, it's our camera position, who would have guessed that
				float3 cam = _WorldSpaceCameraPos.xyz;


				const float3 center = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;

				float size_x = length(mul(unity_ObjectToWorld, float4(1, 0, 0, 1)).xyz - center)*0.1;
				float size_y = length(mul(unity_ObjectToWorld, float4(0, 0, 1, 1)).xyz - center)*0.1;
				
				float3 dim = float3(2.5*size_x, 2, 2.5*size_y);
				float3 A = intersectYPlane(cam, ray, center.y + .05*_WaveHeight);
				float3 B = intersectYPlane(cam, ray, center.y - .05*_WaveHeight);


				float3 S = (B-A) * (1 / 32.0);
				float3 R = (A-B) * (1 / 32.0);

				float3 T = S;

				float stepSize = 1.0;
				float j = 0;
				bool exitFlag = false;
				float3 p = A-T;

				float4 debug;
				float distance = sqrt(dot(T,T));
				float inverseRes = 1.0 / _ImgRes;
				float baseDistance = inverseRes*_CheckDistance;

				float2 uv = float2(0, 0);

				while (j < 33 && !exitFlag)
				{
					p += normalize(T)*distance;
					uv = worldToUV(p, center, dim);
					float height1 = dot(float4(1.0, 0, -1.0, 0), averageSample(_MainTex, uv, baseDistance))*0.05*_WaveHeight + center.y;
					float height2 = dot(float4(1.0, 0, -1.0, 0), tex2D(_MainTex, uv))*0.05*_WaveHeight + center.y;

					float height = _Smoothing * height1 + (1 - _Smoothing)*height2;

					distance = p.y - height;

					//height = height;



					if (distance < _Epsilon)
					{
						exitFlag = true;
					}

					j++;
					debug = float4(1, 1, 1, 0)*(j/31) + float4(0,0,0,1);
				}

				float visible = step(0.5, tex2D(_AlphaMask, worldToUV(p, center, dim)).x) * step(0,dot(ray, -normal * (step(center.y, cam.y)*2-1) ));

					if (abs(p.x - center.x) > dim.x*0.5 || abs(p.z - center.z) > dim.z*0.5)
					{
						clip(-1);
						
					}

				exitFlag = false;
				float k = 0;
				float3 q = p;
				float3 light = normalize(float3(_LX, _LY, _LZ));

				//float3 light = i.light;

				float pixel = 1.0;

				//float2 uv = float2(0, 0);

				while (k < 16)
				{
					q = p + light * k * .05 * _LightDistance;
					float2 uv = worldToUV(q, center, dim);
					float height = dot(float4(1.0, 0, -1.0, 0), averageSample(_MainTex, uv, baseDistance))*0.1 + center.y;

					if (q.y < height)
					{
						pixel *= _LightDensity;
					}

					k++;
				}

				float3 check_size = float3(baseDistance*_NormalDistance, baseDistance*_NormalDistance, 0);

				// generate the coordinates for checking outward when generating a normal map
				float2 cauv = uv + check_size.zy;
				float2 cbuv = uv - check_size.zy;
				float2 ccuv = uv + check_size.xz;
				float2 cduv = uv - check_size.xz;

				// sample the current height for literally no reason
				float d = tex2D(_MainTex, uv).x;

				// sample the renderplane as a height map at outward points to generate a normal map
				float2 weights = float2(1, -1);

				float ca = dot(averageSample(_MainTex, cauv, baseDistance).xz, weights);
				float cb = dot(averageSample(_MainTex, cbuv, baseDistance).xz, weights);
				float cc = dot(averageSample(_MainTex, ccuv, baseDistance).xz, weights);
				float cd = dot(averageSample(_MainTex, cduv, baseDistance).xz, weights);

				// calculate the difference (approximation of a partial derivative) across the x and y axis to generate a normal vector
				float2 diff = float2(ca - cb, cc - cd);
				float4 c = float4(normalize(float3(diff.x, 1, diff.y)), 1);

				float3 emission = texCUBE(_Cubemap, reflect(ray, c.xyz)).rgb;

				//float2 uv = worldToUV(p, center, dim);

				clipPos = mul(UNITY_MATRIX_VP, float4(p, 1.0));
				clipDepth = clipPos.z/clipPos.w;

				//f.color = tex2D(_MainTex, uv);

				float alpha = (_AlphaBase) + _Alpha*(1-_AlphaBase)*(1-abs(dot(c, ray)));

				float4 finalColor = float4(((debug.xyz * _Matte + emission * (1 - _Matte))*pixel).xyz, alpha*visible);

				f.color = finalColor*_Color;
				f.depth = clipDepth;
				return f;
			}
			ENDCG
		}
	}
}
