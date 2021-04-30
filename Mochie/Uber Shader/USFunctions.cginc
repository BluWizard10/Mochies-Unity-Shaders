#ifndef US_FUNCTIONS_INCLUDED
#define US_FUNCTIONS_INCLUDED

#if !X_FEATURES
float GetPackedAudioLinkBand(float4 al, int band){
	float value = 1;
	switch (band){
		case 0: value = al.x; break;
		case 1: value = al.y; break;
		case 2: value = al.z; break;
		case 3: value = al.w; break;
		default: break;
	}
	return value;
}

float GetAudioLinkBand(audioLinkData al, int band){
	float value = 1;
	switch (band){
		case 0: value = al.bass; break;
		case 1: value = al.lowMid; break;
		case 2: value = al.upperMid; break;
		case 3: value = al.treble; break;
		default: break;
	}
	return value;
}
#endif

//----------------------------
// Color Filtering
//----------------------------

void ApplyGeneralFilters(inout float3 albedo){
    albedo = GetSaturation(albedo, _Saturation);
    albedo = lerp(albedo, GetHDR(albedo), _HDR);
    albedo = GetContrast(albedo, _Contrast);
    albedo *= _Brightness;
}

float3 GetTeamColors(masks m, float3 albedo){;

	// Alloy team colors implementation
	if (_TeamFiltering == 1){
		float3 baseCol = albedo;
		float weight = dot(m.teamMask, float4(1.0h, 1.0h, 1.0h, 1.0h));
		m.teamMask /= max(1.0h, weight);
		float3 teamColor = _TeamColor0 * m.teamMask.r 
						+ _TeamColor1 * m.teamMask.g 
						+ _TeamColor2 * m.teamMask.b 
						+ _TeamColor3 * m.teamMask.a 
						+ saturate(1.0h - weight).rrr;
		albedo *= teamColor;
		albedo = baseCol + 2 * (albedo-baseCol);
	}
	return albedo;
}

void ApplyFiltering(g2f i, masks m, inout float3 albedo){
	float3 rgb = GetTeamColors(m, albedo) * _RGB;
	_Hue += lerp(0, frac(_Time.y*_AutoShiftSpeed), _AutoShift);
	float3 hsv = HSVShift(rgb, _Hue, 0, 0);
	ApplyGeneralFilters(hsv);
	albedo = lerp(albedo, hsv, m.filterMask);
}

//------------------------------------
// Albedo
//------------------------------------

void ApplyCutout(g2f i, float2 screenUV, inout float4 albedo){
	if (_BlendMode == 1){
		albedo.a = (albedo.a - _Cutoff) / max(fwidth(albedo.a), 0.0001) + 0.5;
	}
	else if (_BlendMode == 2){
		clip(Dither(screenUV, albedo.a));
	}
}

float2 ScaleUV(float2 uv, float2 pos,  float2 scale, float rot){
	uv -= pos + 0.5;
	uv = Rotate2D(uv, rot) + 0.5;
	uv = (uv - 0.5) / scale + 0.5;
    return uv;
}

bool FrameClip(float2 uv, float2 rowsColumns, float2 fco){
	float2 size = float2(1/rowsColumns.x, 1/rowsColumns.y)-fco;
	bool xClip = uv.x < size.x || uv.x > 1-size.x;
	bool yClip = uv.y < size.y || uv.y > 1-size.y;
	return !(xClip || yClip);
}

float3 GetSpritesheetUV(float2 uv, float2 rowsColumns, float scrubPos, float fps, int manualScrub){
	float2 size = float2(1/rowsColumns.x, 1/rowsColumns.y);
	uint totalFrames = rowsColumns.x * rowsColumns.y;
	uint index = 0;

	index = lerp(_Time.y*fps, scrubPos, manualScrub);

	uint indexX = index % rowsColumns.x;
	uint indexY = floor((index % totalFrames) / rowsColumns.x);
	float2 offset = float2(size.x*indexX,-size.y*indexY);
	float2 uv1 = uv*size;
	uv1.y = uv1.y + size.y*(rowsColumns.y - 1);
	uv = uv1 + offset;
	return float3(uv,0);
}

float3 GetFlipbookUV(Texture2DArray tex2da, float2 uv, float scrubPos, float fps, int manualScrub){
	float width, height, elements;
	tex2da.GetDimensions(width, height, elements);
	uint arrayIndex = frac(_Time.y*fps*(1/elements))*elements;
	uint index = lerp(arrayIndex, scrubPos, manualScrub);
	return float3(uv, index);
}

float4 GetSpritesheetColor(g2f i, 
		Texture2D tex, UNITY_ARGS_TEX2DARRAY(tex2da), float4 spriteColor,
		float2 pos, float2 scale, float2 rowsColumns, float2 fco, 
		float rot, float scrubPos, float fps, float brightness, int manualScrub, int mode
	) {
	float2 scaledUV = ScaleUV(i.rawUV, pos, scale, rot);
	float3 uv = lerp(
		GetFlipbookUV(tex2da, scaledUV, scrubPos, fps, manualScrub), 
		GetSpritesheetUV(scaledUV, rowsColumns, scrubPos, fps, manualScrub), 
		mode
	);
	float4 col = 0;
	UNITY_BRANCH
	if (mode == 1){
		col = UNITY_SAMPLE_TEX2D_SAMPLER(tex, _MainTex, uv.xy) * spriteColor * brightness * FrameClip(scaledUV, rowsColumns, fco);
	}
	else {
		col = UNITY_SAMPLE_TEX2DARRAY(tex2da, uv) * spriteColor * brightness;
	}
	return col;
}

