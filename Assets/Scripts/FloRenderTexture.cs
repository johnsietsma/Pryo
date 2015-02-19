using UnityEngine;
using System.Collections;

public class FloRenderTexture : MonoBehaviour {

    [SerializeField]
    private Texture2D initTexture;

    [SerializeField]
    private Material renderMaterial;

    [SerializeField]
    private Material displayMaterial;

    private RenderTexture renderTexture;

    void Start()
    {
        /*if(!SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBFloat))
        {
            Debug.LogError("Float render textures are not supported.");
            enabled = false;
            return;
        }*/
        renderTexture = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGBFloat);
        //Graphics.Blit( initTexture, renderTexture );
        displayMaterial.mainTexture = renderTexture;
    }

    void OnPostRender()
    {
        Graphics.Blit(initTexture, renderTexture, renderMaterial);
    }
}
