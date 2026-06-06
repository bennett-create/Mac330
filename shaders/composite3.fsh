#version 330 compatibility

uniform sampler2D colortex4;

in vec2 texcoord;

const bool colortex4Clear = false;
const bool colortex5Clear = false;

/* RENDERTARGETS: 5 */
layout(location = 0) out vec4 copiedExposureHistory;

void main(){
	copiedExposureHistory = texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0);
}
