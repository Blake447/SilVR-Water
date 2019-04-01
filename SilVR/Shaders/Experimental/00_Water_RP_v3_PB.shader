Shader "SilVR Experimental/Render Plane Phys. Based"
{
	Properties
	{
		// This particular version of the render plane adds support for negative amplitudes and more realistic wave propegation.
		// In order to use this one, the render plane must be set to ARGB64, resulting in an increase in performance cost. The
		// rise in performance cost is the same however as the lowered cost due to the latest change to use one single plane
		// instead of two frames side by side.
		
		_MainTex ("Render Plane (Render Texture)", 2D) = "white" {}
		_CamIn("Camera In (Render Texture)", 2D) = "magenta" {}

		_imgWidth("Image width", float) = 480
		_imgHeight("Image height", float) = 480

		_WaveSpeed("Wave Speed", float) = 1

		_damping("Damping", Range(0,1)) = .99
		_maxLine("ObjectWave height", Range(-1,1)) = 1
		_smoothing("Smoothing Factor", Range(0,1)) = 0

		_WaterMask("Water Mask Map", 2D) = "white" {}
		_Masking("Water Mask weight", Range(0,1)) = 0

		_Bounce("Bouncing factor", float) = 1

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
			//#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				//UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D_half _MainTex;
			float4 _MainTex_ST;

			sampler2D_half _CamIn;
			sampler2D_half _WaterMask;

			fixed _maxLine;

			float _damping;
			float _smoothing;

			float _Masking;


			float _WaveSpeed;
			float _imgWidth;
			float _imgHeight;
			
			float _Bounce;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			float4 frag (v2f i) : SV_Target
			{

				//Beginning of heightmap Generation
				//Beginning of heightmap Generation


				float RAD_TWO = .7071068;

				//calculate the change in uv coords based off resolution and set max line for the rendering.
				float3 q = float3(1 / _imgWidth * _WaveSpeed, 1/_imgHeight * _WaveSpeed, 0);
				float ml = _maxLine;
				

				// Generate the uv coordinates for sampling at the current and its 4 surround points.
				float2 uv = i.uv;
				float2 uv_u = uv + q.zy*_WaveSpeed;
				float2 uv_d = uv - q.zy*_WaveSpeed;
				float2 uv_l = uv - q.xz*_WaveSpeed;
				float2 uv_r = uv + q.xz*_WaveSpeed;

				float2 b_u = uv + q.zy*_WaveSpeed*_Bounce;
				float2 b_d = uv - q.zy*_WaveSpeed*_Bounce;
				float2 b_l = uv - q.xz*_WaveSpeed*_Bounce;
				float2 b_r = uv + q.xz*_WaveSpeed*_Bounce;

				// Sample the renderplane (current and immediately previous frames of the water heightmap)
				float4 rp_col = tex2D(_MainTex, uv);
				float4 rp_col_u = tex2D(_MainTex, uv_u);
				float4 rp_col_d = tex2D(_MainTex, uv_d);
				float4 rp_col_l = tex2D(_MainTex, uv_l);
				float4 rp_col_r = tex2D(_MainTex, uv_r);

				// Sample the camera at the given uv points
				fixed4 cam_col = tex2D(_CamIn, uv);
				fixed4 cam_col_u = tex2D(_CamIn, uv_u);
				fixed4 cam_col_d = tex2D(_CamIn, uv_d);
				fixed4 cam_col_l = tex2D(_CamIn, uv_l);
				fixed4 cam_col_r = tex2D(_CamIn, uv_r);

				// Sample the water mask to see if the pool should calculate at that spot
				float mask = step(.02, tex2D(_WaterMask, uv).x);
				float mask_u = step(.02, tex2D(_WaterMask, b_u).x);
				float mask_d = step(.02, tex2D(_WaterMask, b_d).x);
				float mask_l = step(.02, tex2D(_WaterMask, b_l).x);
				float mask_r = step(.02, tex2D(_WaterMask, b_r).x);

				mask = (1 - _Masking) + _Masking * mask;
				mask_u = (1 - _Masking) + _Masking * mask_u;
				mask_d = (1 - _Masking) + _Masking * mask_d;
				mask_l = (1 - _Masking) + _Masking * mask_l;
				mask_r = (1 - _Masking) + _Masking * mask_r;


				// determine whether or not the camera pixel needs to be appended onto the render plane
				float3 signs = float3(1, -1, -1);
				float cull = step(dot(cam_col.xyz, signs), .999);
				float cull_u = step(dot(cam_col_u.xyz, signs), .999);
				float cull_d = step(dot(cam_col_d.xyz, signs), .999);
				float cull_l = step(dot(cam_col_l.xyz, signs), .999);
				float cull_r = step(dot(cam_col_r.xyz, signs), .999);

				// Choose between the maxline specified for appended pixels, or the sampled height value for the render plane.
				// The previous frame is stored in the green channel (y) and the current frame is stored in the red (x).
				// For the current fragment shading point, we will sample the previous frame, and for the others the current as
				// per the hugo-elias algorithm for wave propagation.
				float c = (rp_col.y - rp_col.w)* (1 - cull) + ml*cull;
				float c_u = (rp_col_u.x - rp_col_u.z) * (1 - cull_u) + ml*cull_u;
				float c_d = (rp_col_d.x - rp_col_d.z) * (1 - cull_d) + ml*cull_d;
				float c_l = (rp_col_l.x - rp_col_l.z) * (1 - cull_l) + ml*cull_l;
				float c_r = (rp_col_r.x - rp_col_r.z) * (1 - cull_r) + ml*cull_r;

				//c = c * (1-mask);
				c_u = c_u * mask_u + (rp_col.x - rp_col.z) * (1 - mask_u);
				c_d = c_d * mask_d + (rp_col.x - rp_col.z) * (1 - mask_d);
				c_l = c_l * mask_l + (rp_col.x - rp_col.z) * (1 - mask_l);
				c_r = c_r * mask_r + (rp_col.x - rp_col.z) * (1 - mask_r);

				// Actually implement the hugo elias algorithm.
				c = ( ((c_u + c_d + c_l + c_r) / 2) - c)*_damping;

				// Calculate a smoothing factor
				float smoothing_factor = (c_u + c_d + c_l + c_r) / 4;

				// Apply the smoothing factor
				c = c * (1 - _smoothing) + smoothing_factor * _smoothing;

				float a = 0;
				float b = 0;

				if (c < 0)
				{
					a = -c;
					c = 0;
				}

				// return the next frame in the red channel, the current frame in the green channel
				// and the image mask in blue for debugging purposes.
				float4 col = float4(c, rp_col.x, a, rp_col.z)*mask * mask_u * mask_d * mask_l * mask_r;

				return col;

			}
			ENDCG
		}
	}
}



