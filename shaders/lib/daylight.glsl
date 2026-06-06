#ifndef DAYLIGHT_GLSL
#define DAYLIGHT_GLSL

float getDayTick(int time){
	return mod(float(time), 24000.0);
}

float saturate(float value){
	return clamp(value, 0.0, 1.0);
}

float smooth01(float value){
	value = saturate(value);
	return value * value * (3.0 - 2.0 * value);
}

float getLALocalHour(int time){
	float tick = getDayTick(time);

	if(tick <= 6000.0){
		return mix(5.75, 12.85, tick / 6000.0);
	}

	if(tick <= 12000.0){
		return mix(12.85, 20.0, (tick - 6000.0) / 6000.0);
	}

	return mix(20.0, 29.75, (tick - 12000.0) / 12000.0);
}

float getSunKelvin(int time){
	float hour = getLALocalHour(time);

	if(hour < 6.25){
		return mix(2000.0, 3200.0, smoothstep(5.75, 6.25, hour));
	}

	if(hour < 9.0){
		return mix(3200.0, 4700.0, smoothstep(6.25, 9.0, hour));
	}

	if(hour < 12.85){
		return mix(4700.0, 6200.0, smoothstep(9.0, 12.85, hour));
	}

	if(hour < 17.0){
		return mix(6200.0, 4800.0, smoothstep(12.85, 17.0, hour));
	}

	if(hour < 19.0){
		return mix(4800.0, 3500.0, smoothstep(17.0, 19.0, hour));
	}

	if(hour < 20.0){
		return mix(3500.0, 2200.0, smoothstep(19.0, 20.0, hour));
	}

	return 2200.0;
}

vec3 kelvinToRGBFast(float kelvin){
	const vec3 k2000 = vec3(1.000, 0.536, 0.055);
	const vec3 k2500 = vec3(1.000, 0.641, 0.289);
	const vec3 k3200 = vec3(1.000, 0.723, 0.485);
	const vec3 k3500 = vec3(1.000, 0.755, 0.552);
	const vec3 k4700 = vec3(1.000, 0.870, 0.765);
	const vec3 k5500 = vec3(1.000, 0.926, 0.871);
	const vec3 k6200 = vec3(1.000, 0.975, 0.950);

	if(kelvin < 2500.0){
		return mix(k2000, k2500, smoothstep(2000.0, 2500.0, kelvin));
	}

	if(kelvin < 3200.0){
		return mix(k2500, k3200, smoothstep(2500.0, 3200.0, kelvin));
	}

	if(kelvin < 3500.0){
		return mix(k3200, k3500, smoothstep(3200.0, 3500.0, kelvin));
	}

	if(kelvin < 4700.0){
		return mix(k3500, k4700, smoothstep(3500.0, 4700.0, kelvin));
	}

	if(kelvin < 5500.0){
		return mix(k4700, k5500, smoothstep(4700.0, 5500.0, kelvin));
	}

	return mix(k5500, k6200, smoothstep(5500.0, 6200.0, kelvin));
}

float getNoonAmount(int time){
	float tick = min(getDayTick(time), 12000.0);
	float noon = 1.0 - saturate(abs(tick - 6000.0) / 6000.0);
	return smooth01(noon);
}

float getDaylightAmount(int time){
	float tick = getDayTick(time);

	if(tick > 12000.0){
		return 0.0;
	}

	float sunrise = 0.18 + 0.82 * smoothstep(0.0, 1400.0, tick);
	float sunset = 1.0 - smoothstep(10800.0, 12000.0, tick);
	return sunrise * sunset;
}

float getGoldenHourAmount(int time){
	float tick = getDayTick(time);

	if(tick > 12000.0){
		return 0.0;
	}

	float sunriseWarmth = 1.0 - smoothstep(0.0, 1800.0, tick);
	float sunsetWarmth = smoothstep(9600.0, 11200.0, tick) * (1.0 - smoothstep(11800.0, 12000.0, tick));
	return max(sunriseWarmth, sunsetWarmth);
}

float luxToSceneRadiance(float lux){
	return max(lux, 0.0) * (PHYSICAL_LIGHTING_EXPOSURE / PHYSICAL_REFERENCE_LUX);
}

