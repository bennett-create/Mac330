#version 330 compatibility

uniform sampler2D depthtex0;

uniform sampler2D shadowtex1;
uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform float viewWidth;
uniform float viewHeight;
uniform vec3 cameraPosition;

uniform int worldTime;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

in vec2 texcoord;

#include "/lib/settings.glsl"
#include "/lib/distort.glsl"
#include "/lib/daylight.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/pixelation.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const vec3 legacyBlocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 legacyAmbientColor = vec3(0.1);

const float PI = 3.14159265359;
const float TAU = PI * 2.0;
#define VOGEL_DISK_COUNT 24
const vec2 VOGEL_DISK[VOGEL_DISK_COUNT] = vec2[VOGEL_DISK_COUNT](
	vec2(0.1250000, 0.0000000),
	vec2(-0.1596451, 0.1462509),
	vec2(0.0244357, -0.2784379),
	vec2(0.2012222, 0.2624597),
	vec2(-0.3692696, -0.0653187),
	vec2(0.3498160, -0.2225290),
	vec2(-0.1170030, 0.4352653),
	vec2(-0.2231351, -0.4296398),
	vec2(0.4841258, 0.1767939),
	vec2(-0.5036266, 0.2078992),
	vec2(0.2427934, -0.5188254),
	vec2(0.1794267, 0.5719988),
	vec2(-0.5407545, -0.3133790),
	vec2(0.6353756, -0.1394467),
	vec2(-0.3870828, 0.5505925),
	vec2(-0.0894352, -0.6901315),
	vec2(0.5490497, 0.4627243),
	vec2(-0.7386475, 0.0305535),
	vec2(0.5389176, -0.5362900),
	vec2(-0.0360562, 0.7797628),
	vec2(-0.5127939, -0.6145014),
	vec2(0.8123322, 0.1092947),
	vec2(-0.6882888, 0.4788948),
	vec2(0.1880677, -0.8360234)
);

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
	vec4 homPos = projectionMatrix * vec4(position, 1.0);
	return homPos.xyz / homPos.w;
}

vec3 getViewPos(vec2 screenPos, float depth){
	vec3 ndcPos = vec3(screenPos, depth) * 2.0 - 1.0;
	return projectAndDivide(gbufferProjectionInverse, ndcPos);
}

