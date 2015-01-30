using UnityEngine;
using UnityEditor;
using System.Collections;

[CustomEditor(typeof(Fluid))]
public class FluidEditor : Editor {

    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        var fluid = target as Fluid;

        if( GUILayout.Button( "Reset Velocity") )
        {
            fluid.ResetVelocity();
        }
    }
}
