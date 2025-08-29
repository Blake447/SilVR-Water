Shader "SilVR Experimental/Water Surface v3 Standard Spec" {
  Properties {
    _BumpMap ("Render Plane (RenderTexture)", 2D) = "bump" {}
    _Cube ("Cubemap (non specular)", CUBE) = "" {}
    _CubeTint("Cubemap Tint", Color) = (1,1,1,1) 
    _WaveSpeed("Wave Speed", float) = 1
    _Alpha("Alpha Top", Range(0,1)) = 1
    _AlphaBack("Alpha Bottom", Range(0,1)) = 1

    _AlphaMask("Transparency Mask", 2D) = "White" {}
    _SpecularColor("Specular Color (Reflection Probes)", Color) = (0,0,0,0)
    //_Smoothness("Smoothness", Range(0,1)) = 1
    //_Power("Power", float) = 1
    //_Threshold("Threshold", Range(0,1)) = 0

    _RefractionDistance("Refraction distance", float) = 0.1
  }
  SubShader {

    GrabPass
    {
        "_SilVRGrabPass"
    }

    Tags {"Queue" = "Transparent" "RenderType" = "Transparent" }
    Cull Off
    CGPROGRAM
    #pragma surface surf StandardSpecular alpha
    #pragma target 4.0
    struct Input {
      //float2 uv_MainTex;
      float2 uv_BumpMap;
      float3 worldRefl;
      float3 worldPos;
      float vface : VFACE;
      INTERNAL_DATA
    };
    //sampler2D _MainTex;
    sampler2D _BumpMap;
    //amplerCUBE unity_SpecCube0;
    float4 _BumpMap_TexelSize;
    sampler2D _AlphaMask;
    samplerCUBE _Cube;
    sampler2D _SilVRGrabPass;

    float _imgRes;

    float _WaveSpeed;

    float _TrueNorm;
    float _Alpha;
    float _AlphaBack;
    float _Power;
    float _Threshold;

    float4 _CubeTint;

    float _Smoothness;
    float4 _SpecularColor;

    float _RefractionDistance;
    float4 _ColorAbsorbed;
    float _ColorAbsorbance;

    bool isOrthographic()
    {
      return UNITY_MATRIX_P[3][3] == 1;
    }

    //float _Aspect;
    void surf (Input IN, inout SurfaceOutputStandardSpecular o) {

      // Get the camera in to avoid seeing the water surface. This is actually a bad idea, and they
      // should be set up to avoid one another by layering, because this adds a significant strain on the
      // water rig. This will however be left in as a fail safe.
      if (isOrthographic())
      {
        clip(-1);
      }

      // initialize the albedo to the zero vector.
      o.Albedo = fixed4(0, 0, 0, 0);

      // sample a color from the bump map (the render plane)
      fixed4 col = tex2D(_BumpMap, IN.uv_BumpMap);

      // determine the distance to check outwards when generating a normal map.
      float3 q = float3(_BumpMap_TexelSize.xy * _WaveSpeed, 0);

      // generate the coordinates for checking outward when generating a normal map
      float2 uv = float2(IN.uv_BumpMap.x, IN.uv_BumpMap.y);
      float2 cauv = uv + q.zy;
      float2 cbuv = uv - q.zy;
      float2 ccuv = uv + q.xz;
      float2 cduv = uv - q.xz;

      // sample the current height for literally no reason
      float d = tex2D(_BumpMap, uv).x;

      // sample the renderplane as a height map at outward points to generate a normal map
      float2 weights = float2(1, -1);

      float ca = dot(tex2D(_BumpMap, cauv).xz, weights);
      float cb = dot(tex2D(_BumpMap, cbuv).xz, weights);
      float cc = dot(tex2D(_BumpMap, ccuv).xz, weights);
      float cd = dot(tex2D(_BumpMap, cduv).xz, weights);

      // calculate the difference (approximation of a partial derivative) across the x and y axis to generate a normal vector
      float2 diff = float2(ca - cb, cc - cd);
      float4 c = float4(diff, 1, 1);


      float3 normal = normalize(mul((float3x3)unity_ObjectToWorld, c));
      float3 viewDir = normalize(IN.worldPos - _WorldSpaceCameraPos);
      float3 reflDir = reflect(viewDir, normal);
      float3 refrDir = refract(viewDir, -normal, .8);
      float3 refrPos = IN.worldPos + refrDir * _RefractionDistance * dot(normal, float3(0,1,0));

      float4 refrScreenPos = ComputeScreenPos( mul( UNITY_MATRIX_VP, float4(refrPos, 1) ) );
      float2 refrUV = refrScreenPos.xy / refrScreenPos.w;

      float3 refrTrace = IN.worldPos + (refrDir / refrDir.y);
      float lenTrace = length(refrDir / refrDir.y);

      //float3 reflection = texCUBE(_Skybox, reflDir);
      float3 refraction = tex2D(_SilVRGrabPass, refrUV);

      // determine whether we want to use true normals, or an old incorrect form (I still use the
      // incorrect form for the bottom of the water.
      o.Normal = c;

      // Set the alpha transparency of the pixel based on the alpha mask. Useful for irregular shaped pools and
      // places where you dont want the water bleeding outward.
      float alpha = lerp(_AlphaBack, _Alpha, saturate(IN.vface));
      o.Alpha = min(alpha, tex2D(_AlphaMask, IN.uv_BumpMap));
      //o.Alpha = 1;

      // Sample the cubemap for the water surface reflection.
      //o.Emission = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, WorldReflectionVector (IN, o.Normal), 0);
      o.Emission = lerp(refraction, texCUBE (_Cube, WorldReflectionVector (IN, o.Normal)).rgb * _CubeTint, alpha);
      o.Alpha = 1;
      //o.Emission = saturate(IN.vface);
      //o.Emission = refraction;

      o.Specular = _SpecularColor*alpha;
      o.Smoothness = 1;

    }
    ENDCG
  } 
  Fallback "Diffuse"
}