vec3 getPlayerPos(vec3 viewPos){
	return (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
}

vec3 decodeNormal(vec3 encodedNormal){
	return normalize((encodedNormal - 0.5) * 2.0);
}

float interleavedGradientNoise(vec2 pixel){
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

float shadowCompare(float receiverDepth, float shadowDepth){
	return smoothstep(-SHADOW_COMPARE_SOFTNESS, SHADOW_COMPARE_SOFTNESS, shadowDepth - receiverDepth);
}

float getShadowDepthBias(float sunlightFacing){
	float slope = pow(1.0 - clamp(sunlightFacing, 0.0, 1.0), 2.0);
	return SHADOW_BIAS + slope * SHADOW_SLOPE_BIAS;
}

vec3 getShadow(vec3 shadowScreenPos){
	if(shadowScreenPos.x <= 0.0 || shadowScreenPos.y <= 0.0 || shadowScreenPos.x >= 1.0 || shadowScreenPos.y >= 1.0){
		return vec3(1.0);
	}

	if(shadowScreenPos.z <= 0.0 || shadowScreenPos.z >= 1.0){
		return vec3(1.0);
	}

	float transparentVisibility = shadowCompare(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
	float opaqueVisibility = shadowCompare(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r);
	vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);
	vec3 transparentLight = mix(shadowColor.rgb * (1.0 - shadowColor.a), vec3(1.0), transparentVisibility);
	return mix(vec3(0.0), transparentLight, opaqueVisibility);
}

vec3 getSoftShadow(vec4 shadowClipPos, float sunlightFacing){
	shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz);

	vec3 shadowNDCPos = shadowClipPos.xyz / shadowClipPos.w;
	vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5;
	shadowScreenPos.z -= getShadowDepthBias(sunlightFacing);

#if PIXELATED_SHADOWS == 1
	float noise = 0.5;
	float noise2 = 0.5;
#else
	float noise = interleavedGradientNoise(gl_FragCoord.xy);
	float noise2 = interleavedGradientNoise(gl_FragCoord.xy + vec2(17.0, 59.0));
#endif
	float enableJitter = step(0.001, SHADOW_FILTER_JITTER);
	float theta = SHADOW_KERNEL_ROTATION + noise * TAU * enableJitter;
	float cosTheta = cos(theta);
	float sinTheta = sin(theta);
	mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
	float texelRadius = (SHADOW_RADIUS * getSunShadowSoftness(worldTime)) / float(shadowMapResolution);
#if PIXELATED_SHADOWS == 1
	texelRadius *= 0.75;
#endif
	float radiusJitter = 1.0;
#if PIXELATED_SHADOWS != 1
	radiusJitter += (noise2 - 0.5) * 0.35 * SHADOW_FILTER_JITTER;
	shadowScreenPos.xy += (vec2(noise, noise2) - 0.5) * (SHADOW_FILTER_JITTER / float(shadowMapResolution));
#endif
	vec3 shadowAccum = vec3(0.0);

	for(int i = 0; i < SHADOW_SAMPLES; i++){
		vec3 offsetShadowScreenPos = shadowScreenPos;
		offsetShadowScreenPos.xy += (rotation * VOGEL_DISK[i]) * texelRadius * radiusJitter;
		shadowAccum += getShadow(offsetShadowScreenPos);
	}

	return shadowAccum / float(SHADOW_SAMPLES);
}

float luminance(vec3 value){
	return dot(value, vec3(0.2126, 0.7152, 0.0722));
}

vec3 getSubsurfaceScattering(vec3 albedo, vec3 normal, vec3 lightDir, vec3 playerPos, float skylight, vec3 shadow, float foliageMask, vec3 sunRadiance){
#if ENABLE_SUBSURFACE_SCATTERING != 1
	return vec3(0.0);
#else
	if(foliageMask <= 0.001){
		return vec3(0.0);
	}

	vec3 viewRay = normalize(playerPos);
	float backNormal = pow(max(dot(-normal, lightDir), 0.0), 1.35);
	float viewBacklight = pow(max(dot(viewRay, lightDir), 0.0), 2.0);
	float wrapLight = pow(clamp(dot(normal, lightDir) * 0.5 + 0.5, 0.0, 1.0), 2.0) * 0.35;
	float transmission = max(backNormal, viewBacklight * 0.65) + wrapLight;

	float shadowVisibility = max(max(shadow.r, shadow.g), shadow.b);
	float skyGate = smoothstep(0.25, 0.95, skylight);
	float strength = foliageMask * transmission * mix(0.25, 1.0, shadowVisibility) * skyGate * SSS_STRENGTH;

	float maxChannel = max(max(albedo.r, albedo.g), albedo.b);
	vec3 albedoTint = clamp(albedo / max(maxChannel, 0.06), vec3(0.25), vec3(1.25));
	vec3 foliageTint = mix(vec3(0.72, 1.0, 0.34), albedoTint, SSS_TINT_STRENGTH);

	return sunRadiance * foliageTint * strength;
#endif
}

vec4 getBilateralGI(float depth, vec3 normal){
#if ENABLE_GI != 1
	return vec4(0.0, 0.0, 0.0, 1.0);
#else
	vec2 viewSize = vec2(viewWidth, viewHeight);
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);
	vec2 pixel = floor(texcoord * viewSize);
	vec2 gridBase = floor(pixel / float(GI_RENDER_SCALE)) * float(GI_RENDER_SCALE);
	vec4 gi = vec4(0.0);
	float weightSum = 0.0;

	for(int x = -GI_FILTER_RADIUS; x <= GI_FILTER_RADIUS; x++){
		for(int y = -GI_FILTER_RADIUS; y <= GI_FILTER_RADIUS; y++){
			vec2 gridOffset = vec2(float(x), float(y));
			vec2 samplePixel = gridBase + gridOffset * float(GI_RENDER_SCALE);
			vec2 sampleCoord = (samplePixel + 0.5) * pixelSize;

			if(sampleCoord.x <= 0.0 || sampleCoord.y <= 0.0 || sampleCoord.x >= 1.0 || sampleCoord.y >= 1.0){
				continue;
			}

			float sampleDepth = texture(depthtex0, sampleCoord).r;
			if(sampleDepth == 1.0){
				continue;
			}

			vec3 sampleNormal = decodeNormal(texture(colortex2, sampleCoord).rgb);
			float depthWeight = clamp(1.0 - abs(sampleDepth - depth) * 160.0, 0.0, 1.0);
			float normalWeight = clamp(dot(sampleNormal, normal) * 2.0 - 1.0, 0.0, 1.0);
			float spatialWeight = 1.0 / (1.0 + dot(gridOffset, gridOffset) * 0.45);
			float weight = max(depthWeight * normalWeight * spatialWeight, 0.0001);

			gi += texture(colortex3, sampleCoord) * weight;
			weightSum += weight;
		}
	}

	return gi / max(weightSum, 0.0001);
#endif
}