void ApplySpritesheetBlending(g2f i, inout float4 col, float4 gifCol, int blendMode){

	if (blendMode == 0){
		col.rgb += (gifCol.rgb * gifCol.a); 
	}
	else if (blendMode == 1){
		col.rgb *= lerp(1, gifCol.rgb, gifCol.a);
	}
	else col.rgb = lerp(col.rgb, gifCol.rgb, gifCol.a);

	if (_UseSpritesheetAlpha == 1){
		col.a = gifCol.a;
		#if ALPHA_TEST
			if (_BlendMode != 2)
				clip(col.a - _Cutoff);
		#endif
	}
}

void ApplySpritesheet0(g2f i, inout float4 col){
	float4 spriteCol = GetSpritesheetColor(i, 
		_Spritesheet,
		UNITY_PASS_TEX2DARRAY(_Flipbook0),
		_SpritesheetCol,
		_SpritesheetPos,
		_SpritesheetScale,
		_RowsColumns,
		_FrameClipOfs,
		_SpritesheetRot,
		_ScrubPos,
		_FPS,
		_SpritesheetBrightness,
		_ManualScrub,
		_SpritesheetMode0
	);
	ApplySpritesheetBlending(i, col, spriteCol, _SpritesheetBlending);
}

void ApplySpritesheet1(g2f i, inout float4 col){
	float4 spriteCol = GetSpritesheetColor(i, 
		_Spritesheet1,
		UNITY_PASS_TEX2DARRAY(_Flipbook1),
		_SpritesheetCol1,
		_SpritesheetPos1,
		_SpritesheetScale1,
		_RowsColumns1,
		_FrameClipOfs1,
		_SpritesheetRot1,
		_ScrubPos1,
		_FPS1,
		_SpritesheetBrightness1,
		_ManualScrub1,
		_SpritesheetMode1
	);
	ApplySpritesheetBlending(i, col, spriteCol, _SpritesheetBlending1);
}


void ApplyRefraction(g2f i, lighting l, masks m, inout float3 albedo){
	float2 screenUV = GetGrabPos(i.grabPos);
	float2 IOR = (_RefractionIOR-1) * mul(UNITY_MATRIX_V, float4(l.normal, 0));
	float2 offset = ((1/(i.grabPos.z + 1) * IOR)) * (1-dot(l.normal, l.viewDir));
	offset = float2(offset.x, -(offset.y * _ProjectionParams.x));

	float2 refractUV = screenUV + offset;
	#if REFRACTION_CA_ENABLED
		float2 uvG = screenUV + (offset * (1 + _RefractionCAStr));
		float2 uvB = screenUV + (offset * (1 - _RefractionCAStr));
		float chromR = UNITY_SAMPLE_TEX2D_LOD_SAMPLER(_SSRGrab, _MainTex, float4(refractUV,0,0)).r;
		float chromG = UNITY_SAMPLE_TEX2D_LOD_SAMPLER(_SSRGrab, _MainTex, float4(uvG,0,0)).g;
		float chromB = UNITY_SAMPLE_TEX2D_LOD_SAMPLER(_SSRGrab, _MainTex, float4(uvB,0,0)).b;
		float3 refractionCol = float3(chromR, chromG, chromB);
	#else
		float3 refractionCol = UNITY_SAMPLE_TEX2D_LOD_SAMPLER(_SSRGrab, _MainTex, float4(refractUV,0,0));
	#endif
	float alpha = step(m.refractDissolveMask, _RefractionDissolveMaskStr);
	refractionCol = lerp(albedo, refractionCol * _RefractionTint, alpha * m.refractMask);
	albedo = lerp(refractionCol, albedo, _RefractionOpac);
}

void ApplyBCDissolve(g2f i, audioLinkData al, inout float4 albedo, out float3 bcRimColor){
	bcRimColor = 0;
	#if BCDISSOLVE_ENABLED
		float2 texUV = TRANSFORM_TEX(i.rawUV, _MainTex2);
		float2 noiseUV = TRANSFORM_TEX(i.rawUV, _BCNoiseTex);
		float4 albedo2 = UNITY_SAMPLE_TEX2D_SAMPLER(_MainTex2, _MainTex, texUV) * _BCColor;
		float noise = UNITY_SAMPLE_TEX2D_SAMPLER(_BCNoiseTex, _MainTex, noiseUV);
		#if AUDIOLINK_ENABLED
			float bcDissolveValueAL = GetAudioLinkBand(al, _AudioLinkBCDissolveBand);
			_BCDissolveStr *= lerp(1, bcDissolveValueAL, _AudioLinkBCDissolveMultiplier);
		#endif
		float dissolveStr = noise - _BCDissolveStr;
		float rimInner = step(dissolveStr, _BCRimWidth*0.035);
		float rimOuter = step(dissolveStr+_BCRimWidth*0.035, _BCRimWidth*0.035);
		float3 rim = (rimInner - rimOuter) * _BCRimCol;
		albedo = lerp(albedo2, albedo, ceil(dissolveStr));
		bcRimColor = rim * _BCRimCol.a;
	#endif
}

float3 BlendCubemap(float3 baseCol, float3 cubeCol, float blend, int blendMode){
	switch (blendMode){
		case 0: baseCol = lerp(baseCol, cubeCol, blend); break;
		case 1: baseCol += cubeCol * blend; break;
		case 2: baseCol -= cubeCol * blend; break;
		case 3: baseCol *= lerp(1, cubeCol, blend); break;
		default: break;
	}
	return baseCol;
}

