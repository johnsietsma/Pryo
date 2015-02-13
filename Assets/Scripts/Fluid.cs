using UnityEngine;

public class Fluid : MonoBehaviour
{
    [SerializeField]
    private int numGridsWidth;

    [SerializeField]
    private int numGridsHeight;

    [SerializeField]
    private float gridSize;

    [SerializeField]
    private Vector2 initialVelocity;

    private VectorField2 vectorField;

#if UNITY_EDITOR
    private Vector2 cachedVectorFieldSize;
#endif

    private void Awake()
    {
        vectorField = CreateVectorField();
    }

    private void Update()
    {
#if UNITY_EDITOR
        EnsureCorrectGridSize();
#endif

    }

    private void OnDrawGizmosSelected()
    {
        if( vectorField==null ) return;

        var halfFieldSize = new Vector2( numGridsWidth, numGridsHeight );
        halfFieldSize *= gridSize/2;

        var worldHalfGrid = transform.TransformDirection( new Vector2(gridSize, gridSize));

        for( int widthIndex=0; widthIndex<vectorField.Width; widthIndex++ )
        for( int heightIndex=0; heightIndex<vectorField.Height; heightIndex++ )
        {
            var gridPos = new Vector2( widthIndex*gridSize, heightIndex*gridSize );
            gridPos -= halfFieldSize;

            var gridWorldPos = transform.TransformPoint( gridPos );
            Gizmos.DrawSphere( gridWorldPos, 0.2f );
            Gizmos.DrawWireCube( gridWorldPos, worldHalfGrid );
            Gizmos.DrawLine( gridWorldPos, gridWorldPos + transform.TransformPoint( vectorField.At(widthIndex, heightIndex) ) );
        }
    }

    public void ResetVelocity()
    {
        vectorField.SetAll( initialVelocity );
    }

    private VectorField2 CreateVectorField()
    {
        var width = Mathf.Max(1,numGridsWidth);
        var height = Mathf.Max(1,numGridsHeight);

        var vf = new VectorField2( width, height );
        vf.SetAll( initialVelocity );
        return vf;
    }

#if UNITY_EDITOR
    private void EnsureCorrectGridSize()
    {
        if( numGridsHeight!=vectorField.Height || numGridsWidth!=vectorField.Width )
        {
            vectorField = CreateVectorField();
        }
    }
#endif
}
