#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace Bunker.UnityPort.Editor
{
    public static class PrototypeBuild
    {
        // This prototype intentionally uses a DIFFERENT package id and debug
        // signing. It must not replace the production Godot APK or its key.
        [MenuItem("Bunker/Configure Unity prototype")]
        public static void Configure()
        {
            PlayerSettings.companyName = "Bunker";
            PlayerSettings.productName = "Бункер — Unity прототип";
            PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, "org.bunker.unityprototype");
            PlayerSettings.bundleVersion = "0.1.0";
            PlayerSettings.Android.bundleVersionCode = 1;
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene("Assets/Scenes/Bootstrap.unity", true) };
        }
        [MenuItem("Bunker/Build prototype Android APK")]
        public static void BuildAndroid()
        {
            Configure();
            Directory.CreateDirectory("Builds");
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions {
                scenes = new[] { "Assets/Scenes/Bootstrap.unity" },
                locationPathName = "Builds/bunker-unity-prototype.apk",
                target = BuildTarget.Android,
                options = BuildOptions.Development
            });
            if (report.summary.result != BuildResult.Succeeded)
                throw new InvalidOperationException("Unity prototype build failed: " + report.summary.result);
            Debug.Log("Unity prototype APK: " + report.summary.outputPath);
        }
    }
}
#endif