float getSunIlluminanceLux(int time){
	float hour = getLALocalHour(time);

	if(hour < 5.75 || hour > 20.0){
		return 0.0;
	}

	if(hour < 6.25){
		return mix(80.0, 12000.0, smoothstep(5.75, 6.25, hour));
	}

	if(hour < 9.0){
		return mix(12000.0, 65000.0, smoothstep(6.25, 9.0, hour));
	}

	if(hour < 12.85){
		return mix(65000.0, 110000.0, smoothstep(9.0, 12.85, hour));
	}

	if(hour < 17.0){
		return mix(110000.0, 70000.0, smoothstep(12.85, 17.0, hour));
	}

	if(hour < 19.0){
		return mix(70000.0, 18000.0, smoothstep(17.0, 19.0, hour));
	}

	return mix(18000.0, 120.0, smoothstep(19.0, 20.0, hour));
}

float getSkyIlluminanceLux(int time){
	float sunLux = getSunIlluminanceLux(time);
	float noon = getNoonAmount(time);
	float golden = getGoldenHourAmount(time);
	float skyRatio = mix(0.10, 0.16, noon) * mix(1.0, 0.72, golden);
	float twilightLux = 18.0 * golden;
	return sunLux * skyRatio + twilightLux;
}

float getMoonVisibility(int time){
	float tick = getDayTick(time);
	float nightRise = smoothstep(12000.0, 14000.0, tick);
	float dawnFade = 1.0 - smoothstep(22000.0, 24000.0, tick);
	return nightRise * dawnFade;
}

float getMoonIlluminanceLux(int time){
	return 0.25 * getMoonVisibility(time);
}

vec3 getMoonColor(){
	return vec3(0.58, 0.66, 0.82);
}

vec3 getMoonRadiance(int time){
	return getMoonColor() * luxToSceneRadiance(getMoonIlluminanceLux(time));
}

vec3 getCaveAmbientRadiance(){
	return vec3(luxToSceneRadiance(CAVE_AMBIENT_LUX));
}

vec3 getBlockLightRadiance(float blockLight){
	float level = saturate(blockLight);
	float falloff = level * level;
	return vec3(1.0, 0.52, 0.22) * luxToSceneRadiance(BLOCKLIGHT_MAX_LUX * falloff);
}

float getSunBrightness(int time){
#if ENABLE_PHYSICAL_LIGHTING == 1
	return luxToSceneRadiance(getSunIlluminanceLux(time)) * SUNLIGHT_INTENSITY;
#else
#if ENABLE_LIGHT_TEMPERATURE == 1
	float noon = getNoonAmount(time);
	float golden = getGoldenHourAmount(time);
	float daylight = getDaylightAmount(time);
	float brightness = mix(0.52, 1.28, noon);
	brightness *= mix(1.0, 0.82, golden);
	return daylight * brightness * SUNLIGHT_INTENSITY;
#else
	return 1.0;
#endif
#endif
}

vec3 getSunColor(int time){
#if ENABLE_LIGHT_TEMPERATURE == 1
	vec3 kelvinColor = kelvinToRGBFast(getSunKelvin(time));
	return mix(vec3(1.0), kelvinColor, SUN_TEMPERATURE_BLEND);
#else
	return vec3(1.0);
#endif
}

vec3 getSunRadiance(int time){
	return getSunColor(time) * getSunBrightness(time);
}

vec3 getSkylightRadiance(int time){
#if ENABLE_PHYSICAL_LIGHTING == 1
	vec3 daySkyTint = mix(vec3(0.62, 0.78, 1.0), vec3(1.0), getGoldenHourAmount(time) * 0.28);
	vec3 sunSky = getSunColor(time) * daySkyTint * luxToSceneRadiance(getSkyIlluminanceLux(time));
	return sunSky + getMoonRadiance(time);
#else
	vec3 baseSky = vec3(0.05, 0.15, 0.3);

#if ENABLE_LIGHT_TEMPERATURE == 1
	vec3 warmSky = vec3(0.11, 0.13, 0.18) * getSunColor(time);
	float warmth = getGoldenHourAmount(time) * SKYLIGHT_TEMPERATURE_BLEND;
	float daylight = getDaylightAmount(time);
	return mix(baseSky * (0.7 + daylight * 0.3), warmSky, warmth);
#else
	return baseSky;
#endif
#endif
}

float getSunShadowSoftness(int time){
#if ENABLE_LIGHT_TEMPERATURE == 1
	return mix(1.65, 0.72, getNoonAmount(time));
#else
	return 1.0;
#endif
}

#endif
