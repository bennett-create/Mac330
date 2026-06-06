#version 330 compatibility

#include "/lib/settings.glsl"
#include "/lib/distort.glsl"
#include "/lib/daylight.glsl"

#if ENABLE_GI == 1
const float ambientOcclusionLevel = 0.0;
#else
const float ambientOcclusionLevel = 1.0;
#endif

uniform sampler2D depthtex0;
#if GI_SUN_SHADOW_CHECK == 1
uniform sampler2D shadowtex1;
uniform sampler2D shadowtex0;
#endif
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform int worldTime;
uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
#if GI_SUN_SHADOW_CHECK == 1
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
#endif

in vec2 texcoord;

/*
const int colortex0Format = RGBA16F;
const int colortex3Format = RGBA16F;
*/

/* RENDERTARGETS: 3 */
layout(location = 0) out vec4 giBuffer;

const float PI = 3.14159265359;
const float TAU = PI * 2.0;

#define VOGEL_DISK_COUNT 32
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
	vec2(0.1880677, -0.8360234),
	vec2(0.4426709, 0.7596128),
	vec2(-0.8507640, -0.3153562),
	vec2(0.8194199, -0.4047778),
	vec2(-0.3770021, 0.8533796),
	vec2(-0.2705467, -0.9095084),
	vec2(0.7747350, 0.5999274),
	vec2(-0.9705749, 0.0421510),
	vec2(0.6801555, -0.7206553)
);

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
	vec4 homPos = projectionMatrix * vec4(position, 1.0);
	return homPos.xyz / homPos.w;
}