void main() {
	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2));

	float depth = texture(depthtex0, texcoord).r;
	if (depth == 1.0) {
		return;
	}

	ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
	vec4 lightmapData = texelFetch(colortex1, pixelCoord, 0);
	vec2 lightmap = lightmapData.rg;
	vec4 normalData = texelFetch(colortex2, pixelCoord, 0);
	vec3 normal = decodeNormal(normalData.rgb);
	float foliageMask = normalData.a;
	vec3 lightVector = normalize(shadowLightPosition);
	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;
	float sunlightFacing = clamp(dot(worldLightVector, normal), 0.0, 1.0);

	vec3 viewPos = getViewPos(texcoord, depth);
	vec3 feetPlayerPos = getPlayerPos(viewPos);
#if PIXELATED_SHADOWS == 1
	vec3 texelSnappedPlayerPos = pixelatedShadowTexelSnap(feetPlayerPos, decodePixelatedShadowOffset(lightmapData.ba));
	vec3 blockGridSnappedPlayerPos = pixelatedShadowBlockGridSnap(feetPlayerPos, normal, cameraPosition);
	feetPlayerPos = mix(texelSnappedPlayerPos, blockGridSnappedPlayerPos, pixelatedShadowAxisAlignedWeight(normal));
#endif
	float receiverNormalBias = SHADOW_NORMAL_BIAS * (1.0 + pow(1.0 - sunlightFacing, 2.0));
	vec3 shadowReceiverPos = feetPlayerPos + normal * receiverNormalBias;
	vec3 shadowViewPos = (shadowModelView * vec4(shadowReceiverPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

	vec3 shadow = vec3(0.0);
	float shadowFacing = sunlightFacing;
#if ENABLE_SUBSURFACE_SCATTERING == 1
	shadowFacing = max(shadowFacing, foliageMask * 0.35);
#endif
	if(shadowFacing > 0.0){
		shadow = getSoftShadow(shadowClipPos, shadowFacing);
	}

	vec4 gi = getBilateralGI(depth, normal);
	vec3 indirect = gi.rgb * GI_APPLY_STRENGTH;
	float ao = gi.a;

#if ENABLE_GI == 1 && GI_DEBUG == 1
	color.rgb = indirect * GI_DEBUG_SCALE;
	return;
#endif

#if ENABLE_PHYSICAL_LIGHTING == 1
	vec3 blocklight = getBlockLightRadiance(lightmap.r);
	vec3 ambient = getCaveAmbientRadiance();
#else
	vec3 blocklight = lightmap.r * legacyBlocklightColor;
	vec3 ambient = legacyAmbientColor;
#endif
	vec3 sunViewDir = normalize(sunPosition);
	vec3 upDir = getAtmosphereUpDirection(gbufferModelView);
	vec3 skylightRadiance = getAtmosphereSkylight(sunViewDir, upDir, worldTime);
	vec3 skylight = lightmap.g * skylightRadiance;
	vec3 sunRadiance = getSunRadiance(worldTime);
	vec3 sunlight = sunRadiance * sunlightFacing * shadow;
	sunlight += getSubsurfaceScattering(color.rgb, normal, worldLightVector, feetPlayerPos, lightmap.g, shadow, foliageMask, sunRadiance);

	color.rgb *= blocklight + skylight + ambient + sunlight + indirect;
	color.rgb *= ao;
}
