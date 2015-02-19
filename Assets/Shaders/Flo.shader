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
			#include "flo.cg"
			#include "UnityCG.cginc"

			#pragma vertex vert_img
			#pragma fragment frag

			sampler2D _MainTex;
			sampler2D _VelocityField;
			float _Dissipation;
			float _GridScale;

			struct Input {
				float2 uv_MainTex;
			};

	        fixed4 frag(float4 sp:WPOS) : COLOR {
	        	//float time = unity_DeltaTime;
	        	float time = _Time;
	        	float2 u = advect( sp, time, _Dissipation, 1/_GridScale, _VelocityField, _MainTex );
	        	u = diffuse()
	        	//float2 s = sp - sp * time * 1/_GridScale * f4texRECT(_VelocityField, sp);
	        	//return _Dissipation * f4texRECTbilerp(_MainTex, s);
	        }

			ENDCG
		}
	}
	FallBack "Diffuse"
}
