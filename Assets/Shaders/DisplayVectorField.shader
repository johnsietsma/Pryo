Shader "Custom/Vector Display" {
	Properties{
		_MainTex("Base (RGB)", 2D) = "white" {}
	}
	SubShader{
			Pass{
				Tags{ "RenderType" = "Opaque" }
				LOD 200

				CGPROGRAM
				#include "flo.cginc"
				#include "UnityCG.cginc"

				#pragma vertex vert_img
				#pragma fragment frag

				sampler2D _MainTex;

				fixed4 frag(v2f_img i) : COLOR{
					return tex2D(_MainTex, i.uv);
				}
				ENDCG
			}
		}
		FallBack "Diffuse"
}