float3 GetDetailAlbedo(g2f i, float3 alIn){
	float3 detailAlbedo = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailAlbedoMap, _MainTex, i.uv2.xy);
	float3 alOut = 0;
	switch (_DetailAlbedoBlending){
		case 0: alOut = lerp(alIn, detailAlbedo, 0.5); break;
		case 1: alOut = alIn + detailAlbedo; break;
		case 2: alOut = alIn - detailAlbedo; break;
		case 3: alOut = alIn * detailAlbedo; break;
		case 4: alOut = alIn * detailAlbedo * unity_ColorSpaceDouble; break;
		case 5: alOut = BlendOverlay(detailAlbedo, alIn); break;
		case 6: alOut = BlendScreen(detailAlbedo, alIn); break;		
	}
	return alOut;
}

float4 GetAlbedo(g2f i, lighting l, masks m, audioLinkData al){
	float4 mainTex = UNITY_SAMPLE_TEX2D(_MainTex, i.uv.xy);
	#if REFRACTION_ENABLED
		if (_UnlitRefraction == 0)
			ApplyRefraction(i, l, m, mainTex.rgb);
	#endif
	float4 albedo = 1;
	cubeMask = 1;
	
	#if !CUBEMAP_ENABLED && !COMBINED_CUBEMAP_ENABLED
		albedo = mainTex;
		float4 mirrorTex = UNITY_SAMPLE_TEX2D_SAMPLER(_MirrorTex, _MainTex, i.uv.xy);
		if (i.isReflection && _MirrorBehavior == 2)
			albedo = mirrorTex;
		albedo *= _Color;

	#elif CUBEMAP_ENABLED
		albedo = mainTex * 2;
		_CubeRotate0 = lerp(_CubeRotate0, _CubeRotate0 *_Time.y, _AutoRotate0);
		float3 vDir = Rotate(l.viewDir, _CubeRotate0);
		albedo = texCUBE(_MainTexCube0, vDir);
		albedo *= _CubeColor0;

	#elif COMBINED_CUBEMAP_ENABLED
		_CubeRotate0 = lerp(_CubeRotate0, _CubeRotate0 *_Time.y, _AutoRotate0);
		float3 vDir = Rotate(l.viewDir, _CubeRotate0);
		float4 albedo0 = mainTex;
		float4 mirrorTex = UNITY_SAMPLE_TEX2D_SAMPLER(_MirrorTex, _MainTex, i.uv.xy);
		if (i.isReflection && _MirrorBehavior == 2)
			albedo0 = mirrorTex;
		float4 albedo1 = texCUBE(_MainTexCube0, vDir);
		albedo0 *= _Color;
		albedo1 *= _CubeColor0;
		cubeMask = lerp(str, UNITY_SAMPLE_TEX2D_SAMPLER(tex, _MainTex, uv).r, _IsCubeBlendMask); 
		albedo.rgb = BlendCubemap(albedo0, albedo1, cubeMask, _CubeBlendMode);
	#endif

	ApplyBCDissolve(i, al, albedo, bcRimColor);

	#if SHADING_ENABLED
		float detailInterp = _DetailAlbedoStrength * m.detailMask * _UsingDetailAlbedo;
		albedo.rgb = lerp(albedo.rgb, GetDetailAlbedo(i, albedo.rgb), detailInterp);
	#endif

	#if NON_OPAQUE_RENDERING
		if (_UseAlphaMask == 1){
			float2 alphaMaskUV = TRANSFORM_TEX(i.rawUV, _AlphaMask);
			float alphaMask = UNITY_SAMPLE_TEX2D_SAMPLER(_AlphaMask, _MainTex, alphaMaskUV) * _Color.a;
			albedo.a = alphaMask;
		}
	#endif

	#if SPRITESHEETS_ENABLED
		if (_EnableSpritesheet == 1 && _UnlitSpritesheet == 0)
			ApplySpritesheet0(i, albedo);
		if (_EnableSpritesheet1 == 1 && _UnlitSpritesheet1 == 0)
			ApplySpritesheet1(i, albedo);
	#endif

	#if FILTERING_ENABLED
		albedo.rgb = lerp(albedo.rgb, smootherstep(1,0,albedo.rgb), _Invert);
		#if !POST_FILTERING_ENABLED
			ApplyFiltering(i, m, albedo.rgb);
		#endif
	#endif

    return albedo;
}

//----------------------------
// Audio Link
//----------------------------
bool GrabExists(){
	float width = 0;
	float height = 0;
	_AudioTexture.GetDimensions(width, height);
	return width > 16;
}

float SampleAudioTexture(float time, float band){
	return UNITY_SAMPLE_TEX2D_LOD_SAMPLER(_AudioTexture, _MainTex, float4(time, band,0,0));
}

void InitializeAudioLink(inout audioLinkData al, float time){
	if (GrabExists()){
		al.bass = SampleAudioTexture(time, 0.125);
		al.lowMid = SampleAudioTexture(time, 0.375);
		al.upperMid = SampleAudioTexture(time, 0.625);
		al.treble = SampleAudioTexture(time, 0.875);
	}
	else if (_AudioLinkPreview == 1){
		al.bass = 1-frac(_Time.y*1.5);						// Reverse saw for kick
		al.lowMid = 0.5*(sin(_Time.y*3)+1);				// Sin for bassy lower-mids
		al.upperMid = frac(_Time.y*3);					// Saw for harsher high-mids
		al.treble = round((sin(_Time.y*15)+1)*0.5);		// Flashy square for high hats
	}
}

