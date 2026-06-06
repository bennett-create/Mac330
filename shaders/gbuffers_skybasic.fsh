#version 330 compatibility

uniform int renderStage;
uniform int worldTime;
uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;

in vec4 glcolor;

#include "/lib/settings.glsl"
#include "/lib/atmosphere.glsl"

float fogify(float x, float w) {
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
#if ENABLE_REALISTIC_SKY == 1
	vec3 upDir = getAtmosphereUpDirection(gbufferModelView);
	return getAtmosphereColor(pos, normalize(sunPosition), upDir, worldTime);
#else
	float upDot = dot(pos, gbufferModelView[1].xyz); //not much, what's up with you?
	return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
#endif
}

vec3 screenToView(vec3 screenPos) {
	vec4 ndcPos = vec4(screenPos, 1.0) * 2.0 - 1.0;
	vec4 tmp = gbufferProjectionInverse * ndcPos;
	return tmp.xyz / tmp.w;
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	if (renderStage == MC_RENDER_STAGE_STARS) {
		color = glcolor;
	} else {
		vec3 pos = screenToView(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0));
		color = vec4(calcSkyColor(normalize(pos)), 1.0);
	}
}
