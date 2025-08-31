using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Assertions.Must;

#if UNITY_EDITOR
namespace SilVR
{

    public class Water_Setup : EditorWindow
    {
        GameObject RefPlane;
        Cubemap cubemap;

        //GameObject TargetPlane;

        GameObject RigRoot;
        GameObject RigWaterSurface;
        Camera SurfaceCamera;
        RenderTexture CameraInput;
        CustomRenderTexture PropagationCRT;

        GameObject RigWaterSurfaceL;
        Camera SurfaceCameraL;
        RenderTexture CameraInputL;
        CustomRenderTexture PropagationLCRT;

        int mat_count = 7;
        Material[] mats;

		string field = "default";

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


			GUILayout.Space(12);
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

			GUILayout.Space(12);
			GUILayout.Label("Detected Prefabs", EditorStyles.boldLabel);
            List <GameObject> prefabs = new List<GameObject>();
            GameObject[] taggedObjects = GameObject.FindGameObjectsWithTag("silvr");
            if (taggedObjects != null)
            {
                for (int i = 0; i < taggedObjects.Length; i++)
                {
                    bool isValidPrefab = IsValidPrefab(taggedObjects[i]);
                    if (isValidPrefab)
                    {
                        prefabs.Add(taggedObjects[i]);
                    }
                }
            }
            if (prefabs.Count == 0)
            {

            }
            else
            {
                for (int i = 0; i < prefabs.Count; i++)
                {
                    if (GUILayout.Button(prefabs[i].name, "Button"))
                    {
                        EditorGUIUtility.PingObject(prefabs[i]);
                    }
                }
            }
            GUILayout.Space(12);

            GUILayout.Label("Generate New Assets");

            GUILayout.Space(6);
            GUILayout.Label("Asset pack name");
            field = GUILayout.TextField(field);
            field = System.Text.RegularExpressions.Regex.Replace(field, @"[^a-zA-Z -]", "");
            field = field.Replace(" ", "-");
            GUILayout.Space(6);

            HelpMessage("Drop the prefab into the world and find the Gameobjects that match the name in the fields below");
            //RigRoot = (GameObject)EditorGUILayout.ObjectField("Water Rig 3.0", RigRoot, typeof(GameObject), true);

			GUILayout.Space(12);

            Material surfaceMat = null;
            Material renderMat = null;
            Material normalMat = null;

            CustomRenderTexture normalCRT = null;
            CustomRenderTexture renderCRT = null;
            RenderTexture cameraInRT = null;

            //Debug.Log("Outputting to " + outPath);
            //Debug.Log(DM_N_PATH);

