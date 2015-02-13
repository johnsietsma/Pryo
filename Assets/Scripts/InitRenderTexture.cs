using UnityEngine;
using System.Collections;

public class InitRenderTexture : MonoBehaviour {

    [SerializeField]
    private Texture2D initTexture;

    [SerializeField]
    private RenderTexture renderTexture;

    void Start()
    {
        Graphics.Blit( initTexture, renderTexture );
    }
}