//----------------------------
// Emission/Rim
//----------------------------
float GetPulse(g2f i){
	float pulse = 1;
	switch (_PulseWaveform){
		case 0: pulse = 0.5*(sin(_Time.y * _PulseSpeed)+1); break; 			// Sin
		case 1: pulse = round((sin(_Time.y * _PulseSpeed)+1)*0.5); break; 	// Square
		case 2: pulse = abs((_Time.y * (_PulseSpeed * 0.333)%2)-1); break; 	// Triangle
		case 3: pulse = frac(_Time.y * (_PulseSpeed * 0.2)); break; 		// Saw
		case 4: pulse = 1-frac(_Time.y * (_PulseSpeed * 0.2)); break; 		// Reverse Saw
		default: break;
	}
	float mask = UNITY_SAMPLE_TEX2D_SAMPLER(_PulseMask, _MainTex, i.uv.xy);
	pulse = lerp(1, pulse, _PulseStr*mask);
	return pulse;
}

float3 GetEmission(g2f i, masks m, audioLinkData al){
	float3 emiss = UNITY_SAMPLE_TEX2D(_EmissionMap, i.uv.zw).rgb * _EmissionColor.rgb;
	emiss *= m.emissMask;
	#if !OUTLINE_PASS
		#if PULSE_ENABLED
			emiss *= GetPulse(i);
		#endif
		#if AUDIOLINK_ENABLED
			float emissValueAL = GetAudioLinkBand(al, _AudioLinkEmissionBand);
			emiss *= lerp(1, emissValueAL, _AudioLinkEmissionMultiplier);
		#endif
	#endif
	return emiss * _EmissIntensity;
}

float GetRim(lighting l, float width){
	float VdotL = abs(dot(l.viewDir, l.normal));
	float rim = pow((1-VdotL), (1-width) * 10);
	rim = smoothstep(_RimEdge, 1-_RimEdge, rim);
	#if AUDIOLINK_ENABLED
		audioLinkData ral = (audioLinkData)0;
		InitializeAudioLink(ral, 1-VdotL);
		float pulseValueAL = 1-GetAudioLinkBand(ral, _AudioLinkRimBand);
		float pulseRim = pow((1-pulseValueAL), (1-_AudioLinkRimPulseWidth) * 10);
		pulseRim = smoothstep(_AudioLinkRimPulseSharp, 1-_AudioLinkRimPulseSharp, pulseRim);
		rim += (pulseRim * _AudioLinkRimPulse);
	#endif
	return rim;
}

void ApplyRimLighting(g2f i, lighting l, masks m, audioLinkData al, inout float3 diffuse){
	#if AUDIOLINK_ENABLED
		float rimValueAL = GetAudioLinkBand(al, _AudioLinkRimBand);
		_RimWidth *= lerp(1, rimValueAL, _AudioLinkRimWidth);
	#endif
	float rim = GetRim(l, _RimWidth);
	rim *= m.rimMask;
	float3 rimCol = UNITY_SAMPLE_TEX2D_SAMPLER(_RimTex, _MainTex, i.uv2.zw).rgb * _RimCol.rgb;
	float interpolator = rim*_RimStr*lerp(l.worldBrightness, 1, _UnlitRim);
	#if AUDIOLINK_ENABLED
		interpolator *= lerp(1, rimValueAL, _AudioLinkRimMultiplier);
	#endif
	switch (_RimBlending){
		case 0: diffuse = lerp(diffuse, rimCol, interpolator); break;
		case 1: diffuse += rimCol*interpolator; break;
		case 2: diffuse -= rimCol*interpolator; break;
		case 3: diffuse *= lerp(1, rimCol, interpolator); break;
	}
}

//----------------------------
// Workflows
//----------------------------
float GetDetailRough(g2f i, float roughIn){
	float detailRough = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailRoughnessMap, _MainTex, i.uv2.xy);
	float roughOut = 0;
	switch (_DetailRoughBlending){
		case 0: roughOut = lerp(roughIn, detailRough, 0.5); break;
		case 1: roughOut = roughIn + detailRough; break;
		case 2: roughOut = roughIn - detailRough; break;
		case 3: roughOut = roughIn * detailRough; break;
		case 4: roughOut = BlendOverlay(detailRough, roughIn); break;
		case 5: roughOut = BlendScreen(detailRough, roughIn); break;
		default: break;
	}
	return roughOut;
}

float3 GetMetallicWorkflow(g2f i, lighting l, masks m, float3 albedo){

	metallic = lerp(_Metallic, UNITY_SAMPLE_TEX2D_SAMPLER(_MetallicGlossMap, _MainTex, i.uv.xy), _UseMetallicMap);
	roughness = lerp(_Glossiness, UNITY_SAMPLE_TEX2D_SAMPLER(_SpecGlossMap, _MainTex, i.uv.xy), _UseSpecMap);
	roughness = lerp(roughness, GetDetailRough(i, roughness), _DetailRoughStrength * m.detailMask * _UsingDetailRough);
	#if CURVATURE_ENABLED
		roughness = _CurvatureTarget == 2 && _UseCurvature == 1 ? BlendCurvature(curvature, roughness) : roughness;
	#endif
	ApplyPBRFiltering(roughness, _RoughContrast, _RoughIntensity, _RoughLightness, _RoughnessFiltering, prevRough);

	smoothness = 1-roughness;
	specularTint = lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
	omr = unity_ColorSpaceDielectricSpec.a - metallic * unity_ColorSpaceDielectricSpec.a;
	#if REFLECTIONS_ENABLED
		float reflStr = 1;
		reflStr = _ReflectionStr*m.reflectionMask;
		return lerp(albedo, albedo*omr, reflStr);
	#else
		return albedo;
	#endif
}

