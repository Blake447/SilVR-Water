Shader "SilVR Experimental/Water Surface Raymarch-mirror-grabpass"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_Cubemap("Cubemap", Cube) = "white" {}

		_AlphaMask("Alpha mask", 2D) = "white" {}
		_Alpha("Directional Alpha", range(0,1)) = 1
		_AlphaBase("Alpha baseline", range(0,1)) = 0

		_Matte("Matte", Range(0,1)) = 0
		_AO("(Fake) Ambient Occlusion", Range(0,1)) = 0
		_AO_Tint("AO color tint", Color) = (0,0,0,0)

		_Distortion("Distortion", float) = 1
		_ReflectionScale("Reflection Scale", float) = 1

		_WaveHeight("Wave height", float) = 1
		_Epsilon("Epsilon", range(.00001, .01)) = .01

		_Smoothing("Smoothing", Range(0,1)) = 1

		_ImgWidth("Image Width", float) = 720
		_ImgHeight("Image Height", float) = 720
		_CheckDistance("Base check distance", float) = 1
		_AverageDistance("Average distance multiplier", float) = 1
		_NormalDistance("Normal distance multiplier", float) = 1


		_LX("Light X direction", range(-1,1)) = 1
		_LY("Light Y direction", range(-1,1)) = 1
		_LZ("Light Z direction", range(-1,1)) = 1
		_LightDistance("Light Step length", float) = 0.66667
		_LightDensity("Light Density", Range(0,1)) = 0.9


		[HideInInspector] _ReflectionTex0("", 2D) = "white" {}
		[HideInInspector] _ReflectionTex1("", 2D) = "white" {}


	}
	SubShader
	{
		Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
		LOD 100
		//Blend SrcAlpha OneMinusSrcAlpha

		// Use a grabpass to sample the area underneath the water for the distortion effects
		GrabPass
		{
			"_GrabTextureWorld"
		}


		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "UnityStandardCore.cginc"

			// define some useful constants, though they may not be needed for this particular version
			#define PI 3.14159265
			#define ROOT_HALF .707106781
			

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				// Use the position as in a regular vertex shader
				float4 vertex : SV_POSITION;
				
				// The surface is raymarched, so we actually dont need the uv coordinates. 
				// wpos will be used to store the world position of the vertex for said raymarching
				float3 wpos : TEXCOORD0;

				// refl_screenpos stores the pixels screen coordinate for the reflection
				float4 refl_screenpos : TEXCOORD1;

				// grab_screenpos stores the pixels screen coordinate for the grabpass
				float4 grab_screenpos : TEXCOORD2;

				// reserve space for the world space vectors for up and right in screen space
				float3 screen_space_right : TEXCOORD3;
				float3 screen_space_up : TEXCOORD4;
				
				float3 world_x : TEXCOORD5;
				float3 world_z : TEXCOORD6;

			};

			struct fragOut
			{
				float4 color : SV_Target;
				float depth : SV_Depth;
			};

			// _MainTex and _Color are implicity defined by using "UnityStandardCore.cginc". No idea what thatd do in fallback,
			// but it's what VRC_Mirrors do so I figured I'd make conditions as close to that as possible
			samplerCUBE _Cubemap;
			
			sampler2D_float _CameraDepthTexture;
			sampler2D _ReflectionTex0;
			sampler2D _ReflectionTex1;
			sampler2D _GrabTextureWorld;
			sampler2D _AlphaMask;
		
			float _Matte;
			float _LX;
			float _LY;
			float _LZ;
			float4 _AO_Tint;
			float _Epsilon;
			float _Alpha;
			float _AlphaBase;
			float _Iterations;
			float _WaveHeight;
			float _AO;
			float _CheckDistance;
			float _AverageDistance;
			float _LightDistance;
			float _NormalDistance;
			float _ImgRes;
			float _ImgHeight;
			float _ImgWidth;
			float _Smoothing;
			float _LightDensity;
			float _Distortion;
			float _ReflectionScale;

			// This function tests whether a coordinate is within the uv bounds i.e ranging from 0 to 1.
			fixed withinBounds(float2 uv)
			{
				// Assume it is within the bounds of the uv coordinates
				float retval = 1;

				// Check its horizonal and vertical distance from the center. If greater than half the square,
				if (abs(uv.x-0.5) > 0.5 || abs(uv.y - 0.5) > 0.5)
				{
					// we know it is not actually within the uv bounds.
					retval = 0;
				}

				// return our findings.
				return retval;

			}

			// This is meant to blur an image a little by sampling the nearby points, but it really isnt that effective.
			float4 averageSample(sampler2D image, float2 uv, float epsilon)
			{
				// add a the small value epsilon to the uv coordinate in each direction
				float2 uv_up =		uv + float2 ( 0,  1) * epsilon;
				float2 uv_down =	uv + float2 ( 0, -1) * epsilon;
				float2 uv_left =	uv + float2 (-1,  0) * epsilon;
				float2 uv_right	=	uv + float2 ( 1,  0) * epsilon;

				// If the uv coordinate is within the bounds of the image, then sample the color at that point. 
				float4 col_point =	tex2D(image, uv)		* withinBounds(uv);
				float4 col_up =		tex2D(image, uv_up)		* withinBounds(uv_up);
				float4 col_down =	tex2D(image, uv_down)	* withinBounds(uv_down);
				float4 col_left =	tex2D(image, uv_left)	* withinBounds(uv_left);
				float4 col_right =	tex2D(image, uv_right)	* withinBounds(uv_right);

				// average all the sampled colors.
				float4 average_color = (col_point + col_up + col_down + col_left + col_right) * 0.2;

				// return the average
				return average_color;
			}

			// And overloaded with a float2 in case the horizontal and vertical resolution vary
			float4 averageSample(sampler2D image, float2 uv, float2 epsilon)
			{
				// add a the small value epsilon to the uv coordinate in each direction
				float2 uv_up = uv + float2 (0, 1) * epsilon;
				float2 uv_down = uv + float2 (0, -1) * epsilon;
				float2 uv_left = uv + float2 (-1, 0) * epsilon;
				float2 uv_right = uv + float2 (1, 0) * epsilon;

				// If the uv coordinate is within the bounds of the image, then sample the color at that point. 
				float4 col_point = tex2D(image, uv)		* withinBounds(uv);
				float4 col_up = tex2D(image, uv_up)		* withinBounds(uv_up);
				float4 col_down = tex2D(image, uv_down)	* withinBounds(uv_down);
				float4 col_left = tex2D(image, uv_left)	* withinBounds(uv_left);
				float4 col_right = tex2D(image, uv_right)	* withinBounds(uv_right);

				// average all the sampled colors.
				float4 average_color = (col_point + col_up + col_down + col_left + col_right) * 0.2;

				// return the average
				return average_color;
			}

			// Calculate the intersection of a ray coming from the camera with a horizontal plane. Does not support
			// other kinds of planes as that makes the vector math slightly more complicated.
			float3 intersectYPlane(float3 cam, float3 ray, float height)
			{
				// This might not be entirely self explanatory, but its just derived by letting the y component
				// of the ray (y_nought + bt) be equal to the height, solving for t, and plugging that into the
				// expressions for the x and z component of the ray.
				float x = (ray.x / ray.y) * (height - cam.y) + cam.x;
				float z = (ray.z / ray.y) * (height - cam.y) + cam.z;

				// return the intersection point
				return float3(x, height, z);
			}

			// Projects the input point to a horizontal plane (just take the x and z components), calculates its distance
			// from the center, and divides it by the scale of the gameobject to generate a uv coordinate.
			float2 worldToUV(float3 p, float3 center, float3 dim)
			{
				float u = -(p.x - center.x) / dim.x + 0.5;
				float v = -(p.z - center.z) / dim.z + 0.5;
				return float2(u, v);
			}

			float2 worldToUV(float3 p, float3 center, float3 dim, float3 world_x, float3 world_z)
			{
				float u = -(dot(p - center, world_x)) / dim.x + 0.5;
				float v = -(dot(p - center, world_z)) / dim.z + 0.5;
				return float2(u, v);
			}

			// vertex shader.
			v2f vert(appdata v)
			{
				v2f o;

				// get the vertex clip pos as per usual.
				o.vertex = UnityObjectToClipPos(v.vertex);

				// get the vertex world pos for the raymarching calculations
				o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;

				// get the screen pos of the reflection and grabpass points. This will be optional to use.
				o.refl_screenpos = ComputeNonStereoScreenPos(UnityObjectToClipPos(v.vertex));
				o.grab_screenpos = ComputeGrabScreenPos(UnityObjectToClipPos(v.vertex));

				// Calculate the right and up vectors of the camera in object space
				o.screen_space_right = mul(unity_WorldToObject, mul(unity_CameraToWorld, float4(1, 0, 0, 1))).xyz;
				o.screen_space_up = mul(unity_WorldToObject, mul(unity_CameraToWorld, float4(0, 1, 0, 1))).xyz;

				o.world_x = normalize(mul((float3x3)unity_ObjectToWorld, float3(1, 0, 0)));
				o.world_z = normalize(mul((float3x3)unity_ObjectToWorld, float3(0, 1, 0)));

				return o;
			}


			fragOut frag(v2f i)
			{
				// This setup was taken from Neen's example raymarched shader. The setup includes the calculation of the clipping
				// position, the introduction of depth checking, and the calculation of the ray and camera position.
				fragOut f;

				float3 world_x = i.world_x;
				float3 world_z = i.world_z;

				// This is how many steps we will limit the raymarch to.
				const float maxStep = 32;

				// We're just going to initialize these to zero just in case they get lost somewhere.
				float4 clipPos = float4(0,0,0,0);
				float clipDepth = 0;

				//declare the normal direction we will use
				float3 normal = float3(0, 1, 0);

				// Calculate the ray that goes from the camera to the vertex (in world space)
				float3 ray = normalize(i.wpos - _WorldSpaceCameraPos.xyz);

				// Just get the camera position as the rays starting point.
				float3 cam = _WorldSpaceCameraPos.xyz;

				// From here on out its almost all original code again, except for the depth calculation.
				// We will define the center of the raymarched object to be the center of the gameobject in
				// unity. While this could go in the vertex shader, its defined as a constant so it shouldnt
				// matter performance wise.
				const float3 center = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;

				// We are going to determine the scale of the gameobject by converting the x and y unit vectors into
				// world space and seeing how large they are.
				const float size_x = length(mul(unity_ObjectToWorld, float4(1, 0, 0, 1)).xyz - center)*0.1;
				const float size_y = length(mul(unity_ObjectToWorld, float4(0, 1, 0, 1)).xyz - center)*0.1;
				
				// generate the dimensions of the raymarched surface with a correction factor to scale it up to the planes and cameras.
				float3 dim = float3(2.5*size_x, abs(.1*_WaveHeight), 2.5*size_y);

				// Calculate where we should start ray marching from. This would be the intersection of the ray, and the plane
				// horizontal to the surface at the maximum allowed height
				//float3 A = intersectYPlane(cam, ray, center.y + .5*dim.y);
				float3 A = intersectYPlane(cam, ray, center.y + abs(.5*dim.y));

				// generate a point to march by a given ray. This point will start off exactly at the point of
				// intersection we calculated above, along with its uv coordinates and height from the plane.
				// note we do this outside the loop in case we want to access it for lighting or rendering later.
				float3 p = A;
				float2 p_uv = float2(0, 0);
				float p_height = 0;

				// initialize the estimated distance from the nearest point on the wave (not plane) to be zero. This will
				// be clear why in one second.
				float distance = 0;

				// calculate one over the resolution of the image used to sample from. basically, this is one pixel.
				float2 inverseRes = float2(1.0 / _ImgWidth, 1.0 / _ImgHeight);

				// multiply the size of a pixel by some specified distance modifier for use in average sampling later.
				float2 baseDistance = inverseRes*_CheckDistance;

				// start a loop that goes on for as many steps as we specified, or until we hit an exit flag.
				float j = 0;
				bool exitFlag = false;
				while (j < maxStep && !exitFlag)
				{
					// move the point along the ray by a given distance. Note that for the first iteration, distance is initialized
					// to zero and thus this value will be the same as the initial starting position.
					p += ray*distance;

					// update the uv coordinate of the new point, or calculate it for the first time.
					p_uv = worldToUV(p, center, dim, world_x, world_z);

					// generate the height of the wave in world space by sampling the texure. Note that positive amplitude is stored in the x component
					// of the color, and negative amplitude in the z. Thus, the dot of (1,0,-1,0) and the sampled color should just give the height of the
					// wave. Once we get that, we will multiply it by our max wave height and then add it to the center of the object along the y axis
					// so that we get a world space height. Do one for smoothed and one for not smoothed.
					float height_smoothed = dot(float4(1.0, 0, -1.0, 0), averageSample(_MainTex, p_uv, baseDistance))*.5*dim.y + center.y;
					float height_unsmooth = dot(float4(1.0, 0, -1.0, 0), tex2D(_MainTex, p_uv))*.5*dim.y + center.y;

					// record the height to be a linear interpolation between the smoothed and unsmooth value, with weights defined by the user.
					p_height = _Smoothing * height_smoothed + (1 - _Smoothing)*height_unsmooth;

					// calculate the distance between the point we are marching along the ray and the world space height of the wave.
					// Note that although this is not a perfect method, it turns out to be reasonably close as long as the texture is smooth enough.
					distance = p.y - p_height;

					// If we are under a certain distance, we are going to kill the march at the point we sampled from. We allow the user to specify
					// this distance rather than just using zero to minimize overstepping the waters surface.
					if (distance < _Epsilon)
					{
						exitFlag = true;
					}

					// at the end of each iteration, we will increase the index by one.
					j++;
				}

				// This line calculates the visibility of the point we marched to. The first half checks if we are using an alpha mask.
				// The second half of the line tests to see if we are on the right side of the ray marched surface with a dot product
				// of the normal vector.
				float visible = step(0.5, tex2D(_AlphaMask, p_uv).x) * step(0,dot(ray, -normal * (step(center.y, cam.y)*2-1) ));

				// if the sampled point is outside the sampled uv points, then we are going to clip it out.
				if (abs(dot(p - center, world_x)) > dim.x*0.5 || abs(dot(p - center, world_z)) > dim.z*0.5)
				{
					clip(-1);
				}

				// initialize another point to march from as well as its uv coordinates.
				float3 q = p;
				float2 q_uv = float2(0, 0);

				// use a user specified light. Note that we will not use the actual directional light for performance sake
				float3 light = normalize(float3(_LX, _LY, _LZ));

				// this 'pixel' value will be the amount of light the pixel gets. Initialized to one.
				float pixel = 1.0;
			
				// begin another loop from the next point. I am going to limit this one to half the iterations as the first, because in most
				// cases it will not be very interesting, it just adds a slight change.
				float k = 0;
				while (k < 16)
				{
					// starting at q, march forward along the light vector by a specified distance. This one is much less picky as
					// we really dont care about the surface.
					q = p + light * k * .05 * _LightDistance;
			
					// update the uv coordinate of the point q.
					q_uv = worldToUV(q, center, dim, world_x, world_z);
					
					// calculate the height of the wave as before. 
					float height_smoothed = dot(float4(1.0, 0, -1.0, 0), averageSample(_MainTex, q_uv, baseDistance))*.5*dim.y + center.y;
					float height_unsmooth = dot(float4(1.0, 0, -1.0, 0), tex2D(_MainTex, q_uv))*.5*dim.y + center.y;

					// record the height to be a linear interpolation between the smoothed and unsmooth value, with weights defined by the user.
					float height = _Smoothing * height_smoothed + (1 - _Smoothing)*height_unsmooth;
				
					// If the point is below a wave,
					if (q.y < height)
					{
						// darken the pixel.
						pixel *= _LightDensity;
					}

					// increase the loop iteration by one.
					k++;
				}

				float3 check_size = float3(baseDistance*_NormalDistance, 0);

				// generate the coordinates for checking outward when generating a normal map
				float2 cauv = p_uv + check_size.zy;
				float2 cbuv = p_uv - check_size.zy;
				float2 ccuv = p_uv + check_size.xz;
				float2 cduv = p_uv - check_size.xz;

				// sample the current height for literally no reason
				float d = tex2D(_MainTex, p_uv).x;

				// sample the renderplane as a height map at outward points to generate a normal map
				float2 weights = float2(1, -1);

				float ca = dot(averageSample(_MainTex, cauv, baseDistance).xz, weights);
				float cb = dot(averageSample(_MainTex, cbuv, baseDistance).xz, weights);
				float cc = dot(averageSample(_MainTex, ccuv, baseDistance).xz, weights);
				float cd = dot(averageSample(_MainTex, cduv, baseDistance).xz, weights);

				// calculate the difference (approximation of a partial derivative) across the x and y axis to generate a normal vector
				float2 diff = float2(ca - cb, cc - cd);
				float4 c = float4(normalize(float3(diff.x, 1, diff.y)), 1);

				// calculate the clipping depth for the raymarching process. Again, not my own calculation.
				clipPos = mul(UNITY_MATRIX_VP, float4(p, 1.0));
				clipDepth = clipPos.z/clipPos.w;


				//// uncommentting this will help with performance, but you need to comment the next few lines and it will result in
				//// some weird mirror and grabpass artifacts very near the surface.
				//float4 refl0 = i.refl_screenpos;
				//float4 grab0 = i.grab_screenpos;


				// Recomment this iff you uncommented the above two lines. Calculate the screen positions of the grabpass and reflections after
				// taking the raymarching process into account. 
				float4 refl0 = ComputeNonStereoScreenPos(UnityObjectToClipPos(mul(unity_WorldToObject, float4(p,1))));
				float4 grab0 = ComputeGrabScreenPos(UnityObjectToClipPos(mul(unity_WorldToObject, float4(p,1))));

				

				// Do the same thing above with the mirror except with the grabpass. Slightly different calculation, also still not accurate. 
				// But it gets the job done and creates some kind of illusion of distortion.
				

				float2 offset = float2(dot(c, i.screen_space_right), dot(c, i.screen_space_up)) * _Distortion / _ScreenParams.y;
				float4 grabpass = tex2Dproj(_GrabTextureWorld, grab0 + float4(offset, 0,0));
				//float2 offset = sqrt(float2(0, 1 - c.y)) * _Distortion / _ScreenParams.y;

				
				// sample the reflection for the mirror. Note that we subtract a depth from the vertical component of the mirror to accomplish the
				
				// distortion effect. Not particularly accurate, but hey, it works. Feel free to modify if you want.
				//float4 reflection = float4(refl0.xzw, refl0.y - dot(c.xz, normalize(refl0.xz))*refl0.y*_ReflectionScale/ _ScreenParams.y).xwyz;
				float4 reflection = refl0 + float4(offset,0,0)*_ReflectionScale / _ScreenParams.y;
				float4 refl = unity_StereoEyeIndex == 0 ? tex2Dproj(_ReflectionTex0, UNITY_PROJ_COORD(reflection)) : tex2Dproj(_ReflectionTex1, UNITY_PROJ_COORD(reflection));


				// collect all the parameters for the rendering set up. The alpha calculation results in more reflectivity when viewing the surface
				// from an angle, and could probably use some fine tuning, but again, it works.
				// We fake ambient occlusion by making portions of the water that are lower darker. Probably not physically accurate, but I've 
				// collected all the parameters here if you want to make some tweaks to the actual rendering. PBR is not my field of experience.
				float alpha = (_AlphaBase) + _Alpha*(1-_AlphaBase)*(1-abs(dot(c, ray)));
				float brightness = pixel;
				float steps = j / maxStep;
				float matte = _Matte;
				//float ao = (1-_AO) + _AO*(clamp((p_height - center.y + 0.5*dim.y) / dim.y, 0, 0.5)) * 2;
				float ao = (1 - _AO) + _AO * (dot(light, c));

				// Collect all the sampled color as rgb vectors. We are using the grabpass for distortion, so we may as well use it
				// for transparency as well, hence why blend alpha is not on.
				float3 mirror_rgb = refl.rgb;
				float3 grab_rgb = grabpass.rgb;
				float3 cubemap_rgb = texCUBE(_Cubemap, reflect(ray, c.xyz)).rgb;
				float3 color_rgb = _Color.rgb;
				float3 ao_rgb = _AO_Tint;
				
				// initially, I wanted to store the weights in a vector to make it normalizable, but it turns out you dont want it
				// normalized, so we'll just pick our weights carefully.
				float4 color_weights = float4
											(
												alpha * (1 - matte)  * ao,	// mirror weight
												(1-alpha),					// grabpass
												(1-ao),						// ambient occlusion
												alpha * matte * ao			// color weight.
											);

				// apply the weights to interpolate between the various colors we sampled.
				float3 rgb_color = (mirror_rgb	* color_weights.x +
									grab_rgb	* color_weights.y + 
									ao_rgb		* color_weights.z +
									color_rgb	* color_weights.w);

				//	multiply by the brightness we calculated.
				float4 return_color = float4(rgb_color * brightness,1);

				// Finally assign the color and depth to the fragOut structure. 
				f.color = return_color;
				f.depth = clipDepth;

				// Aaaand we're done. Only took 460 lines including comments. Raymarched water surface with mirror and grabpass
				// support. That was some fun stuff.
				return f;
			}
			ENDCG
		}
	}
}
