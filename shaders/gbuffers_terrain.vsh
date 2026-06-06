#version 330 compatibility

uniform mat4 gbufferModelViewInverse;

attribute vec4 mc_Entity;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
flat out float foliageMask;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;

	normal = gl_NormalMatrix * gl_Normal; // this gives us the normal in view space
	normal = mat3(gbufferModelViewInverse) * normal; // this converts the normal to world/player space

	int blockId = int(mc_Entity.x + 0.5);
	if(blockId == 10009){
		foliageMask = 1.0;
	}else if(blockId == 10005 || blockId == 10013 || blockId == 10017 || blockId == 10021){
		foliageMask = 0.72;
	}else{
		foliageMask = 0.0;
	}
}