float hash13(vec3 value){
	value = fract(value * vec3(0.1031, 0.11369, 0.13787));
	value += dot(value, value.yzx + 19.19);
	return fract((value.x + value.y) * value.z);
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

vec3 getViewNormal(vec2 screenPos){
	vec3 playerNormal = decodeNormal(texture(colortex2, screenPos).rgb);
	return normalize(mat3(gbufferModelView) * playerNormal);
}

mat3 getNormalBasis(vec3 normal){
	vec3 up = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 tangent = normalize(cross(up, normal));
	vec3 bitangent = cross(normal, tangent);
	return mat3(tangent, bitangent, normal);
}

vec3 shapeBounceColor(vec3 color){
	color *= color;
	float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
	return max(mix(vec3(luminance), color, GI_COLOR_SATURATION), vec3(0.0)) * (0.75 + luminance * 0.5);
}

#if GI_SUN_SHADOW_CHECK == 1
vec3 getShadowScreenPos(vec3 viewPos){
	vec3 playerPos = getPlayerPos(viewPos);
	vec3 shadowViewPos = (shadowModelView * vec4(playerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz);
	vec3 shadowNDCPos = shadowClipPos.xyz / shadowClipPos.w;
	vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5;
	shadowScreenPos.z -= SHADOW_BIAS;
	return shadowScreenPos;
}

float getSunVisibility(vec3 viewPos){
	vec3 shadowScreenPos = getShadowScreenPos(viewPos);

	if(shadowScreenPos.x <= 0.0 || shadowScreenPos.y <= 0.0 || shadowScreenPos.x >= 1.0 || shadowScreenPos.y >= 1.0){
		return 1.0;
	}

	if(shadowScreenPos.z <= 0.0 || shadowScreenPos.z >= 1.0){
		return 1.0;
	}

	float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
	if(transparentShadow == 1.0){
		return 1.0;
	}

	return step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r);
}
#else
float getSunVisibility(vec3 viewPos){
	return 1.0;
}
#endif

vec3 getSunBounce(vec3 sampleViewPos, vec3 sampleNormalView, vec2 sampleLightmap, vec3 sunDirView, vec3 sunRadiance){
	float sunFacing = clamp(dot(sampleNormalView, sunDirView), 0.0, 1.0);
	float sunVisibility = getSunVisibility(sampleViewPos + sampleNormalView * 0.05);
	float sunHit = sqrt(sunFacing) * sunVisibility * sampleLightmap.g;
	return sunRadiance * sunHit * GI_SUN_BOUNCE_STRENGTH;
}

bool shouldRenderGI(vec3 viewPos){
	if(dot(viewPos, viewPos) > GI_MAX_VIEW_DISTANCE * GI_MAX_VIEW_DISTANCE){
		return false;
	}

#if GI_RENDER_SCALE > 1
	ivec2 pixel = ivec2(gl_FragCoord.xy);
	return (pixel.x % GI_RENDER_SCALE == 0) && (pixel.y % GI_RENDER_SCALE == 0);
#else
	return true;
#endif
}

vec4 traceScreenSpaceGI(vec3 originViewPos, vec3 normalView, float receiverSkylight, vec3 receiverPlayerPos, vec3 sunDirView, vec3 sunRadiance){
	mat3 basis = getNormalBasis(normalView);
	vec3 stableSeed = receiverPlayerPos * GI_NOISE_SCALE;
	float theta = hash13(stableSeed + normalView * 11.0) * TAU;
	float cosTheta = cos(theta);
	float sinTheta = sin(theta);
	mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
	vec3 indirect = vec3(0.0);
	float occlusion = 0.0;

	for(int i = 0; i < GI_SAMPLES; i++){
		vec2 disk = rotation * VOGEL_DISK[i];
		float hemisphereZ = sqrt(max(0.0, 1.0 - dot(disk, disk)));
		vec3 rayDir = normalize(basis * vec3(disk, hemisphereZ));
		float receiverFacing = max(dot(normalView, rayDir), 0.0);

		if(receiverFacing <= 0.001){
			continue;
		}

		for(int stepIndex = 0; stepIndex < GI_STEPS; stepIndex++){
			float stepNoise = hash13(stableSeed + vec3(float(i) * 17.0, float(stepIndex) * 7.0, 3.0));
			float stepOffset = mix(0.5, stepNoise, GI_STEP_JITTER);
			float stepRatio = (float(stepIndex) + stepOffset) / float(GI_STEPS);
			float rayDistance = mix(GI_MIN_DISTANCE, GI_RADIUS, stepRatio * stepRatio);
			vec3 rayViewPos = originViewPos + rayDir * rayDistance;

			vec4 rayClipPos = gbufferProjection * vec4(rayViewPos, 1.0);
			if(rayClipPos.w <= 0.0){
				break;
			}

			vec3 rayScreenPos = rayClipPos.xyz / rayClipPos.w * 0.5 + 0.5;
			if(rayScreenPos.x <= 0.0 || rayScreenPos.y <= 0.0 || rayScreenPos.x >= 1.0 || rayScreenPos.y >= 1.0){
				break;
			}

			float sampleDepth = texture(depthtex0, rayScreenPos.xy).r;
			if(sampleDepth == 1.0){
				continue;
			}

			vec3 sampleViewPos = getViewPos(rayScreenPos.xy, sampleDepth);
			float depthDiff = sampleViewPos.z - rayViewPos.z;
			float thickness = max(GI_THICKNESS, rayDistance * 0.08);

			if(depthDiff > thickness * GI_HIT_SOFTNESS){
				occlusion += receiverFacing * 0.35;
				break;
			}

			if(depthDiff <= 0.0){
				continue;
			}

			vec3 sampleNormalView = getViewNormal(rayScreenPos.xy);
			float emitterFacing = max(dot(sampleNormalView, -rayDir), 0.0);
			float hitWeight = 1.0 - smoothstep(thickness, thickness * GI_HIT_SOFTNESS, depthDiff);
			float geometryWeight = receiverFacing * (emitterFacing * 0.8 + 0.2);
			float distanceWeight = 1.0 / (1.0 + rayDistance * (1.5 + rayDistance));
			vec2 sampleLightmap = texture(colortex1, rayScreenPos.xy).rg;
#if ENABLE_PHYSICAL_LIGHTING == 1
			vec3 sourceLight = getBlockLightRadiance(sampleLightmap.r) * GI_BLOCK_BOUNCE_STRENGTH;
			sourceLight += getSkylightRadiance(worldTime) * sampleLightmap.g * GI_SKY_BOUNCE_STRENGTH;
			sourceLight += getCaveAmbientRadiance();
#else
			vec3 sourceLight = vec3(max(sampleLightmap.r * GI_BLOCK_BOUNCE_STRENGTH + sampleLightmap.g * GI_SKY_BOUNCE_STRENGTH, 0.08));
#endif
			sourceLight += getSunBounce(sampleViewPos, sampleNormalView, sampleLightmap, sunDirView, sunRadiance);
			float skylightWeight = 1.0 / (max(0.0, sampleLightmap.g - receiverSkylight) * 8.0 + 1.0);
			float weight = geometryWeight * distanceWeight * skylightWeight * hitWeight;

			indirect += shapeBounceColor(texture(colortex0, rayScreenPos.xy).rgb) * sourceLight * weight;
			occlusion += receiverFacing * (1.0 - emitterFacing * 0.5) * hitWeight;
			break;
		}
	}

	vec3 bounce = indirect * (GI_STRENGTH / float(GI_SAMPLES));
	float ao = 1.0 - clamp((occlusion / float(GI_SAMPLES)) * GI_AO_STRENGTH, 0.0, 0.75);
	return vec4(bounce, ao);
}

void main(){
#if ENABLE_GI != 1
	giBuffer = vec4(0.0, 0.0, 0.0, 1.0);
	return;
#endif

	float depth = texture(depthtex0, texcoord).r;
	if(depth == 1.0){
		giBuffer = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	vec3 viewPos = getViewPos(texcoord, depth);
	vec3 normalView = getViewNormal(texcoord);
	vec3 playerPos = getPlayerPos(viewPos);
	float skylight = texture(colortex1, texcoord).g;

	if(!shouldRenderGI(viewPos)){
		giBuffer = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	vec3 sunDirView = normalize(shadowLightPosition);
	vec3 sunRadiance = getSunRadiance(worldTime);
	giBuffer = traceScreenSpaceGI(viewPos + normalView * 0.04, normalView, skylight, playerPos, sunDirView, sunRadiance);

#if GI_DEBUG_RAW == 1
	giBuffer.rgb *= 0.25;
#endif
}
