#if UNITY_EDITOR
using System;
using Bunker.UnityPort.World;
using UnityEditor;
using UnityEngine;

namespace Bunker.UnityPort.Editor
{
    // Engine-level configuration check. Touches and collisions still require
    // device/integration tests; this is not a simulated gameplay test.
    public static class TouchControllerAudit
    {
        public static void Verify()
        {
            var root = new GameObject("Touch controller audit");
            root.SetActive(false);
            root.AddComponent<CharacterController>();
            var camera = new GameObject("Pivot");
            camera.transform.SetParent(root.transform, false);
            camera.transform.localPosition = new Vector3(0, 1.65f, 0);
            var controller = root.AddComponent<BunkerTouchController>();
            controller.cameraPivot = camera.transform;
            root.SetActive(true);
            typeof(BunkerTouchController).GetMethod("Awake", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic).Invoke(controller, null);
            controller.SetTopView(true);
            if (camera.transform.localPosition.y < 5) throw new Exception("top view did not move camera");
            controller.SetTopView(false);
            if (Mathf.Abs(camera.transform.localPosition.y - 1.65f) > .001f) throw new Exception("first person camera not restored");
            UnityEngine.Object.DestroyImmediate(root);
            Debug.Log("BUNKER_TOUCH_AUDIT_OK");
        }
    }
}
#endif
