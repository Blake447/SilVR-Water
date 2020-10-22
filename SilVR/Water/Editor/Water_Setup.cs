using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

#if UNITY_EDITOR
namespace SilVR
{

    class Water_Setup : EditorWindow
    {
        GameObject RefPlane;
        Cubemap cubemap;
    
        //GameObject TargetPlane;

        GameObject RigRoot;
        GameObject RigWaterSurface;
        GameObject RigRenderPlane;
        Camera SurfaceCamera;
        Camera RenderCamera;
        RenderTexture CameraInput;
        RenderTexture Propegation;

        GameObject RigWaterSurfaceL;
        GameObject RigRenderPlaneL;
        Camera SurfaceCameraL;
        Camera RenderCameraL;
        RenderTexture CameraInputL;
        RenderTexture PropegationL;

        int mat_count = 7;
        Material[] mats;


        Vector2 scrollPos = new Vector2(0, 0);
        int Image_Width = 0;
        int Image_Height = 0;
        int PixelsPerMeter = 144;
        bool show_help = false;
        bool lite_qual = false;

        [MenuItem("SilVR/Water Setup")]

        public static void ShowWindow()
        {
            EditorWindow.GetWindow(typeof(Water_Setup));
        }

        private void OnEnable()
        {
            FillWithDefaults();
        }

        void OnGUI()
        {



            //this.minSize = new Vector2(350, 540);
            GUILayout.BeginVertical();
            show_help = EditorGUILayout.Toggle("show help", show_help);
            lite_qual = EditorGUILayout.Toggle("Lite quality", lite_qual);

            GUILayout.Label("Quick Setup", EditorStyles.boldLabel);

            scrollPos = GUILayout.BeginScrollView(scrollPos, false, true, GUILayout.MinHeight(200), GUILayout.MaxHeight(1000), GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(true));
            HelpMessage("The default settings button tries to find all the required items by name. It will not find items you have made yourself, renamed, or that aren't yet in the scene. If you renamed the water rig, assign it to the water rig root field and it wil use that to find the items instead. It also does not look for the reference plane or cubemap, so you have to assign those yourself");
            if (GUILayout.Button("Default Settings", "Button"))
            {
                FillWithDefaults();
            }


            //this.maxSize = new Vector2(350, 540);
            GUILayout.Label("Reference objects and values", EditorStyles.boldLabel);
            HelpMessage("Take a standard unity plane and place it and resize it to where you want your water. Then drag it from the inspector to the field labeled 'reference plane'");
            PixelsPerMeter = EditorGUILayout.IntField("Pixels per meter", PixelsPerMeter);

            RefPlane = (GameObject)EditorGUILayout.ObjectField("Reference Plane", RefPlane, typeof(GameObject), true);
            if (RefPlane)
            {
                PreviewResolution();
            }

            EditorGUILayout.HelpBox("Calculated Resolution: (" + Image_Width + ", " + Image_Height + ")", MessageType.None);

            GUILayout.Label("Cubemap", EditorStyles.boldLabel);
            HelpMessage("This should be your cubemap you use for whatever skybox. If you use a six sided layout or procedural, you have to find a way to convert to cubemap.");
            cubemap = (Cubemap)EditorGUILayout.ObjectField("Cubemap (For Skybox)", cubemap, typeof(Cubemap), false);

            string quality = "D";

            GUILayout.Label("Target objects (From Prefab)", EditorStyles.boldLabel);
            HelpMessage("Drop the prefab into the world and find the Gameobjects that match the name in the fields below");
            RigRoot = (GameObject)EditorGUILayout.ObjectField("Water Rig 3.0", RigRoot, typeof(GameObject), true);
            RigWaterSurface = (GameObject)EditorGUILayout.ObjectField(quality + "_Surface", RigWaterSurface, typeof(GameObject), true);
            RigRenderPlane = (GameObject)EditorGUILayout.ObjectField(quality + "_Render_Plane_q", RigRenderPlane, typeof(GameObject), true);
            SurfaceCamera = (Camera)EditorGUILayout.ObjectField(quality + "_Cam_In", SurfaceCamera, typeof(Camera), true);
            RenderCamera = (Camera)EditorGUILayout.ObjectField(quality + "_Render_Cam", RenderCamera, typeof(Camera), true);
            if (lite_qual)
            {
                quality = "L";
                RigWaterSurfaceL = (GameObject)EditorGUILayout.ObjectField(quality + "_Surface", RigWaterSurfaceL, typeof(GameObject), true);
                RigRenderPlaneL = (GameObject)EditorGUILayout.ObjectField(quality + "_Render_Plane_q", RigRenderPlaneL, typeof(GameObject), true);
                SurfaceCameraL = (Camera)EditorGUILayout.ObjectField(quality + "_Cam_In", SurfaceCameraL, typeof(Camera), true);
                RenderCameraL = (Camera)EditorGUILayout.ObjectField(quality + "_Render_Cam", RenderCameraL, typeof(Camera), true);
            }



            //CameraInput = (RenderTexture)EditorGUILayout.ObjectField("DRT_Cam_In", CameraInput, typeof(RenderTexture), false);
            //Propegation = (RenderTexture)EditorGUILayout.ObjectField("DRT_Render_Cam", Propegation, typeof(RenderTexture), false);
            GUILayout.Label("Materials (Order doesn't matter)", EditorStyles.boldLabel);
            HelpMessage("These are slots to change the settings on some of the materials in the project. The order doesnt matter. For the default quality, just drag every material in Assets > SilVR > Materials > Default. For lite quality, do so in Assets > SilVR > Materials > Lite.");

            Material [] mats_temp = new Material[mats.Length];
            if (mats.Length > 0)
            {
                for (int i = 0; i < mats.Length && i < mats_temp.Length; i++)
                {
                    mats_temp[i] = mats[i];
                }

            }

            mat_count = EditorGUILayout.IntField("Materials in folder(s)", mat_count);
            mats = new Material[mat_count];

            //Material[] mats_temp = new Material[mats.Length];
            if (mats_temp.Length > 0)
            {

                for (int i = 0; i < mats.Length && i < mats_temp.Length; i++)
                {
                    mats[i] = mats_temp[i];
                }
            }

                for (int i = 0; i < mat_count; i++)
            {
                mats[i] = (Material)EditorGUILayout.ObjectField("Material", mats[i], typeof(Material), false);
            }

            if (GUILayout.Button("Refresh Materials", "Button"))
            {
                FillMaterials();
            }

            if (GUILayout.Button("Set up rig", "Button" ))
            {
                Button();
            }




            GUILayout.EndScrollView();
            GUILayout.EndVertical();
        }

