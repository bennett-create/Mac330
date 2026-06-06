#version 330 compatibility

attribute vec4 mc_Entity;

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 shadowNormal;
flat out float plantShadowMask;

#include "/lib/distort.glsl"

void main() {
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	shadowNormal = normalize(gl_NormalMatrix * gl_Normal);

	int blockId = int(mc_Entity.x + 0.5);
	if(blockId == 10005 || blockId == 10013 || blockId == 10017 || blockId == 10021){
		plantShadowMask = 1.0;
	}else{
		plantShadowMask = 0.0;
	}

	gl_Position = ftransform();
	gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
}