            if (GUILayout.Button("Generate", "Button"))
            {
				string DM_TOP_PATH = "";
				string DM_RP_PATH = "";
				string DM_N_PATH = "";
				string DCRT_N_PATH = "";
				string DCRT_RP_PATH = "";
				string DRT_CAM_IN_PATH = "";

				string outPath = "";

				string[] pathsToSearch = AssetDatabase.FindAssets("t:Folder SilVR");
				if (pathsToSearch != null)
				{

					for (int i = 0; i < pathsToSearch.Length; i++)
					{
						if (System.IO.Directory.Exists(AssetDatabase.GUIDToAssetPath(pathsToSearch[i]) + "/Water/Generated"))
						{
							outPath = AssetDatabase.GUIDToAssetPath(pathsToSearch[i]) + "/Water/Generated";
						}
						if (System.IO.Directory.Exists(AssetDatabase.GUIDToAssetPath(pathsToSearch[i]) + "/Water"))
						{
							string pathName = AssetDatabase.GUIDToAssetPath(pathsToSearch[i]);
							if (System.IO.File.Exists(pathName + "/Water/Templates/Default/DM_Top.mat"))
							{
								DM_TOP_PATH = pathName + "/Water/Templates/Default/DM_Top.mat";
							}
							if (System.IO.File.Exists(pathName + "/Water/Templates/Default/DM_RP.mat"))
							{
								DM_RP_PATH = pathName + "/Water/Templates/Default/DM_RP.mat";
							}
							if (System.IO.File.Exists(pathName + "/Water/Templates/Default/DM_N.mat"))
							{
								DM_N_PATH = pathName + "/Water/Templates/Default/DM_N.mat";
							}
							if (System.IO.File.Exists(pathName + "/Water/Templates/Default/DCRT_N.asset"))
							{
								DCRT_N_PATH = pathName + "/Water/Templates/Default/DCRT_N.asset";
							}
							if (System.IO.File.Exists(pathName + "/Water/Templates/Default/DCRT_RP.asset"))
							{
								DCRT_RP_PATH = pathName + "/Water/Templates/Default/DCRT_RP.asset";
							}
							if (System.IO.File.Exists(pathName + "/Water/Templates/Default/DRT_Cam_In.renderTexture"))
							{
								DRT_CAM_IN_PATH = pathName + "/Water/Templates/Default/DRT_Cam_In.renderTexture";
							}
						}
					}
				}

                if (field == "") field = "default";

				if (outPath != "")
                {
                    System.IO.Directory.CreateDirectory(outPath + "/" + field);
                    if (DM_TOP_PATH != "")
                    {
                        string assetPath = outPath + "/" + field + "/" + field + "-DM-TOP.mat";
						AssetDatabase.CopyAsset(DM_TOP_PATH, assetPath);
                        Debug.Log("Copied template top to " + assetPath);
                        surfaceMat = (Material)AssetDatabase.LoadAssetAtPath(assetPath, typeof(Material));
                    }
                    else
                    {
                        Debug.LogError("Couldnt find surface material template");
                    }
					if (DM_N_PATH != "")
					{
						string assetPath = outPath + "/" + field + "/" + field + "-DM-N.mat";
						AssetDatabase.CopyAsset(DM_N_PATH, assetPath);
						Debug.Log("Copied template top to " + assetPath);
						normalMat = (Material)AssetDatabase.LoadAssetAtPath(assetPath, typeof(Material));

					}
					else
					{
						Debug.LogError("Couldnt find normal material template");
					}
					if (DM_RP_PATH != "")
					{
						string assetPath = outPath + "/" + field + "/" + field + "-DM-RP.mat";
						AssetDatabase.CopyAsset(DM_RP_PATH, assetPath);
						Debug.Log("Copied template top to " + assetPath);
						renderMat = (Material)AssetDatabase.LoadAssetAtPath(assetPath, typeof(Material));
					}
					else
					{
						Debug.LogError("Couldnt find render material template");
					}
					if (DCRT_RP_PATH != "")
					{
						string assetPath = outPath + "/" + field + "/" + field + "-DCRT-RP.asset";
						AssetDatabase.CopyAsset(DCRT_RP_PATH, assetPath);
						Debug.Log("Copied template top to " + assetPath);
						renderCRT = (CustomRenderTexture)AssetDatabase.LoadAssetAtPath(assetPath, typeof(CustomRenderTexture));
					}
					else
					{
						Debug.LogError("Couldnt find render plane CRT template");
					}
					if (DCRT_N_PATH != "")
					{
						string assetPath = outPath + "/" + field + "/" + field + "-DCRT-N.asset";
						AssetDatabase.CopyAsset(DCRT_N_PATH, assetPath);
						Debug.Log("Copied template top to " + assetPath);
						normalCRT = (CustomRenderTexture)AssetDatabase.LoadAssetAtPath(assetPath, typeof(CustomRenderTexture));
					}
					else
					{
						Debug.LogError("Couldnt find render plane CRT template");
					}
                    if (DRT_CAM_IN_PATH != "")
                    {
						string assetPath = outPath + "/" + field + "/" + field + "-DRT-CI.renderTexture";
						AssetDatabase.CopyAsset(DRT_CAM_IN_PATH, assetPath);
						Debug.Log("Copied template top to " + assetPath);
						cameraInRT = (RenderTexture)AssetDatabase.LoadAssetAtPath(assetPath, typeof(RenderTexture));
					}
                    if (surfaceMat != null) surfaceMat.SetTexture("_BumpMap", renderCRT);
                    if (surfaceMat != null) surfaceMat.SetTexture("_Cube", cubemap);
                    if (normalMat != null) normalMat.SetTexture("_MainTex", renderCRT);
                    if (renderMat != null) renderMat.SetTexture("_CamIn", cameraInRT);


					if (RefPlane && prefabs != null && prefabs.Count > 0 && prefabs[0] != null)
					{
                        GameObject rigRoot = prefabs[0];
                        Camera camera = rigRoot.GetComponentInChildren<Camera>();
                        camera.targetTexture = cameraInRT;

						Vector3 RefScale = RefPlane.transform.localScale * 5;
						Vector3 RefPos = RefPlane.transform.position;
						Quaternion RefRot = RefPlane.transform.rotation;

						rigRoot.transform.position = RefPos;
						rigRoot.transform.rotation = RefRot;

                        GameObject rigWaterSurface = rigRoot.GetComponentInChildren<MeshRenderer>().gameObject.transform.parent.gameObject;
                        MeshRenderer rigWaterSurfaceRender = rigRoot.GetComponentInChildren<MeshRenderer>();
                        rigWaterSurfaceRender.material = surfaceMat;
						rigWaterSurface.transform.localPosition = Vector3.zero;

						int WidthInPixels = (int)(RefScale.x * PixelsPerMeter + 0.5);
						int HeightInPixels = (int)(RefScale.z * PixelsPerMeter + 0.5);

						//Debug.Log("Set the rendertextures to" + WidthInPixels + "x" + HeightInPixels);
						//Debug.Log("No I can't do it for you, it appearently 'isnt supported' whatever that means");

						Vector3 newLocalScale = new Vector3((float)WidthInPixels / PixelsPerMeter, 1, (float)HeightInPixels / PixelsPerMeter);

						rigWaterSurface.transform.localScale = newLocalScale;
                        //rigWaterSurface.transform.localScale = Vector3.Scale(rigWaterSurface.transform.localScale, new Vector3(1, 5, 1));

						camera.orthographicSize = newLocalScale.z;

                        if (normalCRT != null)
                        {
                            normalCRT.Release();
                            normalCRT.width = WidthInPixels;
                            normalCRT.height = HeightInPixels;
                            normalCRT.Create();
                            normalCRT.material = normalMat;
                        }
                        if (renderCRT != null)
                        {
                            renderCRT.Release();
                            renderCRT.width = WidthInPixels;
                            renderCRT.height = HeightInPixels;
                            renderCRT.Create();
                            renderCRT.material = renderMat;
                        }
                        if (cameraInRT != null)
                        {
                            cameraInRT.Release();
                            cameraInRT.width = WidthInPixels;
                            cameraInRT.height = HeightInPixels;
                            cameraInRT.Create();
                        }

						RefPlane.SetActive(false);

						rigRoot.gameObject.SetActive(false);
						rigRoot.gameObject.SetActive(true);
					}
				}
                else
                {
                    Debug.LogError("Couldnt find output path");
                }


            }
		

