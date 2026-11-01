// Compile-time stand-ins only. This does NOT test Unity's engine or rendering.
using System;
using System.Collections;
namespace UnityEngine
{
    public class Object
    {
        public static T FindObjectOfType<T>() where T : class => null;
        public static void Destroy(Object o) { }
    }
    public class Component : Object { public GameObject gameObject = new GameObject(); public Transform transform => new Transform(); public T GetComponent<T>() where T : new() => new T(); }
    public class MonoBehaviour : Component { public Coroutine StartCoroutine(IEnumerator routine) => new Coroutine(); }
    public class Coroutine { }
    public class Transform : Component { public void SetParent(Transform t, bool stay) { } }
    public class RectTransform : Transform { public Vector2 anchorMin, anchorMax, offsetMin, offsetMax; }
    public class GameObject : Object
    {
        public GameObject(string name = "", params Type[] types) { }
        public T AddComponent<T>() where T : new() => new T();
        public T GetComponent<T>() where T : new() => new T();
        public void SetActive(bool enabled) { }
    }
    public struct Vector2 { public Vector2(float x, float y) { } public static Vector2 zero => new Vector2(); }
    public struct Color { public Color(float r, float g, float b, float a = 1) { } }
    public class Font : Object { }
    public static class Resources { public static T GetBuiltinResource<T>(string name) where T : new() => new T(); }
    public enum ScreenOrientation { LandscapeLeft }
    public static class Screen { public static ScreenOrientation orientation; public static int sleepTimeout; }
    public static class SleepTimeout { public static int NeverSleep = -1; }
    public static class PlayerPrefs { public static string GetString(string key, string fallback) => fallback; public static void SetString(string key, string value) { } public static void Save() { } }
    public static class Time { public static float unscaledDeltaTime; }
    public static class Mathf { public static float Max(float a, float b) => Math.Max(a, b); public static int CeilToInt(float f) => (int)Math.Ceiling(f); }
    public enum TextAnchor { MiddleLeft, MiddleCenter, MiddleRight, UpperLeft }
    public enum HorizontalWrapMode { Wrap }
    public enum VerticalWrapMode { Truncate }
    public enum RenderMode { ScreenSpaceOverlay }
    public class WaitForSecondsRealtime { public WaitForSecondsRealtime(float s) { } }
    public enum RuntimeInitializeLoadType { AfterSceneLoad }
    [AttributeUsage(AttributeTargets.Method)] public class RuntimeInitializeOnLoadMethodAttribute : Attribute { public RuntimeInitializeOnLoadMethodAttribute(RuntimeInitializeLoadType type) { } }
    public static class JsonUtility { public static string ToJson(object value) => "{}"; public static T FromJson<T>(string value) => default; }
    public class Canvas : Component { public RenderMode renderMode; }
}
namespace UnityEngine.EventSystems
{
    public class EventSystem : UnityEngine.Component { }
    public class StandaloneInputModule : UnityEngine.Component { }
}
namespace UnityEngine.Events
{
    public class UnityEvent { public void AddListener(Action cb) { } }
    public class UnityEvent<T> { public void AddListener(Action<T> cb) { } }
}
namespace UnityEngine.UI
{
    using UnityEngine;
    using UnityEngine.Events;
    public class Graphic : Component { public Color color; }
    public class Image : Graphic { }
    public class GraphicRaycaster : Component { }
    public class CanvasScaler : Component { public enum ScaleMode { ScaleWithScreenSize } public ScaleMode uiScaleMode; public Vector2 referenceResolution; public float matchWidthOrHeight; }
    public class Text : Graphic
    {
        public Font font; public int fontSize; public TextAnchor alignment; public string text;
        public bool resizeTextForBestFit, raycastTarget, supportRichText; public int resizeTextMinSize, resizeTextMaxSize;
        public HorizontalWrapMode horizontalOverflow; public VerticalWrapMode verticalOverflow;
    }
    public class Button : Component { public Graphic targetGraphic; public UnityEvent onClick = new UnityEvent(); }
    public class InputField : Component { public Graphic targetGraphic; public Text textComponent; public string text; public UnityEvent<string> onValueChanged = new UnityEvent<string>(); }
}
namespace UnityEngine.Networking
{
    using UnityEngine;
    public class UploadHandlerRaw { public UploadHandlerRaw(byte[] b) { } }
    public class DownloadHandlerBuffer { public string text; }
    public class UnityWebRequest : IDisposable
    {
        public enum Result { Success }
        public UnityWebRequest(string url, string method) { }
        public UploadHandlerRaw uploadHandler; public DownloadHandlerBuffer downloadHandler;
        public int timeout; public Result result; public long responseCode; public string error;
        public void SetRequestHeader(string key, string value) { }
        public object SendWebRequest() => null;
        public void Dispose() { }
    }
}
