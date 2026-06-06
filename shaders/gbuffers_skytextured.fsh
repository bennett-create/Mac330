#version 330 compatibility

uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;
uniform int renderStage;

in vec2 texcoord;
in vec4 glcolor;

#include "/lib/settings.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
#if ENABLE_REALISTIC_SKY == 1
	if(renderStage == MC_RENDER_STAGE_SUN || renderStage == MC_RENDER_STAGE_MOON){
		discard;
	}
#endif

	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < alphaTestRef) {
		discard;
	}
}
