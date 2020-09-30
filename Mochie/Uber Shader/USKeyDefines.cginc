#ifndef US_KEYWORD_DEFINES
#define US_KEYWORD_DEFINES

#ifndef X_FEATURES
	#define X_FEATURES defined(UBERX)
#endif

#ifndef FORWARD_PASS
	#define FORWARD_PASS defined(UNITY_PASS_FORWARDBASE)
#endif

#ifndef ADDITIVE_PASS
	#define ADDITIVE_PASS defined(UNITY_PASS_FORWARDADD)
#endif

#ifndef SHADOW_PASS
	#define SHADOW_PASS defined(UNITY_PASS_SHADOWCASTER)
#endif

#ifndef OUTLINE_PASS
	#define OUTLINE_PASS defined(OUTLINE)
#endif

#ifndef VERTEX_LIGHT
	#define VERTEX_LIGHT defined(VERTEXLIGHT_ON)
#endif

#ifndef ALPHA_TEST
	#define ALPHA_TEST defined(_ALPHATEST_ON)
#endif

#ifndef ALPHA_BLEND
	#define ALPHA_BLEND defined(_ALPHABLEND_ON)
#endif

#ifndef ALPHA_PREMULTIPLY
	#define ALPHA_PREMULTIPLY defined(_ALPHAPREMULTIPLY_ON)
#endif

#ifndef NON_OPAQUE_RENDERING
	#define NON_OPAQUE_RENDERING defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
#endif

#ifndef TRANSPARENT_RENDERING
	#define TRANSPARENT_RENDERING defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
#endif

#ifndef SHADING_ENABLED
	#define SHADING_ENABLED !defined(_SUNDISK_NONE)
#endif

#ifndef PACKED_WORKFLOW
	#define PACKED_WORKFLOW defined(_METALLICGLOSSMAP)
#endif

#ifndef PACKED_WORKFLOW_BAKED
	#define PACKED_WORKFLOW_BAKED defined(FXAA)
#endif

#ifndef SPECULAR_WORKFLOW
	#define SPECULAR_WORKFLOW defined(_SPECGLOSSMAP)
#endif

#ifndef DEFAULT_WORFKLOW
	#define DEFAULT_WORKFLOW !defined(_METALLICGLOSSMAP) && !defined(_SPECGLOSSMAP)
#endif

#ifndef REFLECTIONS_ENABLED
	#define REFLECTIONS_ENABLED !defined(_GLOSSYREFLECTIONS_OFF)
#endif

#ifndef SSR_ENABLED
	#define SSR_ENABLED defined(CHROMATIC_ABBERATION_LOW)
#endif

#ifndef CUBEMAP_REFLECTIONS
	#define CUBEMAP_REFLECTIONS defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
#endif

#ifndef SPECULAR_ENABLED
	#define SPECULAR_ENABLED !defined(_SPECULARHIGHLIGHTS_OFF)
#endif

#ifndef ANISO_SPECULAR 
	#define ANISO_SPECULAR defined(_SUNDISK_SIMPLE)
#endif

#ifndef COMBINED_SPECULAR
	#define COMBINED_SPECULAR defined(_SUNDISK_HIGH_QUALITY)
#endif

#ifndef GGX_SPECULAR
	#define GGX_SPECULAR !defined(_SUNDISK_SIMPLE) && !defined(_SUNDISK_HIGH_QUALITY)
#endif

#ifndef NORMALMAP_ENABLED
	#define NORMALMAP_ENABLED defined(_NORMALMAP)
#endif

#ifndef DETAIL_NORMALMAP_ENABLED
	#define DETAIL_NORMALMAP_ENABLED defined(_DETAIL_MULX2)
#endif

#ifndef EMISSION_ENABLED
	#define EMISSION_ENABLED defined(_EMISSION)
#endif

#ifndef PULSE_ENABLED
	#define PULSE_ENABLED defined(BLOOM_LENS_DIRT)
#endif

#ifndef PARALLAX_ENABLED
	#define PARALLAX_ENABLED defined(_PARALLAXMAP)
#endif

#ifndef FILTERING_ENABLED
	#define FILTERING_ENABLED defined(_COLORCOLOR_ON)
#endif

#ifndef POST_FILTERING_ENABLED
	#define POST_FILTERING_ENABLED defined(_COLOROVERLAY_ON)
#endif

#ifndef PBR_PREVIEW_ENABLED
	#define PBR_PREVIEW_ENABLED defined(USER_LUT)
#endif

#ifndef SEPARATE_MASKING
	#define SEPARATE_MASKING defined(_COLORADDSUBDIFF_ON)
#endif

#ifndef PACKED_MASKING
	#define PACKED_MASKING defined(_REQUIRE_UV2)
#endif

#ifndef UV_DISTORTION_ENABLED
	#define UV_DISTORTION_ENABLED defined(EFFECT_BUMP)
#endif

#ifndef UV_DISTORTION_NORMALMAP
	#define UV_DISTORTION_NORMALMAP defined(GRAIN)
#endif

#ifndef DISSOLVE_TEXTURE
	#define DISSOLVE_TEXTURE !defined(_ALPHAMODULATE_ON)
#endif

#ifndef DISSOLVE_GEOMETRY
	#define DISSOLVE_GEOMETRY defined(DEPTH_OF_FIELD)
#endif

#ifndef CUBEMAP_ENABLED
	#define CUBEMAP_ENABLED defined(_MAPPING_6_FRAMES_LAYOUT)
#endif

#ifndef COMBINED_CUBEMAP_ENABLED
	#define COMBINED_CUBEMAP_ENABLED defined(_TERRAIN_NORMAL_MAP)
#endif

#ifndef MATCAP_ENABLED
	#define MATCAP_ENABLED defined(_FADING_ON)
#endif

#ifndef ENVIRONMENT_RIM_ENABLED
	#define ENVIRONMENT_RIM_ENABLED defined(PIXELSNAP_ON)
#endif

#ifndef SPRITESHEETS_ENABLED
	#define SPRITESHEETS_ENABLED defined(EFFECT_HUE_VARIATION)
#endif

#ifndef CLONES_ENABLED
	#define CLONES_ENABLED defined(BLOOM)
#endif

// #ifndef CURVATURE_ENABLED
// 	#define CURVATURE_ENABLED defined(BLOOM_LOW)
// #endif

#endif