            GUILayout.EndScrollView();
            GUILayout.EndVertical();
        }

        private void PreviewResolution()
        {
            Vector3 RefScale = RefPlane.transform.localScale * 5;
            int WidthInPixels = (int)(RefScale.x * PixelsPerMeter + 0.5);
            int HeightInPixels = (int)(RefScale.z * PixelsPerMeter + 0.5);
            Image_Width = WidthInPixels;
            Image_Height = HeightInPixels;
        }

        private void Button()
        {
            Debug.Log("The button has been pressed");
            if (RefPlane)
            {
                CameraInput = SurfaceCamera.targetTexture;

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

                SurfaceCamera.orthographicSize = newLocalScale.z;

                CameraInput.Release();
                CameraInput.width = WidthInPixels;
                CameraInput.height = HeightInPixels;
                CameraInput.Create();

                PropagationCRT.Release();
                PropagationCRT.width = WidthInPixels;
                PropagationCRT.height = HeightInPixels;
                PropagationCRT.Create();

                if (lite_qual)
                {
                    CameraInputL = SurfaceCameraL.targetTexture;

                    RigWaterSurfaceL.transform.localPosition = Vector3.zero;

                    RigWaterSurfaceL.transform.localScale = newLocalScale;

                    SurfaceCameraL.orthographicSize = newLocalScale.z;

                    CameraInputL.Release();
                    CameraInputL.width = WidthInPixels;
                    CameraInputL.height = HeightInPixels;
                    CameraInputL.Create();

                    PropagationLCRT.Release();
                    PropagationLCRT.width = WidthInPixels;
                    PropagationLCRT.height = HeightInPixels;
                    PropagationLCRT.Create();
                }


                for (int i = 0; i < mats.Length; i++)
                {
                    SetMaterial(mats[i]);
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
        bool IsValidPrefab(GameObject prefab)
        {
            return true;
        }

        private void HelpMessage(string output)
        {
            if (show_help)
            {
                EditorGUILayout.HelpBox(output, MessageType.Info);
            }
        }

        private void SetMaterial(Material mat)
        {
            if (mat)
            {
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

        private void FillWithDefaults()
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
                    if (t.gameObject.name == "D_Cam_In")
                    {
                        SurfaceCamera = t.gameObject.GetComponent<Camera>();
                    }
                    if (t.gameObject.name == "L_Surface")
                    {
                        RigWaterSurfaceL = t.gameObject;
                    }
                    if (t.gameObject.name == "L_Cam_In")
                    {
                        SurfaceCameraL = t.gameObject.GetComponent<Camera>();
                    }
                }
            }
            else
            {
                Debug.LogWarning("Could not find the water rig root, you may have to assign it yourself and try again");
            }


            cubemap = (Cubemap)AssetDatabase.LoadAssetAtPath("Assets/Skybox/sky.jpg", typeof(Cubemap));
            PropagationCRT = (CustomRenderTexture)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/Wave_CRT.asset", typeof(CustomRenderTexture));
            PropagationLCRT = (CustomRenderTexture)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Lite/Wave_CRT.asset", typeof(CustomRenderTexture));
            FillMaterials();

        }
        private void FillMaterials()
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
            mats[5] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/DM_CRT.mat", typeof(Material));
            mats[6] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Default/DM_Top.mat", typeof(Material));
            mats[7] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Lite/LM_Bottom.mat", typeof(Material));
            mats[8] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Lite/LM_Distortion.mat", typeof(Material));
            mats[9] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Lite/LM_Flat_Mirror.mat", typeof(Material));
            mats[10] = (Material)AssetDatabase.LoadAssetAtPath("Assets/SilVR/Water/Materials/Lite/LM_CRT.mat", typeof(Material));
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