#if UNITY_EDITOR
using UnityEditor;

namespace Bunker.UnityPort.Editor
{
    public sealed class IrondustImportSettings : AssetPostprocessor
    {
        private void OnPreprocessTexture()
        {
            if (assetPath == "Assets/Resources/Irondust/NormalMap.jpg")
                ((TextureImporter)assetImporter).textureType = TextureImporterType.NormalMap;
        }
    }
}
#endif
