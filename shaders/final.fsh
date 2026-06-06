#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex4;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

layout(location = 0) out vec4 color;

#include "/lib/settings.glsl"

const bool colortex0MipmapEnabled = true;

#define TONEMAP_ACES 1
#define TONEMAP_REINHARD_JODIE 2
#define TONEMAP_OPERATOR TONEMAP_ACES

const float EXPOSURE_ENCODE_MIN = 0.015625;
const float EXPOSURE_ENCODE_MAX = 2048.0;
const float LUMINANCE_ENCODE_MIN = 0.0000001;
const float LUMINANCE_ENCODE_MAX = 8.0;

float decodeLogRange(float value, float rangeMin, float rangeMax){
	return exp2(mix(log2(rangeMin), log2(rangeMax), clamp(value, 0.0, 1.0)));
}

vec3 acesToneMap(vec3 value, float exposure){
	value *= exposure;
	const float a = 2.51;
	const float b = 0.03;
	const float c = 2.43;
	const float d = 0.59;
	const float e = 0.14;
	return clamp((value * (a * value + b)) / (value * (c * value + d) + e), 0.0, 1.0);
}

vec3 reinhardJodieToneMap(vec3 value, float exposure){
	value *= exposure;
	float luminance = dot(value, vec3(0.2126, 0.7152, 0.0722));
	vec3 perChannel = value / (value + vec3(1.0));
	return clamp(mix(value / (luminance + 1.0), perChannel, perChannel), 0.0, 1.0);
}

vec3 toneMap(vec3 value, float exposure){
	value = max(value, vec3(0.0));

#if TONEMAP_OPERATOR == TONEMAP_REINHARD_JODIE
	return reinhardJodieToneMap(value, exposure);
#else
	return acesToneMap(value, exposure);
#endif
}

float luminance(vec3 value){
	return dot(value, vec3(0.2126, 0.7152, 0.0722));
}

vec4 getEyeAdaptationData(){
	vec4 encoded = texelFetch(colortex4, ivec2(0), 0);

#if ENABLE_EYE_ADAPTATION != 1
	return vec4(1.0, 0.3, 1.0, 1.0);
#else
	if(encoded.a < 0.5){
		return vec4(1.0, 0.3, 1.0, 0.0);
	}

	return vec4(
		decodeLogRange(encoded.r, EXPOSURE_ENCODE_MIN, EXPOSURE_ENCODE_MAX),
		decodeLogRange(encoded.g, LUMINANCE_ENCODE_MIN, LUMINANCE_ENCODE_MAX),
		decodeLogRange(encoded.b, EXPOSURE_ENCODE_MIN, EXPOSURE_ENCODE_MAX),
		1.0
	);
#endif
}

vec3 applyLowLightVision(vec3 value, float sceneLuminance, float adaptedExposure){
#if ENABLE_EYE_ADAPTATION != 1
	return value;
#else
	float luminanceGate = 1.0 - smoothstep(EYE_SCOTOPIC_LUMINANCE, EYE_SCOTOPIC_LUMINANCE * 8.0, sceneLuminance);
	float exposureGate = smoothstep(EYE_SCOTOPIC_EXPOSURE * 0.35, EYE_SCOTOPIC_EXPOSURE, adaptedExposure);
	float lowLight = luminanceGate * exposureGate;
	float lum = luminance(value);
	vec3 desaturated = mix(value, vec3(lum), lowLight * 0.72);
	vec3 shifted = desaturated * mix(vec3(1.0), vec3(0.78, 0.90, 1.22), lowLight * 0.55);
	return mix(value, shifted, lowLight * EYE_SCOTOPIC_BLEND);
#endif
}

vec3 bloomSourceResponse(vec3 hdrColor, float exposure){
	float response = 1.0 - exp(-luminance(max(hdrColor * exposure, vec3(0.0))) * BLOOM_RESPONSE);
	return hdrColor * response;
}

vec3 sampleBloomMip(vec2 uv, float lod, float radius, float exposure){
	vec2 texelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight) * exp2(lod) * radius;
	vec3 bloom = vec3(0.0);

	bloom += bloomSourceResponse(textureLod(colortex0, uv, lod).rgb, exposure) * 4.0;
	bloom += bloomSourceResponse(textureLod(colortex0, uv + vec2( texelSize.x,  texelSize.y), lod).rgb, exposure);
	bloom += bloomSourceResponse(textureLod(colortex0, uv + vec2(-texelSize.x,  texelSize.y), lod).rgb, exposure);
	bloom += bloomSourceResponse(textureLod(colortex0, uv + vec2( texelSize.x, -texelSize.y), lod).rgb, exposure);
	bloom += bloomSourceResponse(textureLod(colortex0, uv + vec2(-texelSize.x, -texelSize.y), lod).rgb, exposure);

	return bloom * (1.0 / 8.0);
}

vec3 getPhysicallyBasedBloom(vec2 uv, float exposure){
#if ENABLE_PHYS_BLOOM != 1
	return vec3(0.0);
#else
	vec3 bloom = vec3(0.0);
	float weightSum = 0.0;

	float w1 = 0.38;
	float w2 = 0.28;
	float w3 = 0.20;
	float w4 = 0.14;
	float w5 = 0.10;

	bloom += sampleBloomMip(uv, 1.0, BLOOM_RADIUS, exposure) * w1;
	bloom += sampleBloomMip(uv, 2.0, BLOOM_RADIUS, exposure) * w2;
	bloom += sampleBloomMip(uv, 3.0, BLOOM_RADIUS, exposure) * w3;
	bloom += sampleBloomMip(uv, 4.0, BLOOM_RADIUS, exposure) * w4;
	bloom += sampleBloomMip(uv, 5.0, BLOOM_RADIUS, exposure) * w5;
	weightSum = w1 + w2 + w3 + w4 + w5;

	return bloom / weightSum;
#endif
}

void main() {
	color = texture(colortex0, texcoord);
	vec4 eyeData = getEyeAdaptationData();
	float sceneExposure = TONEMAP_EXPOSURE * eyeData.x;
#if ENABLE_PHYS_BLOOM == 1
	color.rgb += getPhysicallyBasedBloom(texcoord, sceneExposure) * BLOOM_STRENGTH;
#endif
	color.rgb = toneMap(color.rgb, sceneExposure);
	color.rgb = applyLowLightVision(color.rgb, eyeData.y, eyeData.x);
	color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
}
