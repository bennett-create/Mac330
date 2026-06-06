#version 330 compatibility

uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 shadowNormal;
flat in float plantShadowMask;

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 shadowData;

#include "/lib/settings.glsl"

void main() {
#if PLANT_SHADOWS != 1
	if(plantShadowMask > 0.5){
		discard;
	}
#endif

	color = textureLod(gtexture, texcoord, 0.0) * glcolor;
	if(color.a < 0.1){
		discard;
	}

	float skylight = clamp(lmcoord.t, 0.0, 1.0);
	shadowData = vec4(normalize(shadowNormal) * 0.5 + 0.5, skylight);
}
