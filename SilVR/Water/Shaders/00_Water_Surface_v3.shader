  Shader "SilVR/Water Surface v3" {
    Properties {
	  _MainTex("Texure", 2D) = "white" {}
	  _Color("Color", Color) = (0,0,0,0)

      _BumpMap ("Render Plane (RenderTexture)", 2D) = "bump" {}
      _Cube ("Cubemap", CUBE) = "" {}
	  _TrueNorm("True Normal (1=enabled)", Range(0,1)) = 0

	  _imgWidth("image width", float) = 720
	  _imgHeight("image height", float) = 720
	  _WaveSpeed("Check distance", float) = 1

	  _Alpha("Alpha", Range(0,1)) = 1
	  _AlphaMask("Transparency Mask", 2D) = "White" {}
	  _AlphaWeight("Alpha Mask Weight", Range(0,1)) = 1

    }
    SubShader {
      Tags {"Queue" = "Transparent" "RenderType" = "Transparent" }
      CGPROGRAM
      #pragma surface surf Lambert alpha
      struct Input {

          float2 uv_BumpMap;
          float3 worldRefl;
          INTERNAL_DATA
      };

	  sampler2D _MainTex;
	  float4 _Color;

      sampler2D _BumpMap;
	  sampler2D _AlphaMask;
      samplerCUBE _Cube;
	  
	  float _TrueNorm;

	  float _imgWidth;
	  float _imgHeight;
	  float _WaveSpeed;

	  float _Alpha;
	  float _AlphaWeight;

	  bool isOrthographic()
	  {
		  return UNITY_MATRIX_P[3][3] == 1;
	  }

	  //float _Aspect;
      void surf (Input IN, inout SurfaceOutput o) {

		  // initialize the albedo to the zero vector.
		  o.Albedo = tex2D(_MainTex, IN.uv_BumpMap)*_Color;

		  // sample a color from the bump map (the render plane)
		  fixed4 col = tex2D(_BumpMap, IN.uv_BumpMap);

		  // determine the distance to check outwards when generating a normal map.
		  float3 q = float3(1 / _imgWidth * _WaveSpeed, 1 / _imgHeight * _WaveSpeed, 0);

		  // generate the coordinates for checking outward when generating a normal map
		  float2 uv = float2(IN.uv_BumpMap.x, IN.uv_BumpMap.y);
		  float2 cauv = uv + q.zy;
		  float2 cbuv = uv - q.zy;
		  float2 ccuv = uv + q.xz;
		  float2 cduv = uv - q.xz;

		  // sample the current height for literally no reason
		  float d = tex2D(_BumpMap, uv).x;

		  // sample the renderplane as a height map at outward points to generate a normal map
		  float2 weights = float2(0.5, 0.5);

		  float ca = dot(tex2D(_BumpMap, cauv).xy, weights);
		  float cb = dot(tex2D(_BumpMap, cbuv).xy, weights);
		  float cc = dot(tex2D(_BumpMap, ccuv).xy, weights);
		  float cd = dot(tex2D(_BumpMap, cduv).xy, weights);

		  // calculate the difference (approximation of a partial derivative) across the x and y axis to generate a normal vector
		  float2 diff = float2(ca - cb, cc - cd);
		  float4 c = float4(diff, 1, 1);

		  // determine whether we want to use true normals, or an old incorrect form (I still use the
		  // incorrect form for the bottom of the water.
		  o.Normal = ((1 - _TrueNorm) * tex2D(_BumpMap, uv) + _TrueNorm * c);

		  // Set the alpha transparency of the pixel based on the alpha mask. Useful for irregular shaped pools and
		  // places where you dont want the water bleeding outward.
		  o.Alpha = _Alpha*(1-_AlphaWeight) + tex2D(_AlphaMask, IN.uv_BumpMap).x*_AlphaWeight*_Alpha;
		  
		  // Sample the cubemap for the water surface reflection.
		  o.Emission = texCUBE (_Cube, WorldReflectionVector (IN, o.Normal)).rgb;

      }
      ENDCG
    } 
    Fallback "Diffuse"
  }