float3 GetSpecWorkflow(g2f i, lighting l, masks m, float3 albedo){
	if (_UseSpecMap == 1){
		float4 specMap = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecGlossMap, _MainTex, i.uv.xy);
		specularTint = specMap.rgb;
		if (_PBRWorkflow == 1){
			if (_UseSmoothMap == 1){
				smoothness = UNITY_SAMPLE_TEX2D_SAMPLER(_SmoothnessMap, _MainTex, i.uv.xy).r * _GlossMapScale;
				ApplyPBRFiltering(smoothness, _SmoothContrast, _SmoothIntensity, _SmoothLightness, _SmoothnessFiltering, prevSmooth);
			}
			else smoothness = _GlossMapScale;
		}
		else {
			smoothness = specMap.a * _GlossMapScale;
			ApplyPBRFiltering(smoothness, _SmoothContrast, _SmoothIntensity, _SmoothLightness, _SmoothnessFiltering, prevSmooth);
		}
	}
	else {
		specularTint = _SpecCol.rgb;
		smoothness = _GlossMapScale;
	}
	
	omr = 1-max(max(specularTint.r, specularTint.g), specularTint.b);
	albedo = albedo * (float3(1,1,1) - specularTint);
	return albedo;
}

void InitializeModularChannels(){
	metallic = ChannelCheck(packedTex, _MetallicChannel);
	roughness = ChannelCheck(packedTex, _RoughnessChannel);
}

void InitializeBakedChannels(){
	metallic = packedTex.r;
	roughness = packedTex.g;
}

float3 GetPackedWorkflow(g2f i, lighting l, masks m, float3 albedo){
	roughness = lerp(roughness, GetDetailRough(i, roughness), _DetailRoughStrength * m.detailMask * _UsingDetailRough);

	ApplyPBRFiltering(roughness, _RoughContrast, _RoughIntensity, _RoughLightness, _RoughnessFiltering, prevRough);

	smoothness = 1-roughness;
	specularTint = lerp(unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
	omr = unity_ColorSpaceDielectricSpec.a - metallic * unity_ColorSpaceDielectricSpec.a;
	
	#if REFLECTIONS_ENABLED
		float reflStr = 1;
		reflStr = _ReflectionStr*m.reflectionMask;
		return lerp(albedo, albedo*omr, reflStr);
	#else
		return albedo;
	#endif
	
}

float3 GetWorkflow(g2f i, lighting l, masks m, float3 albedo){
	float3 diffuse = albedo;
	#if !SPECULAR_WORKFLOW && !PACKED_WORKFLOW && !PACKED_WORKFLOW_BAKED
		diffuse = GetMetallicWorkflow(i, l, m, albedo);
	#elif SPECULAR_WORKFLOW
		diffuse = GetSpecWorkflow(i, l, m, albedo);
	#elif PACKED_WORKFLOW
		InitializeModularChannels();
		diffuse = GetPackedWorkflow(i, l, m, albedo);
	#elif PACKED_WORKFLOW_BAKED
		InitializeBakedChannels();
		diffuse = GetPackedWorkflow(i, l, m, albedo);
	#endif
	return diffuse;
}

// PBR filtering previews
void ApplyRoughPreview(inout float3 diffuse){
	diffuse = lerp(diffuse, prevRough, _RoughnessFiltering * _PreviewRough);
}

void ApplySmoothPreview(inout float3 diffuse){
	diffuse = lerp(diffuse, prevSmooth, _SmoothnessFiltering * _PreviewSmooth);
}

void ApplyAOPreview(inout float3 diffuse){
	diffuse = lerp(diffuse, prevAO, _AOFiltering * _PreviewAO);
}

void ApplyHeightPreview(inout float3 diffuse){
	#if PARALLAX_ENABLED
		diffuse = lerp(diffuse, prevHeight, _HeightFiltering * _PreviewHeight);
	#endif
}

//----------------------------
// UV Distortion
//----------------------------
float2 GetTorusOffset(float2 uv) {
    // translated to hlsl and modified from https://www.shadertoy.com/view/Md3Bz7
    // http://web.cs.ucdavis.edu/~amenta/s12/findnorm.pdf
    float phi = UNITY_TWO_PI*uv.x;
    float theta = UNITY_TWO_PI*uv.y;
    float3 c = cos(float3(phi, phi + UNITY_HALF_PI, theta));
    float2 result = float2(c.x*c.z,-c.y*c.z);
    return result * 0.5 + 0.5;  
}

float2 GetSimplexOffset(g2f i){
	float xOfs = GetSimplex3D(i.rawUV.xy, _NoiseScale, _Time.y*_NoiseSpeed, _NoiseOctaves) * _DistortUVStr;
	float yOfs = GetSimplex3D(i.rawUV.xy, _NoiseScale, (_Time.y+43.423984)*_NoiseSpeed, _NoiseOctaves) * _DistortUVStr;
	return float2(xOfs, yOfs);
}

float3 GetUVOffset(g2f i){

	_DistortUVStr *= UNITY_SAMPLE_TEX2D_SAMPLER(_DistortUVMask, _MainTex, i.uv.xy);
	float3 ofs = 0;

	#if UV_DISTORTION_NORMALMAP
		ofs = UnpackScaleNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_DistortUVMap, _MainTex, i.uv3.xy), _DistortUVStr);
	#else
		ofs.xy = GetSimplexOffset(i);
	#endif

	ofs *= 0.1;
	uvOffsetOut = ofs;
	
	return ofs;
}

void ApplyUVDistortion(inout g2f i, inout float3 uvOffset){
	uvOffset = GetUVOffset(i);
	i.uv.xy += uvOffset.xy * _DistortMainUV;
	i.uv.zw += uvOffset.xy * _DistortEmissUV;
	i.uv2.xy += uvOffset.xy * _DistortDetailUV;
	i.uv2.zw += uvOffset.xy * _DistortRimUV;
}