        void PreviewResolution()
        {
            Vector3 RefScale = RefPlane.transform.localScale * 5;
            int WidthInPixels = (int)(RefScale.x * PixelsPerMeter + 0.5);
            int HeightInPixels = (int)(RefScale.z * PixelsPerMeter + 0.5);
            Image_Width = WidthInPixels;
            Image_Height = HeightInPixels;
        }

        void Button()
        {
            Debug.Log("The button has been pressed");
            if(RefPlane)
            {
                CameraInput = SurfaceCamera.targetTexture;
                Propegation = RenderCamera.targetTexture;

                Vector3 RefScale = RefPlane.transform.localScale * 5;
                Vector3 RefPos = RefPlane.transform.position;
                Quaternion RefRot = RefPlane.transform.rotation;

                RigRoot.transform.position = RefPos;
                RigRoot.transform.rotation = RefRot;

                RigWaterSurface.transform.localPosition = Vector3.zero;


                int WidthInPixels = (int)(RefScale.x * PixelsPerMeter + 0.5);
                int HeightInPixels = (int)(RefScale.z * PixelsPerMeter + 0.5);

                //Debug.Log("Set the rendertextures to" + WidthInPixels + "x" + HeightInPixels);
                //Debug.Log("No I can't do it for you, it appearently 'isnt supported' whatever that means");

                Vector3 newLocalScale = new Vector3((float)WidthInPixels / PixelsPerMeter, 1, (float)HeightInPixels / PixelsPerMeter);

                RigWaterSurface.transform.localScale = newLocalScale;
                RigRenderPlane.transform.localScale = newLocalScale;

                SurfaceCamera.orthographicSize = newLocalScale.z;
                RenderCamera.orthographicSize = newLocalScale.z;

                CameraInput.Release();
                CameraInput.width = WidthInPixels;
                CameraInput.height = HeightInPixels;
                CameraInput.Create();

                Propegation.Release();
                Propegation.width = WidthInPixels;
                Propegation.height = HeightInPixels;
                Propegation.Create();

                if (lite_qual)
                {
                    CameraInputL = SurfaceCameraL.targetTexture;
                    PropegationL = RenderCameraL.targetTexture;

                    RigWaterSurfaceL.transform.localPosition = Vector3.zero;

                    RigWaterSurfaceL.transform.localScale = newLocalScale;
                    RigRenderPlaneL.transform.localScale = newLocalScale;

                    SurfaceCameraL.orthographicSize = newLocalScale.z;
                    RenderCameraL.orthographicSize = newLocalScale.z;

                    CameraInputL.Release();
                    CameraInputL.width = WidthInPixels;
                    CameraInputL.height = HeightInPixels;
                    CameraInputL.Create();

                    PropegationL.Release();
                    PropegationL.width = WidthInPixels;
                    PropegationL.height = HeightInPixels;
                    PropegationL.Create();
                }


                for (int i = 0; i < mats.Length; i++)
                {
                    SetMaterial(mats[i], WidthInPixels, HeightInPixels);
                }

                RefPlane.SetActive(false);

                RigRoot.gameObject.SetActive(false);
                RigRoot.gameObject.SetActive(true);
            }


            else
            {
                Debug.Log("Something has not been assigned, check to ensure all objects have been assigned");
            }
        }

