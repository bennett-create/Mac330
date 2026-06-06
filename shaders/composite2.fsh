#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex5;

uniform float viewWidth;
uniform float viewHeight;
uniform float frameTime;
uniform int frameCounter;

in vec2 texcoord;

#include "/lib/settings.glsl"

const bool colortex0MipmapEnabled = true;
const bool colortex4Clear = false;
const bool colortex5Clear = false;

/* RENDERTARGETS: 4 */
layout(location = 0) out vec4 exposureHistory;

const float EXPOSURE_ENCODE_MIN = 0.015625;
const float EXPOSURE_ENCODE_MAX = 2048.0;
const float LUMINANCE_ENCODE_MIN = 0.0000001;
const float LUMINANCE_ENCODE_MAX = 8.0;

float luminance(vec3 value){
	return dot(value, vec3(0.2126, 0.7152, 0.0722));
}

float encodeLogRange(float value, float rangeMin, float rangeMax){
	float logMin = log2(rangeMin);
	float logMax = log2(rangeMax);
	return clamp((log2(clamp(value, rangeMin, rangeMax)) - logMin) / (logMax - logMin), 0.0, 1.0);
}

float decodeLogRange(float value, float rangeMin, float rangeMax){
	return exp2(mix(log2(rangeMin), log2(rangeMax), clamp(value, 0.0, 1.0)));
}

float sampleLogLuminance(vec2 coord, float lod){
	return log(max(luminance(max(textureLod(colortex0, coord, lod).rgb, vec3(0.0))), LUMINANCE_ENCODE_MIN));
}

float getCurrentSceneLuminance(){
	float maxLod = max(log2(max(viewWidth, viewHeight)) - 1.0, 1.0);
	float globalLod = min(maxLod, 10.0);
	float centerLod = min(maxLod, 6.0);
	float detailLod = min(maxLod, 3.0);

	float globalLog = sampleLogLuminance(vec2(0.5), globalLod);
	float centerLog = 0.0;
	float centerWeight = 0.0;

	vec2 aspect = vec2(viewHeight / max(viewWidth, 1.0), 1.0);
	vec2 r1 = vec2(0.16, 0.10) * aspect;
	vec2 r2 = vec2(0.29, 0.18) * aspect;

	centerLog += sampleLogLuminance(vec2(0.5), centerLod) * 4.0;
	centerLog += sampleLogLuminance(vec2(0.5) + vec2( r1.x,  0.0), centerLod);
	centerLog += sampleLogLuminance(vec2(0.5) + vec2(-r1.x,  0.0), centerLod);
	centerLog += sampleLogLuminance(vec2(0.5) + vec2( 0.0,  r1.y), centerLod);
	centerLog += sampleLogLuminance(vec2(0.5) + vec2( 0.0, -r1.y), centerLod);
	centerWeight += 8.0;

	centerLog += sampleLogLuminance(vec2(0.5) + vec2( r2.x,  r2.y), detailLod) * 0.6;
	centerLog += sampleLogLuminance(vec2(0.5) + vec2(-r2.x,  r2.y), detailLod) * 0.6;
	centerLog += sampleLogLuminance(vec2(0.5) + vec2( r2.x, -r2.y), detailLod) * 0.6;
	centerLog += sampleLogLuminance(vec2(0.5) + vec2(-r2.x, -r2.y), detailLod) * 0.6;
	centerWeight += 2.4;

	float weightedLog = mix(globalLog, centerLog / centerWeight, EYE_CENTER_WEIGHT);
	return clamp(exp(weightedLog), LUMINANCE_ENCODE_MIN, LUMINANCE_ENCODE_MAX);
}

float getTargetExposure(float sceneLuminance){
	float target = EYE_TARGET_LUMINANCE / max(sceneLuminance, LUMINANCE_ENCODE_MIN);
	return clamp(target, EYE_MIN_EXPOSURE, EYE_MAX_EXPOSURE);
}

void main(){
	ivec2 pixel = ivec2(gl_FragCoord.xy);
	vec4 previous = texelFetch(colortex5, pixel, 0);

	if(pixel.x != 0 || pixel.y != 0){
		exposureHistory = previous;
		return;
	}

	float sceneLuminance = getCurrentSceneLuminance();
	float targetExposure = getTargetExposure(sceneLuminance);
	float previousExposure = decodeLogRange(previous.r, EXPOSURE_ENCODE_MIN, EXPOSURE_ENCODE_MAX);
	float previousLuminance = decodeLogRange(previous.g, LUMINANCE_ENCODE_MIN, LUMINANCE_ENCODE_MAX);
	bool invalidHistory = frameCounter < 8 || previous.a < 0.5;

	if(invalidHistory){
		previousExposure = targetExposure;
		previousLuminance = sceneLuminance;
	}

	float adaptSpeed = targetExposure > previousExposure ? EYE_DARK_ADAPT_SPEED : EYE_LIGHT_ADAPT_SPEED;
	float frameDelta = clamp(frameTime, 0.0, 0.1);
	float adaptAmount = 1.0 - exp(-adaptSpeed * frameDelta);
	float adaptedExposure = mix(previousExposure, targetExposure, adaptAmount);
	float luminanceSpeed = sceneLuminance < previousLuminance ? EYE_DARK_ADAPT_SPEED * 0.65 : EYE_LIGHT_ADAPT_SPEED;
	float luminanceAdaptAmount = 1.0 - exp(-luminanceSpeed * frameDelta);
	float adaptedLuminance = mix(previousLuminance, sceneLuminance, luminanceAdaptAmount);

#if ENABLE_EYE_ADAPTATION != 1
	adaptedExposure = 1.0;
	targetExposure = 1.0;
	adaptedLuminance = sceneLuminance;
#endif

	exposureHistory = vec4(
		encodeLogRange(adaptedExposure, EXPOSURE_ENCODE_MIN, EXPOSURE_ENCODE_MAX),
		encodeLogRange(adaptedLuminance, LUMINANCE_ENCODE_MIN, LUMINANCE_ENCODE_MAX),
		encodeLogRange(targetExposure, EXPOSURE_ENCODE_MIN, EXPOSURE_ENCODE_MAX),
		1.0
	);
}
