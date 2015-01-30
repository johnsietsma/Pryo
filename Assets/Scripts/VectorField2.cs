using System;
using UnityEngine;

public class VectorField2
{
    public int Width { get; private set; }
    public int Height { get; private set; }

    private Vector2[] field;

    public VectorField2( int width, int height )
    {
        Width = width;
        Height = height;
        field = new Vector2[width*height];
    }

    public void SetAll( Vector2 v )
    {
        for( int i=0; i<field.Length; i++ )
        {
            field[i] = v;
        }
    }

    public Vector2 At( int x, int y )
    {
        int index = y*Width + x;
        if( index < 0 || index >= field.Length ) { throw new ArgumentException( string.Format( "({0},{1} is out of range of VectorField {2}", x, y, this ) ); }

        return field[index];
    }

    public override string ToString()
    {
        return string.Format( "Width:{0} Height:{1}", Width, Height );
    }
}
