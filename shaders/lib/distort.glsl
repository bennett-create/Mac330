const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = false;
const bool shadowcolor1Nearest = false;
const bool shadowcolor0Mipmap = true;
const bool shadowcolor1Mipmap = true;

const int shadowMapResolution = 2048; // [1024 2048 4096]
const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize = 4.0;

#define SHADOW_SAMPLES 16 // [8 12 16 24]
#define SHADOW_RADIUS 1.45 // [0.75 1.0 1.25 1.45 1.75 2.25]
#define SHADOW_BIAS 0.00035 // [0.00015 0.00025 0.00035 0.0005 0.00075]
#define SHADOW_SLOPE_BIAS 0.0012 // [0.0004 0.0008 0.0012 0.0018 0.0025]
#define SHADOW_NORMAL_BIAS 0.018 // [0.0 0.01 0.018 0.026 0.04]
#define SHADOW_COMPARE_SOFTNESS 0.00045 // [0.0001 0.00025 0.00045 0.0007 0.001]
#define SHADOW_FILTER_JITTER 0.7 // [0.0 0.35 0.7 1.0]
#define SHADOW_KERNEL_ROTATION 0.0

vec2 distortShadowXY(vec2 shadowPos){
  float distortionFactor = length(shadowPos.xy); // distance from the player in shadow clip space
  distortionFactor += 0.1; // very small distances can cause issues so we add this to slightly reduce the distortion

  return shadowPos.xy / distortionFactor;
}

vec2 distortShadowScreenXY(vec2 shadowScreenPos){
  vec2 shadowNdcPos = shadowScreenPos * 2.0 - 1.0;
  shadowNdcPos = distortShadowXY(shadowNdcPos);
  return shadowNdcPos * 0.5 + 0.5;
}

vec3 distortShadowClipPos(vec3 shadowClipPos){
  shadowClipPos.xy = distortShadowXY(shadowClipPos.xy);
  shadowClipPos.z *= 0.5; // increases shadow distance on the Z axis, which helps when the sun is very low in the sky
  return shadowClipPos;
}