//----------------------------
// Parallax Mapping
//----------------------------
float2 GetParallaxOffset(g2f i){
    float2 uvOffset = 0;
	float2 prevUVOffset = 0;
	float stepSize = 1.0/15.0;
	float stepHeight = 1;
	float2 uvDelta = i.tangentViewDir.xy * (stepSize * _Parallax);
	float surfaceHeight = 0;

	#if PACKED_WORKFLOW
		packedTex = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMap, _MainTex, i.uv.xy);
		surfaceHeight = ChannelCheck(packedTex, _HeightChannel);
		surfaceHeight = clamp(surfaceHeight, 0, 0.999);
		float prevStepHeight = stepHeight;
		float prevSurfaceHeight = surfaceHeight;

		[unroll(15)]
		for (int j = 1; j <= 15 && stepHeight > surfaceHeight; j++){
			prevUVOffset = uvOffset;
			prevStepHeight = stepHeight;
			prevSurfaceHeight = surfaceHeight;
			uvOffset -= uvDelta;
			stepHeight -= stepSize;
			surfaceHeight = ChannelCheck(UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMap, _MainTex, i.uv.xy+uvOffset), _HeightChannel);
			ApplyPBRFiltering(surfaceHeight, _HeightContrast, _HeightIntensity, _HeightLightness, _HeightFiltering, prevHeight);
		}

		[unroll(4)]
		for (int k = 0; k < 4; k++) {
			uvDelta *= 0.5;
			stepSize *= 0.5;

			if (stepHeight < surfaceHeight) {
				uvOffset += uvDelta;
				stepHeight += stepSize;
			}
			else {
				uvOffset -= uvDelta;
				stepHeight -= stepSize;
			}
			surfaceHeight = ChannelCheck(UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMap, _MainTex, i.uv.xy+uvOffset), _HeightChannel);
			ApplyPBRFiltering(surfaceHeight, _HeightContrast, _HeightIntensity, _HeightLightness, _HeightFiltering, prevHeight);
		}

	#elif PACKED_WORKFLOW_BAKED
		packedTex = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMap, _MainTex, i.uv.xy);
		surfaceHeight = packedTex.a;
		surfaceHeight = clamp(surfaceHeight, 0, 0.999);
		float prevStepHeight = stepHeight;
		float prevSurfaceHeight = surfaceHeight;

		[unroll(15)]
		for (int j = 1; j <= 15 && stepHeight > surfaceHeight; j++){
			prevUVOffset = uvOffset;
			prevStepHeight = stepHeight;
			prevSurfaceHeight = surfaceHeight;
			uvOffset -= uvDelta;
			stepHeight -= stepSize;
			surfaceHeight = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMap, _MainTex, i.uv.xy+uvOffset).a;
			ApplyPBRFiltering(surfaceHeight, _HeightContrast, _HeightIntensity, _HeightLightness, _HeightFiltering, prevHeight);
		}

		[unroll(4)]
		for (int k = 0; k < 4; k++) {
			uvDelta *= 0.5;
			stepSize *= 0.5;

			if (stepHeight < surfaceHeight) {
				uvOffset += uvDelta;
				stepHeight += stepSize;
			}
			else {
				uvOffset -= uvDelta;
				stepHeight -= stepSize;
			}
			surfaceHeight = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMap, _MainTex, i.uv.xy+uvOffset).a;
			ApplyPBRFiltering(surfaceHeight, _HeightContrast, _HeightIntensity, _HeightLightness, _HeightFiltering, prevHeight);
		}
	#else
		surfaceHeight = UNITY_SAMPLE_TEX2D_SAMPLER(_ParallaxMap, _MainTex, i.uv.xy+uvOffset);
		surfaceHeight = clamp(surfaceHeight, 0, 0.999);
		float prevStepHeight = stepHeight;
		float prevSurfaceHeight = surfaceHeight;

		[unroll(15)]
		for (int j = 1; j <= 15 && stepHeight > surfaceHeight; j++){
			prevUVOffset = uvOffset;
			prevStepHeight = stepHeight;
			prevSurfaceHeight = surfaceHeight;
			uvOffset -= uvDelta;
			stepHeight -= stepSize;
			surfaceHeight = UNITY_SAMPLE_TEX2D_SAMPLER(_ParallaxMap, _MainTex, i.uv.xy+uvOffset);
			ApplyPBRFiltering(surfaceHeight, _HeightContrast, _HeightIntensity, _HeightLightness, _HeightFiltering, prevHeight);
		}
		
		[unroll(4)]
		for (int k = 0; k < 4; k++) {
			uvDelta *= 0.5;
			stepSize *= 0.5;

			if (stepHeight < surfaceHeight) {
				uvOffset += uvDelta;
				stepHeight += stepSize;
			}
			else {
				uvOffset -= uvDelta;
				stepHeight -= stepSize;
			}
			surfaceHeight = UNITY_SAMPLE_TEX2D_SAMPLER(_ParallaxMap, _MainTex, i.uv.xy+uvOffset);
			ApplyPBRFiltering(surfaceHeight, _HeightContrast, _HeightIntensity, _HeightLightness, _HeightFiltering, prevHeight);
		}
	#endif

	// prevHeight = surfaceHeight;
	// float prevDifference = prevStepHeight - prevSurfaceHeight;
	// float difference = surfaceHeight - stepHeight;
	// float t = prevDifference / (prevDifference + difference);
	// uvOffset = lerp(prevUVOffset, uvOffset, t);
	
    return uvOffset;
}

float3 GetTangentViewDir(g2f i){
    i.tangentViewDir = normalize(i.tangentViewDir);
    i.tangentViewDir.xy /= (i.tangentViewDir.z + 0.42);
    return i.tangentViewDir;
}

