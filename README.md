# SilVR-Water
Interactive Water Rig for VRChat and Unity

# Overview
This is a camera based interactive water solution for VRChat, utiliizing modified VRC_Mirror shaders and rendertextures. The project should include two prefabs, a model, several shaders, and several materials. The prefab is seperated into three parts, a surface, a propegation rig, and a group of legacy components (mainly used for quick testing of normal map implementation into other shaders before actually hardcoding it in.) The Surface takes care of the interaction, and the propegation rig takes care of the rippling effect, utilizing an algortithm refered to as the hugo-elias wave propegation algorithm.

# Key Terms

There are several key terms I will typically use in describing the water rig. The first is the Render Plane.

Render Plane - The plane toward the bottom of the rig that propegates the ripple algorithm.

The Render Camera - The camera lined up with the render plane.

The Render Plane material - Refers to the material that links the camera and the render plane. The cameras input is stored as a render texture, passed to the render plane material, displayed on the render plane, which is then seen by the camera, resulting in a constant feedback loop. This is ultimately what drives the ripple propegation.

# Surface (Default quality)

D_Cam_In - The previously mentioned camera with a rendertexture. This camera feeds in any player activity and passes it into the render plane material.  

D_Top and D_Bottom - The two water surface planes with just cubemap support.

D_Distortion - The water surface plane in charge of handling distortion.

D_Reflective_Raymarched - This is the fun one. This is a quad that is being used to raymarch the water surface, and also uses a modified mirror material. 

D_Raymarched - Same as above, except without the VRC_Mirror component. It samples the cubemap instead.

# Water Surface Materials

DM_Bottom and DM_Top - The two materials that correspond to the D_Top and D_Bottom planes. It requires the render plane's rendertexture as an input to calculate the normal map, and a cubemap to sample from. The normal map calculation is modified by image width, image height, and wave speed (basically, how many pixels out from the current pixel to check). It also supports a transparency mask where any white on the texture will be viewed as a section where there should be water.

DM_Distortion - requires the render planes rendertexture as input. Also has entries for image height and width, as well as a wave size modifier that works as the above wave speed.

DM_Flat_Mirror - A modified VRC mirror texture that supports transparency, color tint, and transparency masking like the above material. No distortion or normals as the distortion texture handles it.

DM_Raymarched - The raymarched surface material. Requires the render planes rendertexture, and a cubemap to sample from. Directional alpha is a slider that refers to how much the viewing angle affects the transparency of the water, and alpha baseline determines the minimum transparency allowed. Matte interpolates between the color tint and the reflection. The Fake Ambient occlusion darkens the waves based on their height, and can be tinted. The Distortion and Reflection Scale parameters are self explanatory. The image width and height are used for built in normal calculations. For performance reasons, the light direction is specified with sliders as opposed to using a directional light. The Light Step length determines how far the raymarched shadow cast steps each time, and the light density determines how much each step found to be under the waters surface darkens the wave.

DM_Reflective_Raymarched - same as immediately above, but it uses the VRC_Mirror component instead of a cubemap to sample from.

# Propegation Rig (Default quality)

D_Render_Plane_q - A render plane that consists of a quad. Used for simpler scaling and set up.

D_Render_Cam - The render camera corresponding to the above plane.

D_Render_Plane - an obselete component. Identical to the D_Render_Plane_q except its a plane not a quad, and it doesnt have a collider.

# Propegation Rig

# Legacy Components (Default quality)

Honestly, just ignore these. Its better to hardcode the normal map support into another shader.
