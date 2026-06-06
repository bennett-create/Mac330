#ifndef ATMOSPHERE_GLSL
#define ATMOSPHERE_GLSL

#include "/lib/settings.glsl"
#include "/lib/daylight.glsl"

vec3 getAtmosphereUpDirection(mat4 modelView){
	return normalize(modelView[1].xyz);
}

float getAtmosphereTwilightAmount(int time){
	float tick = getDayTick(time);
	float dawn = 1.0 - smoothstep(0.0, 1800.0, tick);
	float dusk = smoothstep(10200.0, 12000.0, tick) * (1.0 - smoothstep(12000.0, 14000.0, tick));
	return max(dawn, dusk);
}

vec3 getAtmosphereColorCore(vec3 viewDir, vec3 sunDir, vec3 upDir, int time, float includeSunDisk){
	viewDir = normalize(viewDir);
	sunDir = normalize(sunDir);
	upDir = normalize(upDir);

	float mu = clamp(dot(viewDir, sunDir), -1.0, 1.0);
	float viewY = clamp(dot(viewDir, upDir), -0.08, 1.0);
	float sunY = clamp(dot(sunDir, upDir), -0.08, 1.0);
	float daylight = getDaylightAmount(time);
	float twilight = getAtmosphereTwilightAmount(time);
	float skyLight = clamp(daylight + twilight * 0.35, 0.0, 1.0);
	float lowSun = 1.0 - smoothstep(0.02, 0.45, sunY);
	float aboveHorizon = saturate(viewY * 1.08 + 0.03);
	float horizon = pow(1.0 - aboveHorizon, 2.25);
	float airMass = clamp(1.0 / (aboveHorizon * 0.92 + 0.08), 1.0, 10.0);
	float towardSun = pow(saturate(mu * 0.5 + 0.5), 2.0);

	vec3 sunColor = getSunColor(time);
	vec3 zenithBlue = mix(vec3(0.012, 0.035, 0.12), vec3(0.11, 0.30, 0.82), saturate(sunY * 1.35 + 0.30));
	vec3 horizonBlue = mix(vec3(0.08, 0.11, 0.18), vec3(0.55, 0.70, 0.94), saturate(sunY * 1.15 + 0.35));
	vec3 sunsetColor = sunColor * vec3(1.20, 0.52, 0.22);
	vec3 horizonColor = mix(horizonBlue, sunsetColor, lowSun * (0.32 + 0.68 * towardSun));

	float rayleighPhase = 0.55 + 0.45 * mu * mu;
	vec3 sky = mix(zenithBlue, horizonColor, horizon) * rayleighPhase;

	vec3 extinction = exp(-airMass * mix(vec3(0.05, 0.028, 0.010), vec3(0.20, 0.11, 0.040), lowSun));
	sky *= mix(vec3(1.0), extinction * vec3(1.35, 1.12, 0.95), horizon * lowSun);

	float g = 0.76;
	float miePhase = (1.0 - g * g) / pow(max(0.10, 1.0 + g * g - 2.0 * g * mu), 1.5);
	float forwardGlow = pow(saturate(mu), mix(12.0, 46.0, saturate(sunY)));
	vec3 mie = sunColor * (miePhase * 0.024 + forwardGlow * (0.18 + 1.15 * lowSun));
	sky += mie * ATMOSPHERE_HAZE * skyLight;

	float horizonBand = exp(-abs(viewY) * 10.0);
	sky += sunsetColor * horizonBand * towardSun * twilight * 0.55;

	vec3 nightSky = mix(vec3(0.004, 0.006, 0.014), vec3(0.013, 0.022, 0.050), horizon);
	sky = mix(nightSky, sky, skyLight);

	float sunDisk = smoothstep(0.99982, 0.99996, mu) * smoothstep(-0.025, 0.08, sunY);
	sky += sunColor * sunDisk * getSunBrightness(time) * SUN_DISK_INTENSITY * includeSunDisk;

	vec3 moonDir = -sunDir;
	float moonY = clamp(dot(moonDir, upDir), -0.08, 1.0);
	float moonMu = clamp(dot(viewDir, moonDir), -1.0, 1.0);
	float nightVisibility = (1.0 - saturate(daylight + twilight * 0.65)) * smoothstep(-0.02, 0.10, moonY);
	float moonDisk = smoothstep(0.99970, 0.99992, moonMu);
	float moonGlow = pow(saturate(moonMu), 90.0);
	vec3 moonColor = vec3(0.58, 0.66, 0.82);
	sky += moonColor * nightVisibility * includeSunDisk * (moonDisk * MOON_DISK_INTENSITY + moonGlow * 0.045);

	return max(sky * SKY_EXPOSURE, vec3(0.0));
}

vec3 getAtmosphereColor(vec3 viewDir, vec3 sunDir, vec3 upDir, int time){
#if ENABLE_REALISTIC_SKY == 1
	return getAtmosphereColorCore(viewDir, sunDir, upDir, time, 1.0);
#else
	return vec3(0.0);
#endif
}

vec3 getAtmosphereSkylight(vec3 sunDir, vec3 upDir, int time){
#if ENABLE_REALISTIC_SKY == 1
#if ENABLE_PHYSICAL_LIGHTING == 1
	return getSkylightRadiance(time);
#else
	vec3 zenith = getAtmosphereColorCore(upDir, sunDir, upDir, time, 0.0);
	vec3 sunSide = getAtmosphereColorCore(normalize(upDir + sunDir * 0.45), sunDir, upDir, time, 0.0);
	return max((zenith * 0.62 + sunSide * 0.38) * 0.42, vec3(0.012));
#endif
#else
	return getSkylightRadiance(time);
#endif
}

#endif