        void HelpMessage(string output)
        {
            if (show_help)
            {
                EditorGUILayout.HelpBox(output, MessageType.Info);
            }
        }

        void SetMaterial(Material mat, int WidthInPixels, int HeightInPixels)
        {
            if (mat)
            {
                if (mat.HasProperty("_ImgWidth"))
                {
                    mat.SetInt("_ImgWidth", WidthInPixels);
                }
                if (mat.HasProperty("_imgWidth"))
                {
                    mat.SetInt("_imgWidth", WidthInPixels);
                }
                if (mat.HasProperty("_ImgHeight"))
                {
                    mat.SetInt("_ImgHeight", HeightInPixels);
                }
                if (mat.HasProperty("_imgHeight"))
                {
                    mat.SetInt("_imgHeight", HeightInPixels);
                }
                if (mat.HasProperty("_Cube"))
                {
                    mat.SetTexture("_Cube", cubemap);
                }
                if (mat.HasProperty("_Cubemap"))
                {
                    mat.SetTexture("_Cubemap", cubemap);
                }
            }
        }

       void FillWithDefaults()
        {
            lite_qual = true;
            PixelsPerMeter = 144;
            if (!RigRoot)
            {
                RigRoot = GameObject.Find("water_rig_3.0");
            }

            if (RigRoot)
            {
                Transform[] trans = RigRoot.GetComponentsInChildren<Transform>(true);
                foreach (Transform t in trans)
                {
                    if (t.gameObject.name == "D_Surface")
                    {
                        RigWaterSurface = t.gameObject;
                    }
                    if (t.gameObject.name == "D_Render_Plane_q")
                    {
                        RigRenderPlane = t.gameObject;
                    }
                    if (t.gameObject.name == "D_Cam_In")
                    {
                        SurfaceCamera = t.gameObject.GetComponent<Camera>();
                    }
                    if (t.gameObject.name == "D_Render_Cam")
                    {
                        RenderCamera = t.gameObject.GetComponent<Camera>();
                    }
                    if (t.gameObject.name == "L_Surface")
                    {
                        RigWaterSurfaceL = t.gameObject;
                    }
                    if (t.gameObject.name == "L_Render_Plane_q")
                    {
                        RigRenderPlaneL = t.gameObject;
                    }
                    if (t.gameObject.name == "L_Cam_In")
                    {
                        SurfaceCameraL = t.gameObject.GetComponent<Camera>();
                    }
                    if (t.gameObject.name == "L_Render_Cam")
                    {
                        RenderCameraL = t.gameObject.GetComponent<Camera>();
                    }
                }
            }
            else
            {
                Debug.LogWarning("Could not find the water rig root, you may have to assign it yourself and try again");
            }


            cubemap = (Cubemap)AssetDatabase.LoadAssetAtPath("Assets/Skybox/sky.jpg", typeof(Cubemap));

            FillMaterials();

        }
        void FillMaterials()
        {
            if (mat_count < 17)
            {
                mat_count = 17;
            }

            mats = new Material[mat_count];
            mats[0] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/DM_Bottom.mat", typeof(Material));
            mats[1] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/DM_Distortion.mat", typeof(Material));
            mats[2] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/DM_Flat_Mirror.mat", typeof(Material));
            mats[3] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/DM_Raymarched.mat", typeof(Material));
            mats[4] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/DM_Reflective_Raymarched.mat", typeof(Material));
            mats[5] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/DM_Render_Plane.mat", typeof(Material));
            mats[6] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/DM_Top.mat", typeof(Material));
            mats[7] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Lite/LM_Bottom.mat", typeof(Material));
            mats[8] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Lite/LM_Distortion.mat", typeof(Material));
            mats[9] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Lite/LM_Flat_Mirror.mat", typeof(Material));
            mats[10] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Lite/LM_Render_Plane.mat", typeof(Material));
            mats[11] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Lite/LM_Top.mat", typeof(Material));
            mats[12] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/Presets/Classic.mat", typeof(Material));
            mats[13] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/Presets/Clear.mat", typeof(Material));
            mats[14] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/Presets/Dir-Alpha.mat", typeof(Material));
            mats[15] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/Presets/Matte.mat", typeof(Material));
            mats[16] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/Presets/WaterColor.mat", typeof(Material));

            for (int i = 0; i < mat_count; i++)
            {
                if (!mats[i])
                {
                    Debug.Log("I had trouble finding some materials. If you renamed some then you might need to add them manually");
                }
            }
        }

    }



}
#endif