// Parallax Mapping
void ApplyParallax(inout g2f i){
	if (_RenderMode == 1){
		i.tangentViewDir = GetTangentViewDir(i);
		float2 parallaxOffset = GetParallaxOffset(i);
		i.uv.xy += parallaxOffset;
		i.uv.zw += parallaxOffset;
		i.uv1.xy += parallaxOffset;
		i.uv1.zw += parallaxOffset;
		i.uv2.xy += parallaxOffset;
		i.uv3.xy += parallaxOffset;
		i.uv3.zw += parallaxOffset;
    }
}

//----------------------------
// Transparency Stuff
//----------------------------
float4 PremultiplyAlpha(float4 diffuse, float omr){
	float3 diff = diffuse.rgb * diffuse.a;
	float alpha = 1-omr + diffuse.a*omr;
	return float4(diff, alpha);
}

float GetOneMinusReflectivity(g2f i){
	float omr = 0;
	#if DEFAULT_WORKFLOW
		metallic = lerp(_Metallic, UNITY_SAMPLE_TEX2D_SAMPLER(_MetallicGlossMap, _MainTex, i.uv.xy), _UseMetallicMap);
		omr = unity_ColorSpaceDielectricSpec.a - metallic * unity_ColorSpaceDielectricSpec.a;
	#elif SPECULAR_WORKFLOW
		float3 specularTint = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecGlossMap, _MainTex, i.uv.xy).rgb;
		omr = 1-max(max(specularTint.r, specularTint.g), specularTint.b);
	#elif PACKED_WORKFLOW
		float4 packedTex = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMap, _MainTex, i.uv.xy);
		metallic = ChannelCheck(packedTex, _MetallicChannel);
		omr = unity_ColorSpaceDielectricSpec.a - metallic * unity_ColorSpaceDielectricSpec.a;
	#elif PACKED_WORKFLOW_BAKED
		metallic = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMap, _MainTex, i.uv.xy).r;
		omr = unity_ColorSpaceDielectricSpec.a - metallic * unity_ColorSpaceDielectricSpec.a;
	#endif
	return omr;
}

float ShadowPremultiplyAlpha(g2f i, float alpha){
	float omr = GetOneMinusReflectivity(i);
	alpha = 1-omr + alpha*omr;
	return alpha;
}

void NearClip(g2f i){
    if (_NearClipToggle == 1 && !i.isReflection){
        #if UNITY_SINGLE_PASS_STEREO
            float camDist = distance(i.worldPos, (unity_StereoWorldSpaceCameraPos[0].xyz + unity_StereoWorldSpaceCameraPos[1].xyz)*0.5);
        #else
            float camDist = distance(i.worldPos, _WorldSpaceCameraPos.xyz);
        #endif
        float ncMask = UNITY_SAMPLE_TEX2D_SAMPLER(_NearClipMask, _MainTex, i.rawUV);
        if (camDist < _NearClip && ncMask > 0.5){
            discard;
        }
    }
}

void MirrorClip(g2f i){
	if ((i.isReflection && _MirrorBehavior == 3) ||  (!i.isReflection && _MirrorBehavior == 1))
		discard;
}

