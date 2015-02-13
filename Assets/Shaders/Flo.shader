Shader "Custom/Flo" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Dissipation ("Dissipation", Float) = 1
		_GridScale ("Grid Scale", Float) = 1
	}
	SubShader {
		Pass {
			Tags { "RenderType"="Opaque" }
			LOD 200

			CGPROGRAM
			#include "flo.cg"
			#include "UnityCG.cginc"

			#pragma vertex vert_img
			#pragma fragment frag

			sampler2D _MainTex;
			float _Dissipation;
			float _GridScale;

			struct Input {
				float2 uv_MainTex;
			};

	        fixed4 frag(float4 sp:WPOS) : COLOR {
	        	return advect( sp.xy, unity_DeltaTime, _Dissipation, 1/_GridScale, _MainTex, _MainTex );
	        }

			ENDCG
		}
	}
	FallBack "Diffuse"
}
