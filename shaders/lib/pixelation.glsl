#ifndef PIXELATION_GLSL
#define PIXELATION_GLSL

#include "/lib/settings.glsl"

const float PIXELATED_SHADOW_TEXEL_SCALE = 1.0;
const float PIXELATED_SHADOW_OFFSET_RANGE = 64.0;
const float PIXELATED_SHADOW_BLOCK_GRID = 16.0;

vec2 computePixelatedShadowTexelOffset(vec2 uv, vec4 texelSize){
	vec2 uvCenter = (floor(uv * texelSize.zw) + 0.5) * texelSize.xy;
	vec2 dUV = uvCenter - uv;
	vec2 dUVdS = dFdx(uv);
	vec2 dUVdT = dFdy(uv);

	if(abs(dUVdS.x) + abs(dUVdS.y) + abs(dUVdT.x) + abs(dUVdT.y) <= 0.000001){
		return vec2(0.0);
	}

	float determinant = dUVdS.x * dUVdT.y - dUVdT.x * dUVdS.y;
	if(abs(determinant) <= 0.000001){
		return vec2(0.0);
	}

	float invDeterminant = 1.0 / determinant;
	mat2 dSTdUV = mat2(dUVdT.y, -dUVdT.x, -dUVdS.y, dUVdS.x) * invDeterminant;
	return clamp(dUV * dSTdUV, vec2(-PIXELATED_SHADOW_OFFSET_RANGE), vec2(PIXELATED_SHADOW_OFFSET_RANGE));
}

vec2 computePixelatedShadowTexelOffset(sampler2D tex, vec2 uv){
	vec2 texSize = vec2(textureSize(tex, 0)) * PIXELATED_SHADOW_TEXEL_SCALE;
	return computePixelatedShadowTexelOffset(uv, vec4(1.0 / texSize, texSize));
}

vec2 encodePixelatedShadowOffset(vec2 offset){
	return clamp(offset / (PIXELATED_SHADOW_OFFSET_RANGE * 2.0) + 0.5, 0.0, 1.0);
}

vec2 decodePixelatedShadowOffset(vec2 encodedOffset){
	return (encodedOffset * 2.0 - 1.0) * PIXELATED_SHADOW_OFFSET_RANGE;
}

vec3 pixelatedShadowTexelSnap(vec3 value, vec2 texelOffset){
	if(abs(texelOffset.x) + abs(texelOffset.y) <= 0.000001){
		return value;
	}

	vec3 valueOffset = dFdx(value) * texelOffset.x + dFdy(value) * texelOffset.y;
	valueOffset = clamp(valueOffset, vec3(-1.0), vec3(1.0));
	return value + valueOffset;
}

float pixelatedShadowAxisAlignedWeight(vec3 normal){
	vec3 absNormal = abs(normalize(normal));
	float dominantAxis = max(absNormal.x, max(absNormal.y, absNormal.z));
	return smoothstep(0.75, 0.95, dominantAxis);
}

vec3 pixelatedShadowBlockGridSnap(vec3 playerPos, vec3 normal, vec3 cameraPosition){
	vec3 worldPos = playerPos + cameraPosition;
	vec3 absNormal = abs(normalize(normal));
	vec3 snappedWorldPos = worldPos;

	if(absNormal.y >= absNormal.x && absNormal.y >= absNormal.z){
		snappedWorldPos.xz = (floor(worldPos.xz * PIXELATED_SHADOW_BLOCK_GRID) + PIXELATED_SHADOW_GRID_PHASE) / PIXELATED_SHADOW_BLOCK_GRID;
	}else if(absNormal.x >= absNormal.z){
		snappedWorldPos.yz = (floor(worldPos.yz * PIXELATED_SHADOW_BLOCK_GRID) + PIXELATED_SHADOW_GRID_PHASE) / PIXELATED_SHADOW_BLOCK_GRID;
	}else{
		snappedWorldPos.xy = (floor(worldPos.xy * PIXELATED_SHADOW_BLOCK_GRID) + PIXELATED_SHADOW_GRID_PHASE) / PIXELATED_SHADOW_BLOCK_GRID;
	}

	return snappedWorldPos - cameraPosition;
}

#endif