//----------------------------
// Mask Sampling
//----------------------------
masks GetMasks(g2f i){
	masks m = (masks)1;
	m.anisoMask = 0;
	float2 refractDissUV = i.uv.xy;

	// Separate
	#if SEPARATE_MASKING
		float2 reflUV, specUV, refractUV, erimUV, matcapUV, matcapBlendUV, anisoUV, subsurfUV, rimUV;
		float2 detailUV, shadowUV, diffuseUV, filterUV, teamUV, emissUV, emissPulseUV;
		reflUV = refractUV = specUV = erimUV = matcapUV = matcapBlendUV = anisoUV = subsurfUV = rimUV = i.uv.xy;
		detailUV = shadowUV = diffuseUV = filterUV = teamUV = emissUV = emissPulseUV = i.uv.xy;
		#if SHADING_ENABLED
			#if !OUTLINE_PASS
				#if MASK_SOS_ENABLED
					reflUV = TRANSFORM_TEX(i.rawUV, _ReflectionMask) + (_Time.y*_ReflectionMaskScroll);
					specUV = TRANSFORM_TEX(i.rawUV, _SpecularMask) + (_Time.y*_SpecularMaskScroll);
					erimUV = TRANSFORM_TEX(i.rawUV, _ERimMask) + (_Time.y*_ERimMaskScroll);
					matcapUV = TRANSFORM_TEX(i.rawUV, _MatcapMask) + (_Time.y*_MatcapMaskScroll);
					matcapBlendUV = TRANSFORM_TEX(i.rawUV, _MatcapBlendMask) + (_Time.y*_MatcapBlendMaskScroll);
					anisoUV = TRANSFORM_TEX(i.rawUV, _InterpMask) + (_Time.y*_InterpMaskScroll);
					subsurfUV = TRANSFORM_TEX(i.rawUV, _SubsurfaceMask) + (_Time.y*_SubsurfaceMaskScroll);
					rimUV = TRANSFORM_TEX(i.rawUV, _RimMask) + (_Time.y*_RimMaskScroll);
					refractUV = TRANSFORM_TEX(i.rawUV, _RefractionMask) + (_Time.y*_RefractionMaskScroll);
				#endif
				#if REFLECTIONS_ENABLED
					m.reflectionMask = UNITY_SAMPLE_TEX2D_SAMPLER(_ReflectionMask, _MainTex, reflUV);
				#endif
				#if SPECULAR_ENABLED
					m.specularMask = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecularMask, _MainTex, specUV);
				#endif
				#if ENVIRONMENT_RIM_ENABLED
					m.eRimMask = UNITY_SAMPLE_TEX2D_SAMPLER(_ERimMask, _MainTex, erimUV);
				#endif
				#if MATCAP_ENABLED
					m.matcapMask = UNITY_SAMPLE_TEX2D_SAMPLER(_MatcapMask, _MainTex, matcapUV);
					m.matcapBlendMask = UNITY_SAMPLE_TEX2D_SAMPLER(_MatcapBlendMask, _MainTex, matcapBlendUV);
				#endif
				#if COMBINED_SPECULAR
					m.anisoMask = 1-UNITY_SAMPLE_TEX2D_SAMPLER(_InterpMask, _MainTex, anisoUV);
				#endif
				#if REFRACTION_ENABLED
					refractDissUV = TRANSFORM_TEX(i.rawUV, _RefractionDissolveMask) + (_Time.y*_RefractionDissolveMaskScroll);
					m.refractMask = UNITY_SAMPLE_TEX2D_SAMPLER(_RefractionMask, _MainTex, refractUV);
					m.refractDissolveMask = UNITY_SAMPLE_TEX2D_SAMPLER(_RefractionDissolveMask, _MainTex, refractDissUV);
				#endif
				m.subsurfMask = UNITY_SAMPLE_TEX2D_SAMPLER(_SubsurfaceMask, _MainTex, subsurfUV);
				m.rimMask = UNITY_SAMPLE_TEX2D_SAMPLER(_RimMask, _MainTex, rimUV);
			#endif
			#if MASK_SOS_ENABLED
				detailUV = TRANSFORM_TEX(i.rawUV, _DetailMask) + (_Time.y*_DetailMaskScroll);
				shadowUV = TRANSFORM_TEX(i.rawUV, _ShadowMask) + (_Time.y*_ShadowMaskScroll);
				diffuseUV = TRANSFORM_TEX(i.rawUV, _DiffuseMask) + (_Time.y*_DiffuseMaskScroll);
				filterUV = TRANSFORM_TEX(i.rawUV, _FilterMask) + (_Time.y*_FilterMaskScroll);
				teamUV = TRANSFORM_TEX(i.rawUV, _TeamColorMask) + (_Time.y*_TeamColorMaskScroll);
				emissUV = TRANSFORM_TEX(i.rawUV, _EmissMask) + (_Time.y*_EmissMaskScroll);
				emissPulseUV = TRANSFORM_TEX(i.rawUV, _EmissPulseMask) + (_Time.y*_EmissPulseMaskScroll);
			#endif
			m.detailMask = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailMask, _MainTex, detailUV);
			m.shadowMask = UNITY_SAMPLE_TEX2D_SAMPLER(_ShadowMask, _MainTex, shadowUV);
			m.diffuseMask = UNITY_SAMPLE_TEX2D_SAMPLER(_DiffuseMask, _MainTex, diffuseUV);
		#endif
		#if FILTERING_ENABLED
			#if OUTLINE_PASS
				m.filterMask = lerp(UNITY_SAMPLE_TEX2D_SAMPLER(_FilterMask, _MainTex, filterUV), 1, _IgnoreFilterMask);
			#else
				m.filterMask = UNITY_SAMPLE_TEX2D_SAMPLER(_FilterMask, _MainTex, filterUV);
			#endif
			m.teamMask = UNITY_SAMPLE_TEX2D_SAMPLER(_TeamColorMask, _MainTex, teamUV);
		#endif
		#if EMISSION_ENABLED
			m.emissMask = UNITY_SAMPLE_TEX2D_SAMPLER(_EmissMask, _MainTex, emissUV);
			m.emissPulseMask = UNITY_SAMPLE_TEX2D_SAMPLER(_PulseMask, _MainTex, emissPulseUV);
		#endif

	// Packed
	#elif PACKED_MASKING
		#if SHADING_ENABLED
			#if !OUTLINE_PASS
				float4 mask0 = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMask0, _MainTex, i.uv.xy);
				m.reflectionMask = mask0.r;
				m.specularMask = mask0.g;
				m.matcapMask = mask0.b;
				m.refractMask = mask0.a;
				float4 mask2 = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMask2, _MainTex, i.uv.xy);
				m.rimMask = mask2.r;
				m.eRimMask = mask2.g;
				m.matcapBlendMask = mask2.b;
				m.anisoMask = mask2.a;
			#endif
			float4 mask1 = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMask1, _MainTex, i.uv.xy);
			m.shadowMask = mask1.r;
			m.diffuseMask = mask1.g;
			m.subsurfMask = mask1.b;
			m.detailMask = mask1.a;
		#endif
		float4 mask3 = UNITY_SAMPLE_TEX2D_SAMPLER(_PackedMask3, _MainTex, i.uv.xy);
		m.emissMask = mask3.r;
		m.emissPulseMask = mask3.g;
		#if OUTLINE_PASS
			m.filterMask = lerp(mask3.b, 1, _IgnoreFilterMask);
		#else
			m.filterMask = mask3.b;
		#endif
		#if FILTERING_ENABLED
			m.teamMask = UNITY_SAMPLE_TEX2D_SAMPLER(_TeamColorMask, _MainTex, i.uv.xy);
		#endif
	#elif FILTERING_ENABLED
		m.teamMask = UNITY_SAMPLE_TEX2D_SAMPLER(_TeamColorMask, _MainTex, i.uv.xy);
	#endif

	#if REFRACTION_ENABLED
		refractDissUV = TRANSFORM_TEX(i.rawUV, _RefractionDissolveMask) + (_Time.y*_RefractionDissolveMaskScroll);
		m.refractDissolveMask = UNITY_SAMPLE_TEX2D_SAMPLER(_RefractionDissolveMask, _MainTex, refractDissUV);
	#endif

	return m;
}

#endif // US_FUNCTIONS_INCLUDED