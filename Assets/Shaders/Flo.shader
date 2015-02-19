Shader "Custom/Flo" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_VelocityField ("Velocity Field (RGB)", 2D) = "white" {}
		_Dissipation ("Dissipation", Float) = 1
		_GridScale ("Grid Scale", Float) = 1
	}
	SubShader {
		Pass {
			Tags { "RenderType"="Opaque" }
			LOD 200

			CGPROGRAM
			#include "flo.cginc"
			#include "UnityCG.cginc"

			#pragma vertex vert_img
			#pragma fragment frag

			sampler2D _MainTex;
			float4 _MainTex_TexelSize;
			sampler2D _VelocityField;
			float _Dissipation;
			float _GridScale;

	        fixed4 frag(v2f_img i) : COLOR {
				//float time = _Time;
				float time = unity_DeltaTime;
				FloTexelSize = _MainTex_TexelSize.zw;
				float2 sp = i.uv*FloTexelSize;
				return advect( sp, time, _Dissipation, 1/_GridScale, _VelocityField, _MainTex );
	        }

			ENDCG
		}
	}
	FallBack "Diffuse"
}
