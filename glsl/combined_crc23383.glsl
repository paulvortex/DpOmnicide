/* The engine may define the following macros:
#define VERTEX_SHADER
#define GEOMETRY_SHADER
#define FRAGMENT_SHADER
#define MODE_GENERIC
#define MODE_POSTPROCESS
#define MODE_DEPTH_OR_SHADOW
#define MODE_FLATCOLOR
#define MODE_VERTEXCOLOR
#define MODE_LIGHTMAP
#define MODE_LIGHTMAP_YCG2
#define MODE_LIGHTMAP_YCG2SRGB
#define MODE_FAKELIGHT
#define MODE_LIGHTDIRECTIONMAP_MODELSPACE
#define MODE_LIGHTDIRECTIONMAP_MODELSPACE_YCG2
#define MODE_LIGHTDIRECTIONMAP_MODELSPACE_YCG2SRGB
#define MODE_LIGHTDIRECTIONMAP_TANGENTSPACE
#define MODE_LIGHTDIRECTIONMAP_TANGENTSPACE_YCG2
#define MODE_LIGHTDIRECTIONMAP_TANGENTSPACE_YCG2SRGB
#define MODE_LIGHTDIRECTIONMAP_FORCED_LIGHTMAP
#define MODE_LIGHTDIRECTIONMAP_FORCED_VERTEXCOLOR
#define MODE_LIGHTDIRECTION
#define MODE_LIGHTSOURCE
#define MODE_REFRACTION
#define MODE_WATER
#define MODE_DEFERREDGEOMETRY
#define MODE_DEFERREDLIGHTSOURCE
#define USEDIFFUSE
#define USEVERTEXTEXTUREBLEND
#define USEVIEWTINT
#define USECOLORMAPPING
#define USEFOGINSIDE
#define USEFOGOUTSIDE
#define USEFOGHEIGHTTEXTURE
#define USEFOGALPHAHACK
#define USEGAMMARAMPS
#define USECUBEFILTER
#define USEGLOW
#define USEBLOOM
#define USESPECULAR
#define USEREFLECTION
#define USEOFFSETMAPPING
#define USEOFFSETMAPPING_RELIEFMAPPING
#define USESHADOWMAP2D
#define USESHADOWMAPVSDCT
#define USESHADOWMAPORTHO
#define USEDEFERREDLIGHTMAP
#define USEALPHAKILL
#define USEREFLECTCUBE
#define USESCROLLBLEND
#define USEBOUNCEGRID
#define USETRIPPY
#define USEDEPTHRGB
#define USEALPHAGENVERTEX
#define USESKELETAL
#define USEOCCLUDE
#define USESELFSHADOWING
#define USEVEGETATION
*/
// ambient+diffuse+specular+normalmap+attenuation+cubemap+fog shader
// written by Forest 'LordHavoc' Hale
// shadowmapping enhancements by Lee 'eihrul' Salzman
// VorteX {
// enhancements by Pavel 'VorteX' Timofeyev:
// - Watershader/diffuse 'scroll blend' animation (waterflow effect)
// - YCoCg/YCoCg scaled compression for lightmaps
// - Sun light
// - Vegetation vertex shader + wind effect
// - Trippy shader fix for top-down camera
// - Fog fix
// - Offsetmapping fixed for non-square textures
// - Offsetmapping LOD
// - Postprocessing: sharpen, improved contrast, color mix
// - 'Show vertex alpha' switch
// - Water shader: refraction blur, sun specular
// - Texture-space gamma (higher quality)
// - Cel texturing (averaged color for surfaces)
// - Vertex texture blend utilizing both texture alpha for non-linear splat mapped transition
// } VorteX

#if defined(USESKELETAL) || defined(USEOCCLUDE)
#  ifdef GL_ARB_uniform_buffer_object
#    extension GL_ARB_uniform_buffer_object : enable
#  endif
#endif

#ifdef USESHADOWMAP2D
# ifdef GL_EXT_gpu_shader4
#   extension GL_EXT_gpu_shader4 : enable
# endif
# ifdef GL_ARB_texture_gather
#   extension GL_ARB_texture_gather : enable
# else
#   ifdef GL_AMD_texture_texture4
#     extension GL_AMD_texture_texture4 : enable
#   endif
# endif
#endif

#ifdef USECELSHADING
# define SHADEDIFFUSE myhalf diffuse = cast_myhalf(min(max(float(dot(surfacenormal, lightnormal)) * 2.0, 0.0), 1.0));
# ifdef USEEXACTSPECULARMATH
#  define SHADESPECULAR(specpow) myhalf specular = pow(cast_myhalf(max(float(dot(reflect(lightnormal, surfacenormal), eyenormal))*-1.0, 0.0)), 1.0 + specpow);specular = max(0.0, specular * 10.0 - 9.0);
# else
#  define SHADESPECULAR(specpow) myhalf3 specularnormal = normalize(lightnormal + eyenormal);myhalf specular = pow(cast_myhalf(max(float(dot(surfacenormal, specularnormal)), 0.0)), 1.0 + specpow);specular = max(0.0, specular * 10.0 - 9.0);
# endif
#else
# define SHADEDIFFUSE myhalf diffuse = cast_myhalf(max(float(dot(surfacenormal, lightnormal)), 0.0));
# ifdef USEEXACTSPECULARMATH
#  define SHADESPECULAR(specpow) myhalf specular = pow(cast_myhalf(max(float(dot(reflect(lightnormal, surfacenormal), eyenormal))*-1.0, 0.0)), 1.0 + specpow);
# else
#  define SHADESPECULAR(specpow) myhalf3 specularnormal = normalize(lightnormal + eyenormal);myhalf specular = pow(cast_myhalf(max(float(dot(surfacenormal, specularnormal)), 0.0)), 1.0 + specpow);
# endif
#endif

#if defined(GLSL130) || defined(GLSL140)
precision highp float;
# ifdef VERTEX_SHADER
#  define dp_varying out
#  define dp_attribute in
# endif
# ifdef FRAGMENT_SHADER
out vec4 dp_FragColor;
#  define dp_varying in
#  define dp_attribute in
# endif
# define dp_offsetmapping_dFdx dFdx
# define dp_offsetmapping_dFdy dFdy
# define dp_textureGrad textureGrad
# define dp_textureOffset(a,b,c,d) textureOffset(a,b,ivec2(c,d))
# define dp_texture2D texture
# define dp_texture3D texture
# define dp_textureCube texture
# define dp_shadow2D(a,b) float(texture(a,b))
#else
# ifdef FRAGMENT_SHADER
#  define dp_FragColor gl_FragColor
# endif
# define dp_varying varying
# define dp_attribute attribute
# define dp_offsetmapping_dFdx(a) vec2(0.0, 0.0)
# define dp_offsetmapping_dFdy(a) vec2(0.0, 0.0)
# define dp_textureGrad(a,b,c,d) texture2D(a,b)
# define dp_textureOffset(a,b,c,d) texture2DOffset(a,b,ivec2(c,d))
# define dp_texture2D texture2D
# define dp_texture3D texture3D
# define dp_textureCube textureCube
# define dp_shadow2D(a,b) float(shadow2D(a,b))
#endif

// GL ES and GLSL130 shaders use precision modifiers, standard GL does not
// in GLSL130 we don't use them though because of syntax differences (can't use precision with inout)
#ifndef GL_ES
#define lowp
#define mediump
#define highp
#endif

#ifdef USEDEPTHRGB
	// for 565 RGB we'd need to use different multipliers
#define decodedepthmacro(d) dot((d).rgb, vec3(1.0, 255.0 / 65536.0, 255.0 / 16777215.0))
#define encodedepthmacro(d) (vec4(d, d*256.0, d*65536.0, 0.0) - floor(vec4(d, d*256.0, d*65536.0, 0.0)))
#endif

#ifdef VERTEX_SHADER
dp_attribute vec4 Attrib_Position;  // vertex
dp_attribute vec4 Attrib_Color;     // color
dp_attribute vec4 Attrib_TexCoord0; // material texcoords
dp_attribute vec3 Attrib_TexCoord1; // svector
dp_attribute vec3 Attrib_TexCoord2; // tvector
dp_attribute vec3 Attrib_TexCoord3; // normal
dp_attribute vec4 Attrib_TexCoord4; // lightmap texcoords
#ifdef USESKELETAL
//uniform mat4 Skeletal_Transform[128];
// this is used with glBindBufferRange to bind a uniform block to the name
// Skeletal_Transform12_UniformBlock, the Skeletal_Transform12 variable is
// directly accessible without a namespace.
// explanation: http://www.opengl.org/wiki/Interface_Block_%28GLSL%29#Syntax
uniform Skeletal_Transform12_UniformBlock
{
	vec4 Skeletal_Transform12[768];
};
dp_attribute vec4 Attrib_SkeletalIndex;
dp_attribute vec4 Attrib_SkeletalWeight;
#endif
#endif
dp_varying mediump vec4 VertexColor;

#if defined(USEFOGINSIDE) || defined(USEFOGOUTSIDE) || defined(USEFOGHEIGHTTEXTURE)
# define USEFOG
#endif
#if defined(MODE_LIGHTMAP) || defined(MODE_LIGHTDIRECTIONMAP_MODELSPACE) || defined(MODE_LIGHTDIRECTIONMAP_TANGENTSPACE) || defined(MODE_LIGHTDIRECTIONMAP_FORCED_LIGHTMAP)
# define USELIGHTMAP
#endif
#if defined(USESPECULAR) || defined(USEOFFSETMAPPING) || defined(USEREFLECTCUBE) || defined(MODE_FAKELIGHT) || defined(USEFOG)
# define USEEYEVECTOR
#endif

//#ifdef __GLSL_CG_DATA_TYPES
//# define myhalf half
//# define myhalf2 half2
//# define myhalf3 half3
//# define myhalf4 half4
//# define cast_myhalf half
//# define cast_myhalf2 half2
//# define cast_myhalf3 half3
//# define cast_myhalf4 half4
//#else
# define myhalf mediump float
# define myhalf2 mediump vec2
# define myhalf3 mediump vec3
# define myhalf4 mediump vec4
# define cast_myhalf float
# define cast_myhalf2 vec2
# define cast_myhalf3 vec3
# define cast_myhalf4 vec4
//#endif

// VorteX {
// Scroll blend common definitions
#if defined(FRAGMENT_SHADER) && defined(USESCROLLBLEND)
#ifndef USECLIENTTIME
uniform highp float ClientTime;
#define USECLIENTTIME
#endif
uniform lowp vec3 ScrollBlend;
#define SCROLLVECN1 vec2( 0.000, 0.012)
#define SCROLLVECN2 vec2( 0.004, 0.009)
#define SCROLLVECN3 vec2(-0.004, 0.009)
#define SCROLLVECT1 vec2( 0.003, 0.007)
#define SCROLLVECT2 vec2(-0.003, 0.007)
myhalf3 ScrollBlendNormalmap(sampler2D tex, vec2 TexCoord)
{
	myhalf3 basenormal     = dp_texture2D(tex, (TexCoord                                                          + SCROLLVECN1*ClientTime*ScrollBlend.x)*ScrollBlend.y).rgb;
	myhalf3 surfacenormal  = dp_texture2D(tex, (TexCoord - (basenormal.xy    - myhalf2(0.5)) * ScrollBlend.z      + SCROLLVECN2*ClientTime*ScrollBlend.x)*ScrollBlend.y*0.75).rgb; 
			surfacenormal += dp_texture2D(tex, (TexCoord - (surfacenormal.xy - myhalf2(0.5)) * ScrollBlend.z*0.6  + SCROLLVECN3*ClientTime*ScrollBlend.x)*ScrollBlend.y*0.50).rgb;
			surfacenormal += dp_texture2D(tex, (TexCoord - (surfacenormal.xy - myhalf2(0.5)) * ScrollBlend.z*0.4  + SCROLLVECN1*ClientTime*ScrollBlend.x)*ScrollBlend.y).rgb;
	return cast_myhalf3(normalize(surfacenormal - myhalf3(1.5)));
}
myhalf4 ScrollBlendTexture(sampler2D tex, vec2 TexCoord, myhalf3 surfacenormal)
{
	myhalf4 color  = dp_texture2D(tex, (TexCoord + surfacenormal.xy*ScrollBlend.z + SCROLLVECN1*ClientTime*ScrollBlend.x)*ScrollBlend.y);
	        color += dp_texture2D(tex, (TexCoord + surfacenormal.xy*ScrollBlend.z + SCROLLVECT1*ClientTime*ScrollBlend.x)*ScrollBlend.y*0.75); 
			color += dp_texture2D(tex, (TexCoord + surfacenormal.xy*ScrollBlend.z + SCROLLVECT2*ClientTime*ScrollBlend.x)*ScrollBlend.y*0.50);
	return color / 3.0;
}
#endif // FRAGMENT_SHADER && USESCROLLBLEND

// YCoCg Swizzled texture common definitions
#if defined(MODE_LIGHTMAP_YCG2)
	#define USELIGHTMAP
	#define LIGHTMAP_YCG2
	#define MODE_LIGHTMAP
#elif defined(MODE_LIGHTDIRECTIONMAP_MODELSPACE_YCG2)
	#define USELIGHTMAP
	#define LIGHTMAP_YCG2
	#define MODE_LIGHTDIRECTIONMAP_MODELSPACE
#elif defined(MODE_LIGHTDIRECTIONMAP_TANGENTSPACE_YCG2)
	#define USELIGHTMAP
	#define LIGHTMAP_YCG2
	#define MODE_LIGHTDIRECTIONMAP_TANGENTSPACE
#elif defined(MODE_LIGHTMAP_YCG2SRGB)
	#define USELIGHTMAP
	#define LIGHTMAP_YCG2SRGB
	#define MODE_LIGHTMAP
#elif defined(MODE_LIGHTDIRECTIONMAP_MODELSPACE_YCG2SRGB)
	#define USELIGHTMAP
	#define LIGHTMAP_YCG2SRGB
	#define MODE_LIGHTDIRECTIONMAP_MODELSPACE
#elif defined(MODE_LIGHTDIRECTIONMAP_TANGENTSPACE_YCG2SRGB)
	#define USELIGHTMAP
	#define LIGHTMAP_YCG2SRGB
	#define MODE_LIGHTDIRECTIONMAP_TANGENTSPACE
#endif

// Sunlight common definitions
#ifdef USESUNLIGHT
#if defined(MODE_WATER) || (defined(MODE_LIGHTDIRECTION) && defined(USEDIFFUSE)) || defined(MODE_LIGHTDIRECTIONMAP_MODELSPACE) || defined(MODE_LIGHTDIRECTIONMAP_TANGENTSPACE) || defined(MODE_LIGHTDIRECTIONMAP_TANGENTSPACE) || defined(MODE_LIGHTDIRECTIONMAP_FORCED_LIGHTMAP) || defined(MODE_LIGHTDIRECTIONMAP_FORCED_VERTEXCOLOR) || defined(MODE_LIGHTMAP) || defined(MODE_FAKELIGHT)
	#define USESUNDIRECTION
	#define SUNDIRECTION_DIFFUSEBIAS 0.4
	#if defined(MODE_LIGHTDIRECTIONMAP_FORCED_VERTEXCOLOR) || defined(MODE_LIGHTDIRECTION)
		#define SUNDIRECTION_DIFFUSE 3.5
		#define SUNDIRECTION_AMBIENT 0.3
		#define SUNDIRECTION_MAXDIFFUSE 0.7
	#else
		#define SUNDIRECTION_DIFFUSE 9.0
		#define SUNDIRECTION_MAXDIFFUSE 1.0
	#endif
	#define SUNDIRECTION_BASECOLOR myhalf3(0.25, 0.25, 0.25)
#endif 
#endif // USESUNLIGHT

// OffsetMapping texture size fix
#define USEOFFSETMAPPING_NONSQUARETEXTURES 1

// Fog common definitions
#ifdef USEFOG
#ifdef FRAGMENT_SHADER
#ifdef USEFOGHEIGHTTEXTURE
uniform sampler2D Texture_FogHeightTexture;
#endif
uniform sampler2D Texture_FogMask;
uniform mediump vec3 FogColor;
uniform highp float FogRangeRecip;
uniform highp float FogPlaneViewDist;
uniform highp float FogHeightFade;
vec3 FogVertex(vec4 surfacecolor, vec3 EyeVectorModelSpace, float FogPlaneVertexDist)
{
	float fogfrac;
	vec3 fc = FogColor;
#ifdef USEFOGALPHAHACK
		fc *= surfacecolor.a;
#endif
#ifdef USEFOGHEIGHTTEXTURE
		vec4 fogheightpixel = dp_texture2D(Texture_FogHeightTexture, vec2(1,1) + vec2(FogPlaneVertexDist, FogPlaneViewDist) * (-2.0 * FogHeightFade));
		fogfrac = fogheightpixel.a;
		return mix(fogheightpixel.rgb * fc, surfacecolor.rgb, dp_texture2D(Texture_FogMask, cast_myhalf2(length(EyeVectorModelSpace)*fogfrac*FogRangeRecip, 0.0)).r);
#else
	#ifdef USEFOGOUTSIDE
		fogfrac = min(0.0, FogPlaneVertexDist) / (FogPlaneVertexDist - FogPlaneViewDist) * min(1.0, min(0.0, FogPlaneVertexDist) * FogHeightFade);
	#else
		fogfrac = FogPlaneViewDist / (FogPlaneViewDist - max(0.0, FogPlaneVertexDist)) * min(1.0, (min(0.0, FogPlaneVertexDist) + FogPlaneViewDist) * FogHeightFade);
	#endif
	return mix(fc, surfacecolor.rgb, dp_texture2D(Texture_FogMask, cast_myhalf2(length(EyeVectorModelSpace)*fogfrac*FogRangeRecip, 0.0)).r);
#endif
}
#endif // FRAGMENT_SHADER
#endif // USEFOG

// Lightmap common definitions
#if defined(FRAGMENT_SHADER) && defined(LIGHTMAP_YCG2) 
#define DecodeLightmap DecodeYCoCgScaled
#define DecodeDeluxemap DecodeYCoCgScaled
myhalf3 DecodeYCoCgScaled(myhalf4 color)
{
	float s = 1.0 / ((255.0 / 8.0) * color.b + 1.0);
	float Co = (color.r - (0.5 * (256.0 / 255.0))) * s;
	float Cg = (color.g - (0.5 * (256.0 / 255.0))) * s;
	return myhalf3(color.a + Co - Cg, color.a + Cg, color.a - Co - Cg);
}
#elif defined(LIGHTMAP_YCG2SRGB)
#define DecodeLightmap DecodeYCoCgScaledSRGB
#define DecodeDeluxemap DecodeYCoCgScaled
myhalf3 DecodeYCoCgScaled(myhalf4 color)
{
	float s = 1.0 / ((255.0 / 8.0) * color.b + 1.0);
	float Co = (color.r - (0.5 * (256.0 / 255.0))) * s;
	float Cg = (color.g - (0.5 * (256.0 / 255.0))) * s;
	return myhalf3(color.a + Co - Cg, color.a + Cg, color.a - Co - Cg);
}
myhalf3 DecodeYCoCgScaledSRGB(myhalf4 color)
{
	float s = 1.0 / ((255.0 / 8.0) * color.b + 1.0);
	float Co = (color.r - (0.5 * (256.0 / 255.0))) * s;
	float Cg = (color.g - (0.5 * (256.0 / 255.0))) * s;
	vec3 c = vec3(color.a + Co - Cg, color.a + Cg, color.a - Co - Cg);
	c.r = (c.r <= 0.04045) ? c.r * (1.0 / 12.92) : pow((c.r + 0.055)*(1.0/1.055), 2.4);
	c.g = (c.g <= 0.04045) ? c.g * (1.0 / 12.92) : pow((c.g + 0.055)*(1.0/1.055), 2.4);
	c.b = (c.b <= 0.04045) ? c.b * (1.0 / 12.92) : pow((c.b + 0.055)*(1.0/1.055), 2.4);
	return cast_myhalf3(c);
}
#else
#define DecodeLightmap cast_myhalf3
#define DecodeDeluxemap cast_myhalf3
#endif // FRAGMENT_SHADER && LIGHTMAP_YCG2
// } VorteX

#ifdef VERTEX_SHADER
uniform highp mat4 ModelViewProjectionMatrix;
#endif

// VorteX {
#if defined(VERTEX_SHADER) && defined(USEVEGETATION)
uniform lowp vec4 VegetationParameters;
#ifdef USEWIND
uniform lowp vec3 WindDir;
uniform lowp vec4 WindParameters;
#endif
#ifndef USECLIENTTIME
uniform highp float ClientTime;
#define USECLIENTTIME
#endif

vec4 VegetationVertex(vec4 position, float alpha)
{
	// parameters
	#define plantheight VegetationParameters.x
	#define waveamplitude VegetationParameters.y
	#define wavespeed VegetationParameters.z
	#define waverotation VegetationParameters.a
#ifdef USEWIND
	#define windamplitude WindParameters.x
	#define windtilt WindParameters.y
	#define windspeed WindParameters.z
#endif

	// decode vertex parms from alpha (two 4-bit floats: jitter parm and amplitude)
	float vertpacked = alpha * 15.9375;
	float vertamplitude = floor(vertpacked);
	float vertjitter = (vertpacked - vertamplitude) * 1.07;
	      vertamplitude /= 3.75;
	if( vertamplitude <= 0 )
		return position;
		
	// calc slow global waving
	float vertangle = vertjitter * 1500.0;
	float globalwave = (0.8 + cos(ClientTime + vertangle)) / 1.8;
	
	// calc wave move
	float amplitude = vertamplitude * waveamplitude;
	float rotateCurve = ClientTime * waverotation - vertangle;
	float moveCurve = (ClientTime - vertangle) * wavespeed;
	vec3 move = vec3(sin(rotateCurve), cos(rotateCurve), 0.0) * sin(moveCurve) * globalwave * amplitude;
	
	// calc wind
#ifdef USEWIND
	float windjitter = (cos((moveCurve * windspeed) - vertangle) + windtilt * 0.5) * vertamplitude * windamplitude * globalwave + windtilt * 0.5;
	move += WindDir * windjitter;
#endif
	
	// calc rotation
	// vortex: not exact rotation as we need to know the point origin
	//         it just shifts down to simulate a part of rotation
#ifdef USEVEGETATIONDEFORMROTATION
	float length = length(move);
	float height = vertamplitude * plantheight;
	float hypot = sqrt( height*height + length*length );
	float rotation = length * (length / hypot);
	move.z -= rotation;
#endif

	// apply move
	position.xyz += move;
	return position;	
}
#ifdef SHOWVERTEXALPHA
vec3 VegetationShow(vec3 color, float alpha)
{
	// decode vertex parms from alpha (two 4-bit floats: jitter parm and amplitude)
	float vertpacked = alpha * 15.9375;
	float vertamplitude = floor(vertpacked);
	float vertjitter = (vertpacked - vertamplitude) * 1.07;
	      vertamplitude /= 3.75;
		  
	// show in rgb
	return vec3( vertjitter );
	return vec3( 1.0, 0.0, 0.0 ) * vertjitter * vertjitter + vec3(0.0, 0.0, 1.0) * vertamplitude * vertamplitude;
	if( vertjitter < 0.33 )
		return vec3( 1.0, 0.0, 0.0 ) * (vertjitter / 0.33);
	if( vertjitter < 0.66 )
		return vec3( 0.0, 1.0, 0.0 ) * (vertjitter / 0.66);
	return vec3( 0.0, 0.0, 1.0 ) * vertjitter;
}
#endif
#endif // VERTEX_SHADER && USEVEGETATION

#if defined(VERTEX_SHADER) && defined(USETRIPPY)
// LordHavoc: based on shader code linked at: http://www.youtube.com/watch?v=JpksyojwqzE
// tweaked scale
#ifndef USECLIENTTIME
uniform highp float ClientTime;
#define USECLIENTTIME
#endif
vec4 TrippyVertex(vec4 position)
{
	float worldTime = ClientTime;
	// tweaked for Quake
	worldTime *= 10.0;
	position *= 0.125;
	//~tweaked for Quake
	float distanceSquared = (position.x * position.x + position.z * position.z);
	position.y += 2.0*sin(distanceSquared*sin(worldTime/143.0)/1000.0);
	float y = position.y;
	float x = position.x;
	float om = sin(distanceSquared*sin(worldTime/256.0)/5000.0) * sin(worldTime/200.0);
	position.y = x*sin(om)+y*cos(om);
	position.x = x*cos(om)-y*sin(om);
	return position;
}
#endif // VERTEX_SHADER && USETRIPPY
// } VorteX

#ifdef MODE_DEPTH_OR_SHADOW
dp_varying highp float Depth;
#ifdef VERTEX_SHADER
void main(void)
{
#ifdef USESKELETAL
	ivec4 si0 = ivec4(Attrib_SkeletalIndex * 3.0);
	ivec4 si1 = si0 + ivec4(1, 1, 1, 1);
	ivec4 si2 = si0 + ivec4(2, 2, 2, 2);
	vec4 sw = Attrib_SkeletalWeight;
	vec4 SkeletalMatrix1 = Skeletal_Transform12[si0.x] * sw.x + Skeletal_Transform12[si0.y] * sw.y + Skeletal_Transform12[si0.z] * sw.z + Skeletal_Transform12[si0.w] * sw.w;
	vec4 SkeletalMatrix2 = Skeletal_Transform12[si1.x] * sw.x + Skeletal_Transform12[si1.y] * sw.y + Skeletal_Transform12[si1.z] * sw.z + Skeletal_Transform12[si1.w] * sw.w;
	vec4 SkeletalMatrix3 = Skeletal_Transform12[si2.x] * sw.x + Skeletal_Transform12[si2.y] * sw.y + Skeletal_Transform12[si2.z] * sw.z + Skeletal_Transform12[si2.w] * sw.w;
	mat4 SkeletalMatrix = mat4(SkeletalMatrix1, SkeletalMatrix2, SkeletalMatrix3, vec4(0.0, 0.0, 0.0, 1.0));
	vec4 SkeletalVertex = Attrib_Position * SkeletalMatrix;
#define Attrib_Position SkeletalVertex
#endif
// VorteX {
#ifdef USEVEGETATION
	gl_Position = ModelViewProjectionMatrix * VegetationVertex(Attrib_Position, Attrib_Color.a);
#else
	gl_Position = ModelViewProjectionMatrix * Attrib_Position;
#endif
// } VorteX
#ifdef USETRIPPY
	gl_Position = TrippyVertex(gl_Position);
#endif
	Depth = gl_Position.z;
}
#endif

#ifdef FRAGMENT_SHADER
void main(void)
{
#ifdef USEDEPTHRGB
	dp_FragColor = encodedepthmacro(Depth);
#else
	dp_FragColor = vec4(1.0,1.0,1.0,1.0);
#endif
}
#endif
#else // !MODE_DEPTH_ORSHADOW




#ifdef MODE_POSTPROCESS
dp_varying mediump vec2 TexCoord1;
dp_varying mediump vec2 TexCoord2;

#ifdef VERTEX_SHADER
void main(void)
{
	gl_Position = ModelViewProjectionMatrix * Attrib_Position;
	TexCoord1 = Attrib_TexCoord0.xy;
#ifdef USEBLOOM
	TexCoord2 = Attrib_TexCoord4.xy;
#endif
}
#endif

#ifdef FRAGMENT_SHADER
uniform sampler2D Texture_First;
#ifdef USEBLOOM
uniform sampler2D Texture_Second;
uniform mediump vec4 BloomColorSubtract;
#endif
#ifdef USEGAMMARAMPS
uniform sampler2D Texture_GammaRamps;
#endif
#ifdef USESATURATION
uniform mediump float Saturation;
#endif
#ifdef USEVIEWTINT
uniform mediump vec4 ViewTintColor;
#endif
//uncomment these if you want to use them:
uniform mediump vec4 UserVec1;
uniform mediump vec4 UserVec2;
// VorteX {
uniform mediump vec4 UserVec3;
// uniform mediump vec4 UserVec4;
#ifndef USECLIENTTIME
// uniform highp float ClientTime;
// #define USECLIENTTIME
#endif
// } VorteX
uniform mediump vec2 PixelSize;

#ifdef USEFXAA
// graphitemaster: based off the white paper by Timothy Lottes
// http://developer.download.nvidia.com/assets/gamedev/files/sdk/11/FXAA_WhitePaper.pdf
vec4 fxaa(vec4 inColor, float maxspan)
{
	vec4 ret = inColor; // preserve old
	float mulreduct = 1.0/maxspan;
	float minreduct = (1.0 / 128.0);

	// directions
	vec3 NW = dp_texture2D(Texture_First, TexCoord1 + (vec2(-1.0, -1.0) * PixelSize)).xyz;
	vec3 NE = dp_texture2D(Texture_First, TexCoord1 + (vec2(+1.0, -1.0) * PixelSize)).xyz;
	vec3 SW = dp_texture2D(Texture_First, TexCoord1 + (vec2(-1.0, +1.0) * PixelSize)).xyz;
	vec3 SE = dp_texture2D(Texture_First, TexCoord1 + (vec2(+1.0, +1.0) * PixelSize)).xyz;
	vec3 M = dp_texture2D(Texture_First, TexCoord1).xyz;

	// luminance directions
	vec3 luma = vec3(0.299, 0.587, 0.114);
	float lNW = dot(NW, luma);
	float lNE = dot(NE, luma);
	float lSW = dot(SW, luma);
	float lSE = dot(SE, luma);
	float lM = dot(M, luma);
	float lMin = min(lM, min(min(lNW, lNE), min(lSW, lSE)));
	float lMax = max(lM, max(max(lNW, lNE), max(lSW, lSE)));

	// direction and reciprocal
	vec2 dir = vec2(-((lNW + lNE) - (lSW + lSE)), ((lNW + lSW) - (lNE + lSE)));
	float rcp = 1.0/(min(abs(dir.x), abs(dir.y)) + max((lNW + lNE + lSW + lSE) * (0.25 * mulreduct), minreduct));

	// span
	dir = min(vec2(maxspan, maxspan), max(vec2(-maxspan, -maxspan), dir * rcp)) * PixelSize;

	vec3 rA = (1.0/2.0) * (
		dp_texture2D(Texture_First, TexCoord1 + dir * (1.0/3.0 - 0.5)).xyz +
		dp_texture2D(Texture_First, TexCoord1 + dir * (2.0/3.0 - 0.5)).xyz);
	vec3 rB = rA * (1.0/2.0) + (1.0/4.0) * (
		dp_texture2D(Texture_First, TexCoord1 + dir * (0.0/3.0 - 0.5)).xyz +
		dp_texture2D(Texture_First, TexCoord1 + dir * (3.0/3.0 - 0.5)).xyz);
	float lB = dot(rB, luma);

	ret.xyz = ((lB < lMin) || (lB > lMax)) ? rA : rB;
	ret.a = 1.0;
	return ret;
}
#endif

void main(void)
{
	dp_FragColor = dp_texture2D(Texture_First, TexCoord1);

#ifdef USEFXAA
	dp_FragColor = fxaa(dp_FragColor, 8.0); // 8.0 can be changed for larger span
#endif

#ifdef USEBLOOM
	dp_FragColor += max(vec4(0,0,0,0), dp_texture2D(Texture_Second, TexCoord2) - BloomColorSubtract);
#endif

#ifdef USEVIEWTINT
	dp_FragColor = mix(dp_FragColor, ViewTintColor, ViewTintColor.a);
#endif

// VorteX {
#ifdef USEPOSTPROCESSING
	vec2 size = PixelSize.xy * UserVec1.x;
	vec3 sum = vec3(0.0);

	// sharpen (> 0) or blur (< 0)
	if (UserVec1.x > 0.0)
	{
		// x - pixel radius
		// y - radius 
		// z - brighten 
		// a - mix ratio	
		sum += dp_texture2D(Texture_First, TexCoord1 + vec2(-size.x, -size.y)).rgb * -UserVec1.y;
		sum += dp_texture2D(Texture_First, TexCoord1 + vec2(0.0, -size.y)).rgb * -UserVec1.y;
		sum += dp_texture2D(Texture_First, TexCoord1 + vec2(size.x, -size.y)).rgb * -UserVec1.y;
		sum += dp_texture2D(Texture_First, TexCoord1 + vec2(-size.x, 0.0)).rgb * -UserVec1.y;
		sum += dp_texture2D(Texture_First, TexCoord1).rgb * 9.0 * UserVec1.y;
		sum += dp_texture2D(Texture_First, TexCoord1 + vec2(size.x, 0.0)).rgb * -UserVec1.y;
		sum += dp_texture2D(Texture_First, TexCoord1 + vec2(-size.x, size.y)).rgb * -UserVec1.y;
		sum += dp_texture2D(Texture_First, TexCoord1 + vec2(0.0, size.y)).rgb * -UserVec1.y;
		sum += dp_texture2D(Texture_First, TexCoord1 + vec2(size.x, size.y)).rgb * -UserVec1.y;
		dp_FragColor.rgb = mix(dp_FragColor.rgb, dp_FragColor.rgb * max(0.33, min(0.6, 0.3*sum.r + 0.59*sum.g + 0.11*sum.b) + UserVec1.z), UserVec1.a);
	}
	else
	{
		// blur
		// x - step (pixel) radius
		// y - number of passes
		float px = 0.0 - UserVec1.x;
		float passes = UserVec1.y;
		float p = px;
		while(passes > 0.0)
		{
			dp_FragColor += dp_texture2D(Texture_First, TexCoord1 + PixelSize*p*vec2(-0.987688, -0.156434));
			dp_FragColor += dp_texture2D(Texture_First, TexCoord1 + PixelSize*p*vec2(-0.156434, -0.891007));
			dp_FragColor += dp_texture2D(Texture_First, TexCoord1 + PixelSize*p*vec2( 0.891007, -0.453990));
			dp_FragColor += dp_texture2D(Texture_First, TexCoord1 + PixelSize*p*vec2( 0.707107,  0.707107));
			dp_FragColor += dp_texture2D(Texture_First, TexCoord1 + PixelSize*p*vec2(-0.453990,  0.891007));
			passes = passes - 1.0;
			px = px * UserVec1.z;
			p = p + px;
		}
		dp_FragColor /= 1.0 + 5.0 * UserVec1.y;
	}
	
	// prefilter
	if (UserVec3.a > 0)
	{
		vec3 rgb = dp_FragColor.rgb;
		if (UserVec3.x == 1)
		{
			rgb.r = pow(rgb.r, 0.8) * 0.95;
			rgb.g = pow(rgb.g, 0.8);
			rgb.b = pow(rgb.b, 0.8);
			rgb.r = (rgb.r + (rgb.r - 0.5)*0.08 - UserVec3.y)*UserVec3.z;
			rgb.g = (rgb.g + (rgb.g - 0.5)*0.08 - UserVec3.y)*UserVec3.z;
			rgb.b = (rgb.b + (rgb.b - 0.5)*0.08 - UserVec3.y)*UserVec3.z;
		}
		dp_FragColor.r = mix(dp_FragColor.r, rgb.r, UserVec3.a);
		dp_FragColor.g = mix(dp_FragColor.g, rgb.g, UserVec3.a);
		dp_FragColor.b = mix(dp_FragColor.b, rgb.b, UserVec3.a);
	} 
	else
	{
		// variable color filter
		dp_FragColor.r = dp_FragColor.r + ((dp_FragColor.r - 0.5)*2.0)*UserVec2.x*UserVec2.a;
		dp_FragColor.g = dp_FragColor.g + ((dp_FragColor.g - 0.5)*2.0)*UserVec2.y*UserVec2.a;
		dp_FragColor.b = dp_FragColor.b + ((dp_FragColor.b - 0.5)*2.0)*UserVec2.z*UserVec2.a;
	}
#endif
// } VorteX

#ifdef USESATURATION
	//apply saturation BEFORE gamma ramps, so v_glslgamma value does not matter
	float y = dot(dp_FragColor.rgb, vec3(0.299, 0.587, 0.114));
	// 'vampire sight' effect, wheres red is compensated
	#ifdef SATURATION_REDCOMPENSATE
		float rboost = max(0.0, (dp_FragColor.r - max(dp_FragColor.g, dp_FragColor.b))*(1.0 - Saturation));
		dp_FragColor.rgb = mix(vec3(y), dp_FragColor.rgb, Saturation);
		dp_FragColor.r += rboost;
	#else
		// normal desaturation
		//dp_FragColor = vec3(y) + (dp_FragColor.rgb - vec3(y)) * Saturation;
		dp_FragColor.rgb = mix(vec3(y), dp_FragColor.rgb, Saturation);
	#endif
#endif

#ifdef USEGAMMARAMPS
	dp_FragColor.r = dp_texture2D(Texture_GammaRamps, vec2(dp_FragColor.r, 0)).r;
	dp_FragColor.g = dp_texture2D(Texture_GammaRamps, vec2(dp_FragColor.g, 0)).g;
	dp_FragColor.b = dp_texture2D(Texture_GammaRamps, vec2(dp_FragColor.b, 0)).b;
#endif
}
#endif
#else // !MODE_POSTPROCESS




#ifdef MODE_GENERIC
#ifdef USEDIFFUSE
dp_varying mediump vec2 TexCoord1;
#endif
#ifdef USESPECULAR
dp_varying mediump vec2 TexCoord2;
#endif
// VorteX {
#ifdef USEFOG
uniform highp vec3 EyePosition;
dp_varying highp vec3 EyeVectorModelSpace;
#endif
// } VorteX
uniform myhalf Alpha;
#ifdef VERTEX_SHADER
void main(void)
{
#ifdef USESKELETAL
	ivec4 si0 = ivec4(Attrib_SkeletalIndex * 3.0);
	ivec4 si1 = si0 + ivec4(1, 1, 1, 1);
	ivec4 si2 = si0 + ivec4(2, 2, 2, 2);
	vec4 sw = Attrib_SkeletalWeight;
	vec4 SkeletalMatrix1 = Skeletal_Transform12[si0.x] * sw.x + Skeletal_Transform12[si0.y] * sw.y + Skeletal_Transform12[si0.z] * sw.z + Skeletal_Transform12[si0.w] * sw.w;
	vec4 SkeletalMatrix2 = Skeletal_Transform12[si1.x] * sw.x + Skeletal_Transform12[si1.y] * sw.y + Skeletal_Transform12[si1.z] * sw.z + Skeletal_Transform12[si1.w] * sw.w;
	vec4 SkeletalMatrix3 = Skeletal_Transform12[si2.x] * sw.x + Skeletal_Transform12[si2.y] * sw.y + Skeletal_Transform12[si2.z] * sw.z + Skeletal_Transform12[si2.w] * sw.w;
	mat4 SkeletalMatrix = mat4(SkeletalMatrix1, SkeletalMatrix2, SkeletalMatrix3, vec4(0.0, 0.0, 0.0, 1.0));
	vec4 SkeletalVertex = Attrib_Position * SkeletalMatrix;
#define Attrib_Position SkeletalVertex
#endif
	VertexColor = Attrib_Color;
// VorteX {
#if defined(SHOWVERTEXALPHA) && defined(USEVEGETATION)
	VertexColor.rgb =  VegetationShow(VertexColor.rgb, VertexColor.a);
#endif
// } VorteX
#ifdef USEDIFFUSE
	TexCoord1 = Attrib_TexCoord0.xy;
#endif
#ifdef USESPECULAR
	TexCoord2 = Attrib_TexCoord1.xy;
#endif
// VorteX {
#ifdef USEFOG
	EyeVectorModelSpace = EyePosition - Attrib_Position.xyz;
#endif
#ifdef USEVEGETATION
	gl_Position = ModelViewProjectionMatrix * VegetationVertex(Attrib_Position, Attrib_Color.a);
#else
	gl_Position = ModelViewProjectionMatrix * Attrib_Position;
#endif
// } VorteX
#ifdef USETRIPPY
	gl_Position = TrippyVertex(gl_Position);
#endif
}
#endif

#ifdef FRAGMENT_SHADER
#ifdef USEDIFFUSE
uniform sampler2D Texture_First;
#endif
#ifdef USESPECULAR
uniform sampler2D Texture_Second;
#endif
#ifdef USEGAMMARAMPS
uniform sampler2D Texture_GammaRamps;
#endif

void main(void)
{
#ifdef USEVIEWTINT
	dp_FragColor = VertexColor;
#else
	dp_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
#endif
#ifdef USEDIFFUSE
# ifdef USEREFLECTCUBE
	// suppress texture alpha
	dp_FragColor.rgb *= dp_texture2D(Texture_First, TexCoord1).rgb;
# else
	dp_FragColor *= dp_texture2D(Texture_First, TexCoord1);
# endif
#endif

#ifdef USESPECULAR
	vec4 tex2 = dp_texture2D(Texture_Second, TexCoord2);
# ifdef USECOLORMAPPING
	dp_FragColor *= tex2;
# endif
# ifdef USEGLOW
	dp_FragColor += tex2;
# endif
# ifdef USEVERTEXTEXTUREBLEND
	dp_FragColor = mix(dp_FragColor, tex2, tex2.a);
# endif
#endif
// Vortex {
#ifdef USEFOG
#ifdef SHOWFOG
	dp_FragColor.rgb = FogVertex(vec4(0.0, 0.0, 0.0, 1.0), EyeVectorModelSpace, 0.0);
#else
	dp_FragColor.rgb = FogVertex(dp_FragColor, EyeVectorModelSpace, 0.0);
#endif
#endif
// } VorteX
#ifdef USEGAMMARAMPS
	dp_FragColor.r = dp_texture2D(Texture_GammaRamps, vec2(dp_FragColor.r, 0)).r;
	dp_FragColor.g = dp_texture2D(Texture_GammaRamps, vec2(dp_FragColor.g, 0)).g;
	dp_FragColor.b = dp_texture2D(Texture_GammaRamps, vec2(dp_FragColor.b, 0)).b;
#endif
#ifdef USEALPHAKILL
	dp_FragColor.a *= Alpha;
#endif
}
#endif
#else // !MODE_GENERIC




#ifdef MODE_BLOOMBLUR
dp_varying mediump vec2 TexCoord;
#ifdef VERTEX_SHADER
void main(void)
{
	VertexColor = Attrib_Color;
	TexCoord = Attrib_TexCoord0.xy;
	gl_Position = ModelViewProjectionMatrix * Attrib_Position;
}
#endif

#ifdef FRAGMENT_SHADER
uniform sampler2D Texture_First;
uniform mediump vec4 BloomBlur_Parameters;

void main(void)
{
	int i;
	vec2 tc = TexCoord;
	vec3 color = dp_texture2D(Texture_First, tc).rgb;
	tc += BloomBlur_Parameters.xy;
	for (i = 1;i < SAMPLES;i++)
	{
		color += dp_texture2D(Texture_First, tc).rgb;
		tc += BloomBlur_Parameters.xy;
	}
	dp_FragColor = vec4(color * BloomBlur_Parameters.z + vec3(BloomBlur_Parameters.w), 1);
}
#endif
#else // !MODE_BLOOMBLUR
#ifdef MODE_REFRACTION
dp_varying mediump vec2 TexCoord;
dp_varying highp vec4 ModelViewProjectionPosition;
uniform highp mat4 TexMatrix;
#ifdef VERTEX_SHADER

void main(void)
{
#ifdef USESKELETAL
	ivec4 si0 = ivec4(Attrib_SkeletalIndex * 3.0);
	ivec4 si1 = si0 + ivec4(1, 1, 1, 1);
	ivec4 si2 = si0 + ivec4(2, 2, 2, 2);
	vec4 sw = Attrib_SkeletalWeight;
	vec4 SkeletalMatrix1 = Skeletal_Transform12[si0.x] * sw.x + Skeletal_Transform12[si0.y] * sw.y + Skeletal_Transform12[si0.z] * sw.z + Skeletal_Transform12[si0.w] * sw.w;
	vec4 SkeletalMatrix2 = Skeletal_Transform12[si1.x] * sw.x + Skeletal_Transform12[si1.y] * sw.y + Skeletal_Transform12[si1.z] * sw.z + Skeletal_Transform12[si1.w] * sw.w;
	vec4 SkeletalMatrix3 = Skeletal_Transform12[si2.x] * sw.x + Skeletal_Transform12[si2.y] * sw.y + Skeletal_Transform12[si2.z] * sw.z + Skeletal_Transform12[si2.w] * sw.w;
	mat4 SkeletalMatrix = mat4(SkeletalMatrix1, SkeletalMatrix2, SkeletalMatrix3, vec4(0.0, 0.0, 0.0, 1.0));
	vec4 SkeletalVertex = Attrib_Position * SkeletalMatrix;
#define Attrib_Position SkeletalVertex
#endif
#ifdef USEALPHAGENVERTEX
	VertexColor = Attrib_Color;
// VorteX {
#if defined(SHOWVERTEXALPHA) && defined(USEVEGETATION)
	VertexColor.rgb =  VegetationShow(VertexColor.rgb, VertexColor.a);
#endif
// } VorteX
#endif
	TexCoord = vec2(TexMatrix * Attrib_TexCoord0);
// VorteX {
#ifdef USEVEGETATION
	gl_Position = ModelViewProjectionMatrix * VegetationVertex(Attrib_Position, Attrib_Color.a);
#else
	gl_Position = ModelViewProjectionMatrix * Attrib_Position;
#endif
// } VorteX
	ModelViewProjectionPosition = gl_Position;
#ifdef USETRIPPY
	gl_Position = TrippyVertex(gl_Position);
#endif
}
#endif

#ifdef FRAGMENT_SHADER
uniform sampler2D Texture_Normal;
uniform sampler2D Texture_Refraction;

uniform mediump vec4 DistortScaleRefractReflect;
uniform mediump vec4 ScreenScaleRefractReflect;
uniform mediump vec4 ScreenCenterRefractReflect;
uniform mediump vec4 RefractColor;
uniform mediump vec4 ReflectColor;
// VorteX {
#ifndef USECLIENTTIME
uniform highp float ClientTime;
#define USECLIENTTIME
#endif
// } VorteX
void main(void)
{
	vec2 ScreenScaleRefractReflectIW = ScreenScaleRefractReflect.xy * (1.0 / ModelViewProjectionPosition.w);
	//vec2 ScreenTexCoord = (ModelViewProjectionPosition.xy + normalize(vec3(dp_texture2D(Texture_Normal, TexCoord)) - vec3(0.5)).xy * DistortScaleRefractReflect.xy * 100) * ScreenScaleRefractReflectIW + ScreenCenterRefractReflect.xy;
	vec2 SafeScreenTexCoord = ModelViewProjectionPosition.xy * ScreenScaleRefractReflectIW + ScreenCenterRefractReflect.xy;
#ifdef USEALPHAGENVERTEX
	vec2 distort = DistortScaleRefractReflect.xy * VertexColor.a;
	vec4 refractcolor = mix(RefractColor, vec4(1.0, 1.0, 1.0, 1.0), VertexColor.a);
#else
	vec2 distort = DistortScaleRefractReflect.xy;
	vec4 refractcolor = RefractColor;
#endif
	#ifdef USENORMALMAPSCROLLBLEND
		vec3 normal = dp_texture2D(Texture_Normal, (TexCoord + vec2(0.08, 0.08)*ClientTime*NormalmapScrollBlend.x*0.5)*NormalmapScrollBlend.y).rgb - vec3(1.0);
		normal += dp_texture2D(Texture_Normal, (TexCoord + vec2(-0.06, -0.09)*ClientTime*NormalmapScrollBlend.x)*NormalmapScrollBlend.y*0.75).rgb;
		vec2 ScreenTexCoord = SafeScreenTexCoord + vec3(normalize(cast_myhalf3(normal))).xy * distort;
	#else
		vec2 ScreenTexCoord = SafeScreenTexCoord + vec3(normalize(cast_myhalf3(dp_texture2D(Texture_Normal, TexCoord)) - cast_myhalf3(0.5))).xy * distort;
	#endif
	// FIXME temporary hack to detect the case that the reflection
	// gets blackened at edges due to leaving the area that contains actual
	// content.
	// Remove this 'ack once we have a better way to stop this thing from
	// 'appening.
	float f = min(1.0, length(dp_texture2D(Texture_Refraction, ScreenTexCoord + vec2(0.01, 0.01)).rgb) / 0.05);
	f      *= min(1.0, length(dp_texture2D(Texture_Refraction, ScreenTexCoord + vec2(0.01, -0.01)).rgb) / 0.05);
	f      *= min(1.0, length(dp_texture2D(Texture_Refraction, ScreenTexCoord + vec2(-0.01, 0.01)).rgb) / 0.05);
	f      *= min(1.0, length(dp_texture2D(Texture_Refraction, ScreenTexCoord + vec2(-0.01, -0.01)).rgb) / 0.05);
	ScreenTexCoord = mix(SafeScreenTexCoord, ScreenTexCoord, f);
	dp_FragColor = vec4(dp_texture2D(Texture_Refraction, ScreenTexCoord).rgb, 1.0) * refractcolor;
}
#endif
#else // !MODE_REFRACTION




#ifdef MODE_WATER
dp_varying mediump vec2 TexCoord;
// VorteX {
dp_varying highp vec4 EyeVector;
dp_varying highp vec3 EyeRelative;
dp_varying highp vec4 ModelViewProjectionPosition;
dp_varying highp vec4 WaterFlow;
dp_varying highp vec3 WaterNormal;
#ifdef USESUNDIRECTION
dp_varying mediump vec3 SunlightVector;
uniform mediump vec4 SunlightColor;
#endif
// } VorteX
#ifdef VERTEX_SHADER
uniform highp vec3 EyePosition;
uniform highp mat4 TexMatrix;
// VorteX {
#ifdef USESUNDIRECTION
uniform mediump vec4 SunlightDir;
#endif
// } VorteX

void main(void)
{
#ifdef USESKELETAL
	ivec4 si0 = ivec4(Attrib_SkeletalIndex * 3.0);
	ivec4 si1 = si0 + ivec4(1, 1, 1, 1);
	ivec4 si2 = si0 + ivec4(2, 2, 2, 2);
	vec4 sw = Attrib_SkeletalWeight;
	vec4 SkeletalMatrix1 = Skeletal_Transform12[si0.x] * sw.x + Skeletal_Transform12[si0.y] * sw.y + Skeletal_Transform12[si0.z] * sw.z + Skeletal_Transform12[si0.w] * sw.w;
	vec4 SkeletalMatrix2 = Skeletal_Transform12[si1.x] * sw.x + Skeletal_Transform12[si1.y] * sw.y + Skeletal_Transform12[si1.z] * sw.z + Skeletal_Transform12[si1.w] * sw.w;
	vec4 SkeletalMatrix3 = Skeletal_Transform12[si2.x] * sw.x + Skeletal_Transform12[si2.y] * sw.y + Skeletal_Transform12[si2.z] * sw.z + Skeletal_Transform12[si2.w] * sw.w;
	mat4 SkeletalMatrix = mat4(SkeletalMatrix1, SkeletalMatrix2, SkeletalMatrix3, vec4(0.0, 0.0, 0.0, 1.0));
	mat3 SkeletalNormalMatrix = mat3(cross(SkeletalMatrix[1].xyz, SkeletalMatrix[2].xyz), cross(SkeletalMatrix[2].xyz, SkeletalMatrix[0].xyz), cross(SkeletalMatrix[0].xyz, SkeletalMatrix[1].xyz)); // is actually transpose(inverse(mat3(SkeletalMatrix))) * det(mat3(SkeletalMatrix))
	vec4 SkeletalVertex = Attrib_Position * SkeletalMatrix;
	vec3 SkeletalSVector = normalize(Attrib_TexCoord1.xyz * SkeletalNormalMatrix);
	vec3 SkeletalTVector = normalize(Attrib_TexCoord2.xyz * SkeletalNormalMatrix);
	vec3 SkeletalNormal  = normalize(Attrib_TexCoord3.xyz * SkeletalNormalMatrix);
#define Attrib_Position SkeletalVertex
#define Attrib_TexCoord1 SkeletalSVector
#define Attrib_TexCoord2 SkeletalTVector
#define Attrib_TexCoord3 SkeletalNormal
#endif
#ifdef USEALPHAGENVERTEX
	VertexColor = Attrib_Color;
// VorteX {
#if defined(SHOWVERTEXALPHA) && defined(USEVEGETATION)
	VertexColor.rgb =  VegetationShow(VertexColor.rgb, VertexColor.a);
#endif
// } VorteX
#endif
	TexCoord = vec2(TexMatrix * Attrib_TexCoord0);
// VorteX {
	EyeRelative = EyePosition - Attrib_Position.xyz;
#ifdef USESUNDIRECTION
	// transform unnormalized sun direction into tangent space
	SunlightVector.x = dot(SunlightDir.xyz, Attrib_TexCoord1.xyz);
	SunlightVector.y = dot(SunlightDir.xyz, Attrib_TexCoord2.xyz);
	SunlightVector.z = dot(SunlightDir.xyz, Attrib_TexCoord3.xyz);
	SunlightVector = normalize(SunlightVector);
#endif
// } VorteX
	EyeVector.x = dot(EyeRelative, Attrib_TexCoord1.xyz);
	EyeVector.y = dot(EyeRelative, Attrib_TexCoord2.xyz);
	EyeVector.z = dot(EyeRelative, Attrib_TexCoord3.xyz);
// VorteX {
	EyeVector.w = 0;
	WaterFlow = vec4(Attrib_Color.x, Attrib_Color.y, Attrib_Color.z, Attrib_Color.a );
	WaterNormal = Attrib_TexCoord3.xyz;
#ifdef USEVEGETATION
	gl_Position = ModelViewProjectionMatrix * VegetationVertex(Attrib_Position, Attrib_Color.a);
#else
	gl_Position = ModelViewProjectionMatrix * Attrib_Position;
#endif
// } VorteX
	ModelViewProjectionPosition = gl_Position;
#ifdef USETRIPPY
	gl_Position = TrippyVertex(gl_Position);
#endif
}
#endif

#ifdef FRAGMENT_SHADER
uniform sampler2D Texture_Normal;
uniform sampler2D Texture_Gloss; // VorteX
uniform sampler2D Texture_Refraction;
uniform sampler2D Texture_Reflection;

uniform myhalf3 Color_Specular; // VorteX
uniform myhalf SpecularPower; // VorteX

uniform mediump vec4 DistortScaleRefractReflect;
uniform mediump vec4 ScreenScaleRefractReflect;
uniform mediump vec4 ScreenCenterRefractReflect;
uniform mediump vec4 RefractColor;
uniform mediump vec4 ReflectColor;
uniform mediump float ReflectFactor;
uniform mediump float ReflectOffset;
// VorteX {
#ifndef USECLIENTTIME
uniform highp float ClientTime;
#define USECLIENTTIME
#endif

uniform mediump vec2 PixelSize;

#ifdef USEGAMMARAMPS
uniform sampler2D Texture_GammaRamps;
#endif

void main(void)
{
	vec4 SafeScreenTexCoord = ModelViewProjectionPosition.xyxy * (ScreenScaleRefractReflect * (1.0 / ModelViewProjectionPosition.w)) + ScreenCenterRefractReflect;

	myhalf waterflow_s = sqrt(WaterFlow.a);
#ifdef USESCROLLBLEND
	myhalf3 surfacenormal = cast_myhalf3(normalize(mix(myhalf3(0.0, 0.0, 0.5), ScrollBlendNormalmap(Texture_Normal, TexCoord), WaterFlow.z * WaterFlow.z)));
	myhalf4 glosstex = ScrollBlendTexture(Texture_Gloss, TexCoord, surfacenormal);
#else
	myhalf3 surfacenormal = normalize(dp_texture2D(Texture_Normal, TexCoord).rgb - vec3(0.5));
	myhalf4 glosstex = normalize(dp_texture2D(Texture_Gloss, TexCoord));
#endif
	// calculate sun specular
	vec3 eyenormal = normalize(EyeVector.xyz);
#ifdef USESUNDIRECTION
	#define SUNSPECULARCOLOR mix(sunspecularcolor, glosstex.rgb * sunspecularcolor * 5.0, 0.5)
	float   sunenv = max(-0.25, (dot(surfacenormal, eyenormal) - dot(vec3(0.0, 0.0, 0.92), eyenormal)) / 0.08 - 0.2);
	float   eyemod = max(0.001, pow(1.0 - eyenormal.z, 7.0));
	myhalf  sunspecular = (pow(cast_myhalf(max(float(dot(reflect(SunlightVector, surfacenormal), eyenormal))*-1.0, 0.0)), SpecularPower) * 0.3 + sunenv*sunenv*sunenv*sunenv*sunenv * 70.0 * eyemod) * Color_Specular.x * waterflow_s;
	myhalf3 sunspecularcolor = (myhalf3(0.25) + normalize(myhalf3(0.25) + SunlightColor.rgb)) * length(SunlightColor.rgb) * sunspecular;
#else
	#define SUNSPECULARCOLOR mix(sunspecularcolor, glosstex.rgb * sunspecularcolor * 5.0, 0.5)
	myhalf  sunspecular = 0;
	myhalf3 sunspecularcolor = vec3(sunspecular * 0.65);
#endif
	// calculate fresnel
	myhalf fresnel = min(1.0, min(1.0, 1.0 - float(eyenormal.z)) * ReflectFactor + ReflectOffset);
	// distort
	vec4 screentx = SafeScreenTexCoord + vec2(surfacenormal).xyxy * DistortScaleRefractReflect * waterflow_s * (1.0 - sunspecular);
	// refract blur
#define WATER_REFRACTBLUR
#ifdef WATER_REFRACTBLUR
	myhalf blur = WaterFlow.a * WaterFlow.z * 1.0;
	myhalf radius = 1.0;
	myhalf3 refract  = dp_texture2D(Texture_Refraction, screentx.xy + PixelSize.xy*blur*vec2(-0.987688, -0.156434)).rgb * radius;
		    refract += dp_texture2D(Texture_Refraction, screentx.xy + PixelSize.xy*blur*vec2(-0.156434, -0.891007)).rgb * radius;
		    refract += dp_texture2D(Texture_Refraction, screentx.xy + PixelSize.xy*blur*vec2( 0.891007, -0.453990)).rgb * radius;
		    refract += dp_texture2D(Texture_Refraction, screentx.xy + PixelSize.xy*blur*vec2( 0.707107,  0.707107)).rgb * radius;
		    refract += dp_texture2D(Texture_Refraction, screentx.xy + PixelSize.xy*blur*vec2(-0.453990,  0.891007)).rgb * radius;
		    refract /= (1.0 + 5.0 * radius);
#else
	myhalf3 refract = dp_texture2D(Texture_Refraction, screentx.xy).rgb;
#endif
	// blend refract & reflect
	dp_FragColor.rgb = mix(refract * mix(vec3(1.0), RefractColor.rgb, WaterFlow.a), dp_texture2D(Texture_Reflection, screentx.zw).rgb * ReflectColor.rgb, (sunspecular + fresnel) * waterflow_s) + SUNSPECULARCOLOR;
	dp_FragColor.a = pow(max(0.0, min(1.0, (WaterFlow.a - 0.05) / 0.2)), eyenormal.z);
#ifdef USESUNDIRECTION
	if (sunenv < 0.3)
		dp_FragColor.rgb = mix(dp_FragColor.rgb, dp_FragColor.rgb * 0.66, sqrt(1.0 - sunenv / 0.3) * (1 + eyemod)*0.5);
#endif
	// darken effect (for bloodfountain)
	dp_FragColor.rgb *= pow(dot(normalize(WaterNormal), vec3(0.0, 0.0, 1.0)), 32.0);
#ifdef USEFOG
	dp_FragColor.rgb = mix(dp_FragColor.rgb, FogVertex(dp_FragColor, EyeRelative, EyeVector.w), max(fresnel, (1.0 + waterflow_s) * 0.5));
#endif
#ifdef USEGAMMARAMPS
	dp_FragColor.r = dp_texture2D(Texture_GammaRamps, vec2(dp_FragColor.r, 0)).r;
	dp_FragColor.g = dp_texture2D(Texture_GammaRamps, vec2(dp_FragColor.g, 0)).g;
	dp_FragColor.b = dp_texture2D(Texture_GammaRamps, vec2(dp_FragColor.b, 0)).b;
#endif
}
#endif
#else // !MODE_WATER
// } VorteX




// common definitions between vertex shader and fragment shader:

dp_varying mediump vec4 TexCoordSurfaceLightmap;
#ifdef USEVERTEXTEXTUREBLEND
dp_varying mediump vec2 TexCoord2;
#endif

#ifdef MODE_LIGHTSOURCE
dp_varying mediump vec3 CubeVector;
#endif

#if (defined(MODE_LIGHTSOURCE) || defined(MODE_LIGHTDIRECTION)) && defined(USEDIFFUSE)
dp_varying mediump vec3 LightVector;
#endif

#ifdef USEEYEVECTOR
dp_varying highp vec4 EyeVectorFogDepth;
#endif

#if defined(MODE_LIGHTDIRECTIONMAP_MODELSPACE) || defined(MODE_DEFERREDGEOMETRY) || defined(USEREFLECTCUBE) || defined(USEBOUNCEGRIDDIRECTIONAL)
dp_varying highp vec4 VectorS; // direction of S texcoord (sometimes crudely called tangent)
dp_varying highp vec4 VectorT; // direction of T texcoord (sometimes crudely called binormal)
dp_varying highp vec4 VectorR; // direction of R texcoord (surface normal)
#else
# ifdef USEFOG
dp_varying highp vec3 EyeVectorModelSpace;
# endif
#endif

#ifdef USEREFLECTION
dp_varying highp vec4 ModelViewProjectionPosition;
#endif
#ifdef MODE_DEFERREDLIGHTSOURCE
uniform highp vec3 LightPosition;
dp_varying highp vec4 ModelViewPosition;
#endif

#ifdef MODE_LIGHTSOURCE
uniform highp vec3 LightPosition;
#endif
uniform highp vec3 EyePosition;
#ifdef MODE_LIGHTDIRECTION
uniform highp vec3 LightDir;
#endif
uniform highp vec4 FogPlane;

#ifdef USESHADOWMAPORTHO
dp_varying highp vec3 ShadowMapTC;
#endif

#ifdef USEBOUNCEGRID
dp_varying highp vec3 BounceGridTexCoord;
#endif

#ifdef MODE_DEFERREDGEOMETRY
dp_varying highp float Depth;
#endif






// TODO: get rid of tangentt (texcoord2) and use a crossproduct to regenerate it from tangents (texcoord1) and normal (texcoord3), this would require sending a 4 component texcoord1 with W as 1 or -1 according to which side the texcoord2 should be on

// fragment shader specific:
#ifdef FRAGMENT_SHADER

uniform sampler2D Texture_Normal;
uniform sampler2D Texture_Color;
uniform sampler2D Texture_Gloss;
// VorteX {
#ifdef USECELTEXTURING
uniform highp vec4 Color_Average;
#endif
// } VorteX
#ifdef USEGLOW
uniform sampler2D Texture_Glow;
#endif
#ifdef USEVERTEXTEXTUREBLEND
uniform sampler2D Texture_SecondaryNormal;
uniform sampler2D Texture_SecondaryColor;
uniform sampler2D Texture_SecondaryGloss;
// VorteX {
#ifdef USECELTEXTURING
uniform highp vec4 Color_SecondaryAverage;
#endif
// } VorteX
#ifdef USEGLOW
uniform sampler2D Texture_SecondaryGlow;
#endif
#endif
#ifdef USECOLORMAPPING
uniform sampler2D Texture_Pants;
uniform sampler2D Texture_Shirt;
#endif
// VorteX {
//#ifdef USEFOG
//#ifdef USEFOGHEIGHTTEXTURE
//uniform sampler2D Texture_FogHeightTexture;
//#endif
//uniform sampler2D Texture_FogMask;
//#endif
// } VorteX
#ifdef USELIGHTMAP
uniform sampler2D Texture_Lightmap;
#endif
#if defined(MODE_LIGHTDIRECTIONMAP_MODELSPACE) || defined(MODE_LIGHTDIRECTIONMAP_TANGENTSPACE)
uniform sampler2D Texture_Deluxemap;
#endif
#ifdef USEREFLECTION
uniform sampler2D Texture_Reflection;
#endif

#ifdef MODE_DEFERREDLIGHTSOURCE
uniform sampler2D Texture_ScreenNormalMap;
#endif
#ifdef USEDEFERREDLIGHTMAP
#ifdef USECELOUTLINES
uniform sampler2D Texture_ScreenNormalMap;
#endif
uniform sampler2D Texture_ScreenDiffuse;
uniform sampler2D Texture_ScreenSpecular;
#endif

uniform mediump vec3 Color_Pants;
uniform mediump vec3 Color_Shirt;

// VorteX {
#ifdef USEGAMMARAMPS
uniform sampler2D Texture_GammaRamps;
#endif

#if defined(USEOFFSETMAPPING) || defined(USESELFSHADOWING)
uniform mediump vec4 OffsetMapping_ScaleSteps;
uniform mediump float OffsetMapping_Bias;
uniform mediump vec2 PixelSize;
#ifdef USEOFFSETMAPPING_LOD
uniform mediump float OffsetMapping_LodDistance;
#endif
#endif
#ifdef USEOFFSETMAPPING
#ifdef USEOFFSETMAPPING_NONSQUARETEXTURES
	#define USEOFFSETMAPPING_NONSQUARETEXTURES_FIX(ov) ov.x *= min(1.0, PixelSize.x / PixelSize.y); ov.y *= min(1.0, PixelSize.y / PixelSize.x);
#else
	#define USEOFFSETMAPPING_NONSQUARETEXTURES_FIX(ov)
#endif
#ifdef USEVERTEXTEXTUREBLEND
vec2 OffsetMapping(vec2 TexCoord, vec2 dPdx, vec2 dPdy, float scale)
#else
vec2 OffsetMapping(vec2 TexCoord, vec2 dPdx, vec2 dPdy)
#endif
{
	float i;
	// distance-based LOD
#ifdef USEOFFSETMAPPING_LOD
	mediump float GuessLODFactor = min(1.0, OffsetMapping_LodDistance / EyeVectorFogDepth.z);
#ifdef USEOFFSETMAPPING_RELIEFMAPPING
	// stupid workaround because 1-step and 2-step reliefmapping is void
	mediump float LODSteps = max(3.0, ceil(GuessLODFactor * OffsetMapping_ScaleSteps.y));
#else
	mediump float LODSteps = ceil(GuessLODFactor * OffsetMapping_ScaleSteps.y);
#endif
	mediump float LODFactor = LODSteps / OffsetMapping_ScaleSteps.y;
	mediump vec4 ScaleSteps = vec4(OffsetMapping_ScaleSteps.x, LODSteps, 1.0 / LODSteps, OffsetMapping_ScaleSteps.w * LODFactor);
#else
	#define ScaleSteps OffsetMapping_ScaleSteps
#endif
#ifdef USEOFFSETMAPPING_RELIEFMAPPING
	float f;
	vec3 EyeVector = normalize(EyeVectorFogDepth.xyz);
#ifdef USEVERTEXTEXTUREBLEND
	vec3 OffsetVector = vec3(EyeVector.xy / max(0.66, EyeVector.z) * ScaleSteps.x * vec2(-1, 1) * scale, -1);
#else
	vec3 OffsetVector = vec3(EyeVector.xy / max(0.66, EyeVector.z) * ScaleSteps.x * vec2(-1, 1), -1);
#endif
	USEOFFSETMAPPING_NONSQUARETEXTURES_FIX(OffsetVector)
	vec3 RT = vec3(vec2(TexCoord.xy - OffsetVector.xy*OffsetMapping_Bias), 1);
	OffsetVector *= ScaleSteps.z;
	for(i = 1.0; i < ScaleSteps.y; ++i)
		RT += OffsetVector *  step(dp_textureGrad(Texture_Normal, RT.xy, dPdx, dPdy).a, RT.z);
	for(i = 0.0, f = 1.0; i < ScaleSteps.w; ++i, f *= 0.5)
		RT += OffsetVector * (step(dp_textureGrad(Texture_Normal, RT.xy, dPdx, dPdy).a, RT.z) * f - 0.5 * f);
	return RT.xy;
#else
#ifdef USEVERTEXTEXTUREBLEND
	vec2 OffsetVector = vec2(normalize(EyeVectorFogDepth.xyz).xy * ScaleSteps.x * scale * vec2(-1, 1));
#else
	vec2 OffsetVector = vec2(EyeVectorFogDepth.xy / max(0.66, EyeVectorFogDepth.z) * ScaleSteps.x * vec2(-1, 1));
#endif
	USEOFFSETMAPPING_NONSQUARETEXTURES_FIX(OffsetVector)
	OffsetVector *= ScaleSteps.z;
	for(i = 0.0; i < ScaleSteps.y; ++i)
		TexCoord += OffsetVector * ((1.0 - OffsetMapping_Bias) - dp_textureGrad(Texture_Normal, TexCoord, dPdx, dPdy).a);
	return TexCoord;
#endif
}
#endif // USEOFFSETMAPPING
#ifdef USESELFSHADOWING
uniform mediump vec4 SelfShadowing_Parameters;
#ifdef USEVERTEXTEXTUREBLEND
float SelfShadowing(myhalf3 LightVector, vec2 TexCoord, vec2 dPdx, vec2 dPdy, float StepScale)
#else
float SelfShadowing(myhalf3 LightVector, vec2 TexCoord, vec2 dPdx, vec2 dPdy)
#endif
{
	// surface should be oriented to light source
	if( LightVector.z < 0 )
		return 1.0;
	// renormalize direction
	LightVector = normalize(LightVector);
	LightVector.z = max(0.05, LightVector.z);
	// calculate layers count
#ifdef USEOFFSETMAPPING_LOD
	mediump float n = max(3.0, mix(40.0, 10.0, LightVector.z) * min(1.0, sqrt(OffsetMapping_LodDistance / EyeVectorFogDepth.z)));
#else
	mediump float n = mix(40.0, 10.0, LightVector.z);
#endif
	// calculate initial parms
#ifdef USEVERTEXTEXTUREBLEND
	vec2 TexStep = -SelfShadowing_Parameters.x * LightVector.xy / LightVector.z / n * vec2(-1, 1) * StepScale;
#else
	vec2 TexStep = -SelfShadowing_Parameters.x * LightVector.xy / LightVector.z / n * vec2(-1, 1);
#endif
	USEOFFSETMAPPING_NONSQUARETEXTURES_FIX(TexStep)
	TexCoord -= TexStep*SelfShadowing_Parameters.y; // initial tex coord
	float h = 1.0 - dp_textureGrad(Texture_Normal, TexCoord, dPdx, dPdy).a; // initial height
	float lh = h / n; // layer height
	float clh = h - lh; // current layer height
	vec2 tc = TexCoord + TexStep; // current texcoord
	// while point is below depth 0.0
	int i = 1;
	float f = 0.0;
	h = 1.0 - dp_textureGrad(Texture_Normal, tc, dPdx, dPdy).a;
	while( clh > 0.0 )
	{
		// if point is under the surface, calculate partial shadowing factor
		if( ( clh - h ) > 0 )
			f = max(f, (clh - h) * (i / n));
		// offset to the next layer
		i += 1;
		clh -= lh;
		tc += TexStep;
		h = 1.0 - dp_textureGrad(Texture_Normal, tc, dPdx, dPdy).a;
	}
	// return
	return pow(1.0 - f, 32.0 * SelfShadowing_Parameters.a);
}
#endif // USESELFSHADOWING
// } VorteX

#if defined(MODE_LIGHTSOURCE) || defined(MODE_DEFERREDLIGHTSOURCE)
uniform sampler2D Texture_Attenuation;
uniform samplerCube Texture_Cube;
#endif

#if defined(MODE_LIGHTSOURCE) || defined(MODE_DEFERREDLIGHTSOURCE) || defined(USESHADOWMAPORTHO)

#ifdef USESHADOWMAP2D
# ifdef USESHADOWSAMPLER
uniform sampler2DShadow Texture_ShadowMap2D;
# else
uniform sampler2D Texture_ShadowMap2D;
# endif
#endif

#ifdef USESHADOWMAPVSDCT
uniform samplerCube Texture_CubeProjection;
#endif

#if defined(USESHADOWMAP2D)
uniform mediump vec4 ShadowMap_TextureScale;
uniform mediump vec4 ShadowMap_Parameters;
#endif

#if defined(USESHADOWMAP2D)
# ifdef USESHADOWMAPORTHO
#  define GetShadowMapTC2D(dir) (max(vec3(0.0, 0.0, 0.0), min(dir, ShadowMap_Parameters.xyz)))
# else
#  ifdef USESHADOWMAPVSDCT
vec3 GetShadowMapTC2D(vec3 dir)
{
	vec3 adir = abs(dir);
	float m = max(max(adir.x, adir.y), adir.z);
	vec4 proj = dp_textureCube(Texture_CubeProjection, dir);
#ifdef USEDEPTHRGB
	return vec3(mix(dir.xy, dir.zz, proj.xy) * (ShadowMap_Parameters.x / m) +  proj.zw * ShadowMap_Parameters.z, m + 64.0 * ShadowMap_Parameters.w);
#else
	vec2 mparams = ShadowMap_Parameters.xy / m;
	return vec3(mix(dir.xy, dir.zz, proj.xy) * mparams.x + proj.zw * ShadowMap_Parameters.z, mparams.y + ShadowMap_Parameters.w);
#endif
}
#  else
vec3 GetShadowMapTC2D(vec3 dir)
{
	vec3 adir = abs(dir);
	float m; vec4 proj;
	if (adir.x > adir.y) { m = adir.x; proj = vec4(dir.zyx, 0.5); } else { m = adir.y; proj = vec4(dir.xzy, 1.5); }
	if (adir.z > m) { m = adir.z; proj = vec4(dir, 2.5); }
#ifdef USEDEPTHRGB
	return vec3(proj.xy * (ShadowMap_Parameters.x / m) + vec2(0.5,0.5) + vec2(proj.z < 0.0 ? 1.5 : 0.5, proj.w) * ShadowMap_Parameters.z, m + 64.0 * ShadowMap_Parameters.w);
#else
	vec2 mparams = ShadowMap_Parameters.xy / m;
	return vec3(proj.xy * mparams.x + vec2(proj.z < 0.0 ? 1.5 : 0.5, proj.w) * ShadowMap_Parameters.z, mparams.y + ShadowMap_Parameters.w);
#endif
}
#  endif
# endif
#endif // defined(USESHADOWMAP2D)

# ifdef USESHADOWMAP2D
float ShadowMapCompare(vec3 dir)
{
	vec3 shadowmaptc = GetShadowMapTC2D(dir) + vec3(ShadowMap_TextureScale.zw, 0.0f);
	float f;

#  ifdef USEDEPTHRGB
#   ifdef USESHADOWMAPPCF
#    define texval(x, y) decodedepthmacro(dp_texture2D(Texture_ShadowMap2D, center + vec2(x, y)*ShadowMap_TextureScale.xy))
#    if USESHADOWMAPPCF > 1
	vec2 center = shadowmaptc.xy - 0.5, offset = fract(center);
	center *= ShadowMap_TextureScale.xy;
	vec4 row1 = step(shadowmaptc.z, vec4(texval(-1.0, -1.0), texval( 0.0, -1.0), texval( 1.0, -1.0), texval( 2.0, -1.0)));
	vec4 row2 = step(shadowmaptc.z, vec4(texval(-1.0,  0.0), texval( 0.0,  0.0), texval( 1.0,  0.0), texval( 2.0,  0.0)));
	vec4 row3 = step(shadowmaptc.z, vec4(texval(-1.0,  1.0), texval( 0.0,  1.0), texval( 1.0,  1.0), texval( 2.0,  1.0)));
	vec4 row4 = step(shadowmaptc.z, vec4(texval(-1.0,  2.0), texval( 0.0,  2.0), texval( 1.0,  2.0), texval( 2.0,  2.0)));
	vec4 cols = row2 + row3 + mix(row1, row4, offset.y);
	f = dot(mix(cols.xyz, cols.yzw, offset.x), vec3(1.0/9.0));
#    else
	vec2 center = shadowmaptc.xy*ShadowMap_TextureScale.xy, offset = fract(shadowmaptc.xy);
	vec3 row1 = step(shadowmaptc.z, vec3(texval(-1.0, -1.0), texval( 0.0, -1.0), texval( 1.0, -1.0)));
	vec3 row2 = step(shadowmaptc.z, vec3(texval(-1.0,  0.0), texval( 0.0,  0.0), texval( 1.0,  0.0)));
	vec3 row3 = step(shadowmaptc.z, vec3(texval(-1.0,  1.0), texval( 0.0,  1.0), texval( 1.0,  1.0)));
	vec3 cols = row2 + mix(row1, row3, offset.y);
	f = dot(mix(cols.xy, cols.yz, offset.x), vec2(0.25));
#    endif
#   else
	f = step(shadowmaptc.z, decodedepthmacro(dp_texture2D(Texture_ShadowMap2D, shadowmaptc.xy*ShadowMap_TextureScale.xy)));
#   endif
#  else
#   ifdef USESHADOWSAMPLER
#     ifdef USESHADOWMAPPCF
#       define texval(off) dp_shadow2D(Texture_ShadowMap2D, vec3(off, shadowmaptc.z))  
	vec2 offset = fract(shadowmaptc.xy - 0.5);
   vec4 size = vec4(offset + 1.0, 2.0 - offset);
#       if USESHADOWMAPPCF > 1
   vec2 center = (shadowmaptc.xy - offset + 0.5)*ShadowMap_TextureScale.xy;
   vec4 weight = (vec4(-1.5, -1.5, 2.0, 2.0) + (shadowmaptc.xy - 0.5*offset).xyxy)*ShadowMap_TextureScale.xyxy;
	f = (1.0/25.0)*dot(size.zxzx*size.wwyy, vec4(texval(weight.xy), texval(weight.zy), texval(weight.xw), texval(weight.zw))) +
		(2.0/25.0)*dot(size, vec4(texval(vec2(weight.z, center.y)), texval(vec2(center.x, weight.w)), texval(vec2(weight.x, center.y)), texval(vec2(center.x, weight.y)))) +
		(4.0/25.0)*texval(center);
#       else
	vec4 weight = (vec4(1.0, 1.0, -0.5, -0.5) + (shadowmaptc.xy - 0.5*offset).xyxy)*ShadowMap_TextureScale.xyxy;
	f = (1.0/9.0)*dot(size.zxzx*size.wwyy, vec4(texval(weight.zw), texval(weight.xw), texval(weight.zy), texval(weight.xy)));
#       endif        
#     else
	f = dp_shadow2D(Texture_ShadowMap2D, vec3(shadowmaptc.xy*ShadowMap_TextureScale.xy, shadowmaptc.z));
#     endif
#   else
#     ifdef USESHADOWMAPPCF
#      if defined(GL_ARB_texture_gather) || defined(GL_AMD_texture_texture4)
#       ifdef GL_ARB_texture_gather
#         define texval(x, y) textureGatherOffset(Texture_ShadowMap2D, center, ivec2(x, y))
#       else
#         define texval(x, y) texture4(Texture_ShadowMap2D, center + vec2(x, y)*ShadowMap_TextureScale.xy)
#       endif
	vec2 offset = fract(shadowmaptc.xy - 0.5), center = (shadowmaptc.xy - offset)*ShadowMap_TextureScale.xy;
#       if USESHADOWMAPPCF > 1
   vec4 group1 = step(shadowmaptc.z, texval(-2.0, -2.0));
   vec4 group2 = step(shadowmaptc.z, texval( 0.0, -2.0));
   vec4 group3 = step(shadowmaptc.z, texval( 2.0, -2.0));
   vec4 group4 = step(shadowmaptc.z, texval(-2.0,  0.0));
   vec4 group5 = step(shadowmaptc.z, texval( 0.0,  0.0));
   vec4 group6 = step(shadowmaptc.z, texval( 2.0,  0.0));
   vec4 group7 = step(shadowmaptc.z, texval(-2.0,  2.0));
   vec4 group8 = step(shadowmaptc.z, texval( 0.0,  2.0));
   vec4 group9 = step(shadowmaptc.z, texval( 2.0,  2.0));
	vec4 locols = vec4(group1.ab, group3.ab);
	vec4 hicols = vec4(group7.rg, group9.rg);
	locols.yz += group2.ab;
	hicols.yz += group8.rg;
	vec4 midcols = vec4(group1.rg, group3.rg) + vec4(group7.ab, group9.ab) +
				vec4(group4.rg, group6.rg) + vec4(group4.ab, group6.ab) +
				mix(locols, hicols, offset.y);
	vec4 cols = group5 + vec4(group2.rg, group8.ab);
	cols.xyz += mix(midcols.xyz, midcols.yzw, offset.x);
	f = dot(cols, vec4(1.0/25.0));
#      else
	vec4 group1 = step(shadowmaptc.z, texval(-1.0, -1.0));
	vec4 group2 = step(shadowmaptc.z, texval( 1.0, -1.0));
	vec4 group3 = step(shadowmaptc.z, texval(-1.0,  1.0));
	vec4 group4 = step(shadowmaptc.z, texval( 1.0,  1.0));
	vec4 cols = vec4(group1.rg, group2.rg) + vec4(group3.ab, group4.ab) +
				mix(vec4(group1.ab, group2.ab), vec4(group3.rg, group4.rg), offset.y);
	f = dot(mix(cols.xyz, cols.yzw, offset.x), vec3(1.0/9.0));
#       endif
#      else
#       ifdef GL_EXT_gpu_shader4
#         define texval(x, y) dp_textureOffset(Texture_ShadowMap2D, center, x, y).r
#       else
#         define texval(x, y) dp_texture2D(Texture_ShadowMap2D, center + vec2(x, y)*ShadowMap_TextureScale.xy).r  
#       endif
#       if USESHADOWMAPPCF > 1
	vec2 center = shadowmaptc.xy - 0.5, offset = fract(center);
	center *= ShadowMap_TextureScale.xy;
	vec4 row1 = step(shadowmaptc.z, vec4(texval(-1.0, -1.0), texval( 0.0, -1.0), texval( 1.0, -1.0), texval( 2.0, -1.0)));
	vec4 row2 = step(shadowmaptc.z, vec4(texval(-1.0,  0.0), texval( 0.0,  0.0), texval( 1.0,  0.0), texval( 2.0,  0.0)));
	vec4 row3 = step(shadowmaptc.z, vec4(texval(-1.0,  1.0), texval( 0.0,  1.0), texval( 1.0,  1.0), texval( 2.0,  1.0)));
	vec4 row4 = step(shadowmaptc.z, vec4(texval(-1.0,  2.0), texval( 0.0,  2.0), texval( 1.0,  2.0), texval( 2.0,  2.0)));
	vec4 cols = row2 + row3 + mix(row1, row4, offset.y);
	f = dot(mix(cols.xyz, cols.yzw, offset.x), vec3(1.0/9.0));
#       else
	vec2 center = shadowmaptc.xy*ShadowMap_TextureScale.xy, offset = fract(shadowmaptc.xy);
	vec3 row1 = step(shadowmaptc.z, vec3(texval(-1.0, -1.0), texval( 0.0, -1.0), texval( 1.0, -1.0)));
	vec3 row2 = step(shadowmaptc.z, vec3(texval(-1.0,  0.0), texval( 0.0,  0.0), texval( 1.0,  0.0)));
	vec3 row3 = step(shadowmaptc.z, vec3(texval(-1.0,  1.0), texval( 0.0,  1.0), texval( 1.0,  1.0)));
	vec3 cols = row2 + mix(row1, row3, offset.y);
	f = dot(mix(cols.xy, cols.yz, offset.x), vec2(0.25));
#       endif
#      endif
#     else
	f = step(shadowmaptc.z, dp_texture2D(Texture_ShadowMap2D, shadowmaptc.xy*ShadowMap_TextureScale.xy).r);
#     endif
#   endif
#  endif
#  ifdef USESHADOWMAPORTHO
	return mix(ShadowMap_Parameters.w, 1.0, f);
#  else
	return f;
#  endif
}
# endif
#endif // !defined(MODE_LIGHTSOURCE) && !defined(MODE_DEFERREDLIGHTSOURCE) && !defined(USESHADOWMAPORTHO)
#endif // FRAGMENT_SHADER




#ifdef MODE_DEFERREDGEOMETRY
#ifdef VERTEX_SHADER
uniform highp mat4 TexMatrix;
#ifdef USEVERTEXTEXTUREBLEND
uniform highp mat4 BackgroundTexMatrix;
#endif
uniform highp mat4 ModelViewMatrix;
void main(void)
{
#ifdef USESKELETAL
	ivec4 si0 = ivec4(Attrib_SkeletalIndex * 3.0);
	ivec4 si1 = si0 + ivec4(1, 1, 1, 1);
	ivec4 si2 = si0 + ivec4(2, 2, 2, 2);
	vec4 sw = Attrib_SkeletalWeight;
	vec4 SkeletalMatrix1 = Skeletal_Transform12[si0.x] * sw.x + Skeletal_Transform12[si0.y] * sw.y + Skeletal_Transform12[si0.z] * sw.z + Skeletal_Transform12[si0.w] * sw.w;
	vec4 SkeletalMatrix2 = Skeletal_Transform12[si1.x] * sw.x + Skeletal_Transform12[si1.y] * sw.y + Skeletal_Transform12[si1.z] * sw.z + Skeletal_Transform12[si1.w] * sw.w;
	vec4 SkeletalMatrix3 = Skeletal_Transform12[si2.x] * sw.x + Skeletal_Transform12[si2.y] * sw.y + Skeletal_Transform12[si2.z] * sw.z + Skeletal_Transform12[si2.w] * sw.w;
	mat4 SkeletalMatrix = mat4(SkeletalMatrix1, SkeletalMatrix2, SkeletalMatrix3, vec4(0.0, 0.0, 0.0, 1.0));
	mat3 SkeletalNormalMatrix = mat3(cross(SkeletalMatrix[1].xyz, SkeletalMatrix[2].xyz), cross(SkeletalMatrix[2].xyz, SkeletalMatrix[0].xyz), cross(SkeletalMatrix[0].xyz, SkeletalMatrix[1].xyz)); // is actually transpose(inverse(mat3(SkeletalMatrix))) * det(mat3(SkeletalMatrix))
	vec4 SkeletalVertex = Attrib_Position * SkeletalMatrix;
	vec3 SkeletalSVector = normalize(Attrib_TexCoord1.xyz * SkeletalNormalMatrix);
	vec3 SkeletalTVector = normalize(Attrib_TexCoord2.xyz * SkeletalNormalMatrix);
	vec3 SkeletalNormal  = normalize(Attrib_TexCoord3.xyz * SkeletalNormalMatrix);
#define Attrib_Position SkeletalVertex
#define Attrib_TexCoord1 SkeletalSVector
#define Attrib_TexCoord2 SkeletalTVector
#define Attrib_TexCoord3 SkeletalNormal
#endif
	TexCoordSurfaceLightmap = vec4((TexMatrix * Attrib_TexCoord0).xy, 0.0, 0.0);
#ifdef USEVERTEXTEXTUREBLEND
	VertexColor = Attrib_Color;
// VorteX {
#if defined(SHOWVERTEXALPHA) && defined(USEVEGETATION)
	VertexColor.rgb =  VegetationShow(VertexColor.rgb, VertexColor.a);
#endif
// } VorteX
	TexCoord2 = vec2(BackgroundTexMatrix * Attrib_TexCoord0);
#endif

	// transform unnormalized eye direction into tangent space
#ifdef USEOFFSETMAPPING
	vec3 EyeRelative = EyePosition - Attrib_Position.xyz;
	EyeVectorFogDepth.x = dot(EyeRelative, Attrib_TexCoord1.xyz);
	EyeVectorFogDepth.y = dot(EyeRelative, Attrib_TexCoord2.xyz);
	EyeVectorFogDepth.z = dot(EyeRelative, Attrib_TexCoord3.xyz);
	EyeVectorFogDepth.w = 0.0;
#endif

	VectorS = (ModelViewMatrix * vec4(Attrib_TexCoord1.xyz, 0));
	VectorT = (ModelViewMatrix * vec4(Attrib_TexCoord2.xyz, 0));
	VectorR = (ModelViewMatrix * vec4(Attrib_TexCoord3.xyz, 0));
// VorteX {
#ifdef USEVEGETATION
	gl_Position = ModelViewProjectionMatrix * VegetationVertex(Attrib_Position, Attrib_Color.a);
#else
	gl_Position = ModelViewProjectionMatrix * Attrib_Position;
#endif
// } VorteX
#ifdef USETRIPPY
	gl_Position = TrippyVertex(gl_Position);
#endif
// VorteX {
	// VorteX: Depth are used for outlining code
	// outlining code was patched to allow both \/ and /\ borders
	// so it's requiring to have normalmap (triangles tangent) and depth-map of the scene to detect borders
	// but we have only one parameter to store it
#ifdef USEOFFSETMAPPING
	Depth = EyeVectorFogDepth.z * length(EyeRelative); // VorteX
#else
	vec3 EyeRelative = EyePosition - Attrib_Position.xyz;
	Depth = dot(EyeRelative, Attrib_TexCoord3.xyz) * length(EyeRelative); // VorteX
#endif
// } VorteX
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
void main(void)
{
#ifdef USEOFFSETMAPPING
	// apply offsetmapping
	vec2 dPdx = dp_offsetmapping_dFdx(TexCoordSurfaceLightmap.xy);
	vec2 dPdy = dp_offsetmapping_dFdy(TexCoordSurfaceLightmap.xy);
	vec2 TexCoordOffset = OffsetMapping(TexCoordSurfaceLightmap.xy, dPdx, dPdy);
# define offsetMappedTexture2D(t) dp_textureGrad(t, TexCoordOffset, dPdx, dPdy)
#else
# define offsetMappedTexture2D(t) dp_texture2D(t, TexCoordSurfaceLightmap.xy)
#endif

#ifdef USEALPHAKILL
	if (offsetMappedTexture2D(Texture_Color).a < 0.5)
		discard;
#endif

#ifdef USEVERTEXTEXTUREBLEND
	float alpha = offsetMappedTexture2D(Texture_Color).a;
	float terrainblend = clamp(float(VertexColor.a) * alpha * 2.0 - 0.5, float(0.0), float(1.0));
	//float terrainblend = min(float(VertexColor.a) * alpha * 2.0, float(1.0));
	//float terrainblend = float(VertexColor.a) * alpha > 0.5;
#endif

#ifdef USEVERTEXTEXTUREBLEND
	vec3 surfacenormal = mix(vec3(dp_texture2D(Texture_SecondaryNormal, TexCoord2)), vec3(offsetMappedTexture2D(Texture_Normal)), terrainblend) - vec3(0.5, 0.5, 0.5);
	float a = mix(dp_texture2D(Texture_SecondaryGloss, TexCoord2).a, offsetMappedTexture2D(Texture_Gloss).a, terrainblend);
#else
	vec3 surfacenormal = vec3(offsetMappedTexture2D(Texture_Normal)) - vec3(0.5, 0.5, 0.5);
	float a = offsetMappedTexture2D(Texture_Gloss).a;
#endif

	vec3 pixelnormal = normalize(surfacenormal.x * VectorS.xyz + surfacenormal.y * VectorT.xyz + surfacenormal.z * VectorR.xyz);
	dp_FragColor = vec4(pixelnormal.x, pixelnormal.y, Depth, a);
}
#endif // FRAGMENT_SHADER
#else // !MODE_DEFERREDGEOMETRY




#ifdef MODE_DEFERREDLIGHTSOURCE
#ifdef VERTEX_SHADER
uniform highp mat4 ModelViewMatrix;
void main(void)
{
	ModelViewPosition = ModelViewMatrix * Attrib_Position;
	gl_Position = ModelViewProjectionMatrix * Attrib_Position;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
uniform highp mat4 ViewToLight;
// ScreenToDepth = vec2(Far / (Far - Near), Far * Near / (Near - Far));
uniform highp vec2 ScreenToDepth;
uniform myhalf3 DeferredColor_Ambient;
uniform myhalf3 DeferredColor_Diffuse;
#ifdef USESPECULAR
uniform myhalf3 DeferredColor_Specular;
uniform myhalf SpecularPower;
#endif
uniform myhalf2 PixelToScreenTexCoord;
void main(void)
{
	// calculate viewspace pixel position
	vec2 ScreenTexCoord = gl_FragCoord.xy * PixelToScreenTexCoord;
	vec3 position;
	// get the geometry information (depth, normal, specular exponent)
	myhalf4 normalmap = dp_texture2D(Texture_ScreenNormalMap, ScreenTexCoord);
	// decode viewspace pixel normal
//	myhalf3 surfacenormal = normalize(normalmap.rgb - cast_myhalf3(0.5,0.5,0.5));
	myhalf3 surfacenormal = myhalf3(normalmap.rg, sqrt(1.0-dot(normalmap.rg, normalmap.rg)));
	// decode viewspace pixel position
//	position.z = decodedepthmacro(dp_texture2D(Texture_ScreenDepth, ScreenTexCoord));
	position.z = normalmap.b;
//	position.z = ScreenToDepth.y / (dp_texture2D(Texture_ScreenDepth, ScreenTexCoord).r + ScreenToDepth.x);
	position.xy = ModelViewPosition.xy * (position.z / ModelViewPosition.z);

	// now do the actual shading
	// surfacenormal = pixel normal in viewspace
	// LightVector = pixel to light in viewspace
	// CubeVector = pixel in lightspace
	// eyenormal = pixel to view direction in viewspace
	vec3 CubeVector = vec3(ViewToLight * vec4(position,1));
	myhalf fade = cast_myhalf(dp_texture2D(Texture_Attenuation, vec2(length(CubeVector), 0.0)));
#ifdef USEDIFFUSE
	// calculate diffuse shading
	myhalf3 lightnormal = cast_myhalf3(normalize(LightPosition - position));
SHADEDIFFUSE
#endif
#ifdef USESPECULAR
	// calculate directional shading
	myhalf3 eyenormal = -normalize(cast_myhalf3(position));
SHADESPECULAR(SpecularPower * normalmap.a)
#endif

#if defined(USESHADOWMAP2D)
	fade *= ShadowMapCompare(CubeVector);
#endif

#ifdef USESPECULAR
	gl_FragData[0] = vec4((DeferredColor_Ambient + DeferredColor_Diffuse * diffuse) * fade, 1.0);
	gl_FragData[1] = vec4(DeferredColor_Specular * (specular * fade), 1.0);
# ifdef USECUBEFILTER
	vec3 cubecolor = dp_textureCube(Texture_Cube, CubeVector).rgb;
	gl_FragData[0].rgb *= cubecolor;
	gl_FragData[1].rgb *= cubecolor;
# endif
#else
# ifdef USEDIFFUSE
	gl_FragColor = vec4((DeferredColor_Ambient + DeferredColor_Diffuse * diffuse) * fade, 1.0);
# else
	gl_FragColor = vec4(DeferredColor_Ambient * fade, 1.0);
# endif
# ifdef USECUBEFILTER
	vec3 cubecolor = dp_textureCube(Texture_Cube, CubeVector).rgb;
	gl_FragColor.rgb *= cubecolor;
# endif
#endif
}
#endif // FRAGMENT_SHADER
#else // !MODE_DEFERREDLIGHTSOURCE

// VorteX {
#ifdef USESUNDIRECTION
dp_varying mediump vec3 SunlightVector;
uniform mediump vec4 SunlightColor;
#endif
// } VorteX

#ifdef VERTEX_SHADER
uniform highp mat4 TexMatrix;
#ifdef USEVERTEXTEXTUREBLEND
uniform highp mat4 BackgroundTexMatrix;
#endif
#ifdef MODE_LIGHTSOURCE
uniform highp mat4 ModelToLight;
#endif
#ifdef USESHADOWMAPORTHO
uniform highp mat4 ShadowMapMatrix;
#endif
#ifdef USEBOUNCEGRID
uniform highp mat4 BounceGridMatrix;
#endif
// VorteX {
#ifdef USESUNDIRECTION
uniform mediump vec4 SunlightDir;
#endif
// } VorteX
void main(void)
{
#ifdef USESKELETAL
	ivec4 si0 = ivec4(Attrib_SkeletalIndex * 3.0);
	ivec4 si1 = si0 + ivec4(1, 1, 1, 1);
	ivec4 si2 = si0 + ivec4(2, 2, 2, 2);
	vec4 sw = Attrib_SkeletalWeight;
	vec4 SkeletalMatrix1 = Skeletal_Transform12[si0.x] * sw.x + Skeletal_Transform12[si0.y] * sw.y + Skeletal_Transform12[si0.z] * sw.z + Skeletal_Transform12[si0.w] * sw.w;
	vec4 SkeletalMatrix2 = Skeletal_Transform12[si1.x] * sw.x + Skeletal_Transform12[si1.y] * sw.y + Skeletal_Transform12[si1.z] * sw.z + Skeletal_Transform12[si1.w] * sw.w;
	vec4 SkeletalMatrix3 = Skeletal_Transform12[si2.x] * sw.x + Skeletal_Transform12[si2.y] * sw.y + Skeletal_Transform12[si2.z] * sw.z + Skeletal_Transform12[si2.w] * sw.w;
	mat4 SkeletalMatrix = mat4(SkeletalMatrix1, SkeletalMatrix2, SkeletalMatrix3, vec4(0.0, 0.0, 0.0, 1.0));
//	ivec4 si = ivec4(Attrib_SkeletalIndex);
//	mat4 SkeletalMatrix = Skeletal_Transform[si.x] * Attrib_SkeletalWeight.x + Skeletal_Transform[si.y] * Attrib_SkeletalWeight.y + Skeletal_Transform[si.z] * Attrib_SkeletalWeight.z + Skeletal_Transform[si.w] * Attrib_SkeletalWeight.w;
	mat3 SkeletalNormalMatrix = mat3(cross(SkeletalMatrix[1].xyz, SkeletalMatrix[2].xyz), cross(SkeletalMatrix[2].xyz, SkeletalMatrix[0].xyz), cross(SkeletalMatrix[0].xyz, SkeletalMatrix[1].xyz)); // is actually transpose(inverse(mat3(SkeletalMatrix))) * det(mat3(SkeletalMatrix))
	vec4 SkeletalVertex = Attrib_Position * SkeletalMatrix;
	SkeletalVertex.w = 1.0;
	vec3 SkeletalSVector = normalize(Attrib_TexCoord1.xyz * SkeletalNormalMatrix);
	vec3 SkeletalTVector = normalize(Attrib_TexCoord2.xyz * SkeletalNormalMatrix);
	vec3 SkeletalNormal  = normalize(Attrib_TexCoord3.xyz * SkeletalNormalMatrix);
#define Attrib_Position SkeletalVertex
#define Attrib_TexCoord1 SkeletalSVector
#define Attrib_TexCoord2 SkeletalTVector
#define Attrib_TexCoord3 SkeletalNormal
#endif

// VorteX {
#if defined(MODE_VERTEXCOLOR) || defined(USEVERTEXTEXTUREBLEND) || defined(MODE_LIGHTDIRECTIONMAP_FORCED_VERTEXCOLOR) || defined(USEALPHAGENVERTEX) || defined(SHOWVERTEXALPHA)
	VertexColor = Attrib_Color;
#if defined(SHOWVERTEXALPHA) && defined(USEVEGETATION)
	VertexColor.rgb = VegetationShow(VertexColor.rgb, VertexColor.a);
#endif
// } VorteX
#endif
	// copy the surface texcoord
#ifdef USELIGHTMAP
	TexCoordSurfaceLightmap = vec4((TexMatrix * Attrib_TexCoord0).xy, Attrib_TexCoord4.xy);
#else
	TexCoordSurfaceLightmap = vec4((TexMatrix * Attrib_TexCoord0).xy, 0.0, 0.0);
#endif
#ifdef USEVERTEXTEXTUREBLEND
	TexCoord2 = vec2(BackgroundTexMatrix * Attrib_TexCoord0);
#endif

#ifdef USEBOUNCEGRID
	BounceGridTexCoord = vec3(BounceGridMatrix * Attrib_Position);
#ifdef USEBOUNCEGRIDDIRECTIONAL
	BounceGridTexCoord.z *= 0.125;
#endif
#endif

#ifdef MODE_LIGHTSOURCE
	// transform vertex position into light attenuation/cubemap space
	// (-1 to +1 across the light box)
	CubeVector = vec3(ModelToLight * Attrib_Position);

# ifdef USEDIFFUSE
	// transform unnormalized light direction into tangent space
	// (we use unnormalized to ensure that it interpolates correctly and then
	//  normalize it per pixel)
	vec3 lightminusvertex = LightPosition - Attrib_Position.xyz;
	LightVector.x = dot(lightminusvertex, Attrib_TexCoord1.xyz);
	LightVector.y = dot(lightminusvertex, Attrib_TexCoord2.xyz);
	LightVector.z = dot(lightminusvertex, Attrib_TexCoord3.xyz);
# endif
#endif

#if defined(MODE_LIGHTDIRECTION) && defined(USEDIFFUSE)
	LightVector.x = dot(LightDir, Attrib_TexCoord1.xyz);
	LightVector.y = dot(LightDir, Attrib_TexCoord2.xyz);
	LightVector.z = dot(LightDir, Attrib_TexCoord3.xyz);
#endif

// VorteX {
#ifdef USESUNDIRECTION
	// transform unnormalized sun direction into tangent space
	SunlightVector.x = dot(SunlightDir.xyz, Attrib_TexCoord1.xyz);
	SunlightVector.y = dot(SunlightDir.xyz, Attrib_TexCoord2.xyz);
	SunlightVector.z = dot(SunlightDir.xyz, Attrib_TexCoord3.xyz);
	SunlightVector = normalize(SunlightVector);
#endif
// } VorteX

	// transform unnormalized eye direction into tangent space
#ifdef USEEYEVECTOR
	vec3 EyeRelative = EyePosition - Attrib_Position.xyz;
	EyeVectorFogDepth.x = dot(EyeRelative, Attrib_TexCoord1.xyz);
	EyeVectorFogDepth.y = dot(EyeRelative, Attrib_TexCoord2.xyz);
	EyeVectorFogDepth.z = dot(EyeRelative, Attrib_TexCoord3.xyz);
#ifdef USEFOG
	EyeVectorFogDepth.w = dot(FogPlane, Attrib_Position);
#else
	EyeVectorFogDepth.w = 0.0;
#endif
#endif


#if defined(MODE_LIGHTDIRECTIONMAP_MODELSPACE) || defined(USEREFLECTCUBE) || defined(USEBOUNCEGRIDDIRECTIONAL)
# ifdef USEFOG
	VectorS = vec4(Attrib_TexCoord1.xyz, EyePosition.x - Attrib_Position.x);
	VectorT = vec4(Attrib_TexCoord2.xyz, EyePosition.y - Attrib_Position.y);
	VectorR = vec4(Attrib_TexCoord3.xyz, EyePosition.z - Attrib_Position.z);
# else
	VectorS = vec4(Attrib_TexCoord1, 0);
	VectorT = vec4(Attrib_TexCoord2, 0);
	VectorR = vec4(Attrib_TexCoord3, 0);
# endif
#else
# ifdef USEFOG
	EyeVectorModelSpace = EyePosition - Attrib_Position.xyz;
# endif
#endif

// VorteX {
#ifdef USEVEGETATION
	gl_Position = ModelViewProjectionMatrix * VegetationVertex(Attrib_Position, Attrib_Color.a);
#else
	gl_Position = ModelViewProjectionMatrix * Attrib_Position;
#endif
// } VorteX

#ifdef USESHADOWMAPORTHO
	ShadowMapTC = vec3(ShadowMapMatrix * gl_Position);
#endif

#ifdef USEREFLECTION
	ModelViewProjectionPosition = gl_Position;
#endif
#ifdef USETRIPPY
	gl_Position = TrippyVertex(gl_Position);
#endif
}
#endif // VERTEX_SHADER




#ifdef FRAGMENT_SHADER
#ifdef USEDEFERREDLIGHTMAP
uniform myhalf2 PixelToScreenTexCoord;
uniform myhalf3 DeferredMod_Diffuse;
uniform myhalf3 DeferredMod_Specular;
#endif
uniform myhalf3 Color_Ambient;
uniform myhalf3 Color_Diffuse;
uniform myhalf3 Color_Specular;
uniform myhalf SpecularPower;
#ifdef USEGLOW
uniform myhalf3 Color_Glow;
#endif
uniform myhalf Alpha;
#ifdef USEREFLECTION
uniform mediump vec4 DistortScaleRefractReflect;
uniform mediump vec4 ScreenScaleRefractReflect;
uniform mediump vec4 ScreenCenterRefractReflect;
uniform mediump vec4 ReflectColor;
#endif
#ifdef USEREFLECTCUBE
uniform highp mat4 ModelToReflectCube;
uniform sampler2D Texture_ReflectMask;
uniform samplerCube Texture_ReflectCube;
#endif
#ifdef MODE_LIGHTDIRECTION
uniform myhalf3 LightColor;
#endif
#ifdef MODE_LIGHTSOURCE
uniform myhalf3 LightColor;
#endif
#ifdef USEBOUNCEGRID
uniform sampler3D Texture_BounceGrid;
uniform float BounceGridIntensity;
uniform highp mat4 BounceGridMatrix;
#endif
// VorteX {
#ifndef USECLIENTTIME
uniform highp float ClientTime;
#define USECLIENTTIME
#endif
// } VorteX
#ifdef USENORMALMAPSCROLLBLEND
uniform highp vec2 NormalmapScrollBlend;
#endif
#ifdef USEOCCLUDE
uniform occludeQuery {
    uint visiblepixels;
    uint allpixels;
};
#endif
void main(void)
{
#ifdef USEOFFSETMAPPING
	// apply offsetmapping
	vec2 dPdx = dp_offsetmapping_dFdx(TexCoordSurfaceLightmap.xy);
	vec2 dPdy = dp_offsetmapping_dFdy(TexCoordSurfaceLightmap.xy);
// VorteX {
// VorteX: support offsetmapping for vertex blended terrain
#ifdef USEVERTEXTEXTUREBLEND
	vec2 TexCoordOffset = OffsetMapping(TexCoordSurfaceLightmap.xy, dPdx, dPdy, VertexColor.a);
#else
	vec2 TexCoordOffset = OffsetMapping(TexCoordSurfaceLightmap.xy, dPdx, dPdy);
#endif
// } VorteX
# define offsetMappedTexture2D(t) dp_textureGrad(t, TexCoordOffset, dPdx, dPdy)
# define TexCoord TexCoordOffset
#else
# define offsetMappedTexture2D(t) dp_texture2D(t, TexCoordSurfaceLightmap.xy)
# define TexCoord TexCoordSurfaceLightmap.xy
#endif

	// combine the diffuse textures (base, pants, shirt)
	myhalf4 color = cast_myhalf4(offsetMappedTexture2D(Texture_Color));
#ifdef USEALPHAKILL
	if (color.a < 0.5)
		discard;
#endif
	color.a *= Alpha;

// VorteX {
#ifdef USECELTEXTURING
	color.rgb = mix(color.rgb, Color_Average.rgb, Color_Average.a);
#endif

#ifdef USECOLORMAPPING
	color.rgb += cast_myhalf3(offsetMappedTexture2D(Texture_Pants)) * Color_Pants + cast_myhalf3(offsetMappedTexture2D(Texture_Shirt)) * Color_Shirt;
#endif

// this special blend style is aimed to reduce effect of smooth transition between 2 textures (or texture alpha)
#ifdef USEVERTEXTEXTUREBLEND
	#ifdef USEBOTHALPHAS
		//  0        0.3              0.7       1.0
		// RGB ---- RGBA ----------- RGBA2 ---- RGB2
		// by applying splat masks to it, and making this zones to look more harsh and detailed
		// each texture's alpha sets 'leak' zones (white) and fully transparent zones (black) where opposite layer texture is shown
		#define BLEND_SPLATMASK_BORDER 0.3
		#define BLEND_SPLATMASK_INNER  0.4
		myhalf4 color2 = cast_myhalf4(dp_texture2D(Texture_SecondaryColor, TexCoord2));
		myhalf  terrainblend = mix(mix(1.0, color.a, min((1.0 - VertexColor.a)/BLEND_SPLATMASK_BORDER, 1.0)), mix(0.0, 1.0 - color2.a, min(VertexColor.a/BLEND_SPLATMASK_BORDER, 1.0)), sqrt(1.0 - clamp(((VertexColor.a-BLEND_SPLATMASK_BORDER)/BLEND_SPLATMASK_INNER), 0.0, 1.0)));
		#ifdef USECELTEXTURING
			color.rgb = mix(mix(color2.rgb, Color_SecondaryAverage.rgb, Color_SecondaryAverage.a), color.rgb, terrainblend);
		#else
			color.rgb = mix(color2.rgb, color.rgb, terrainblend);
		#endif
	#else
		myhalf terrainblend = clamp(cast_myhalf(VertexColor.a) * color.a * 2.0 - 0.5, cast_myhalf(0.0), cast_myhalf(1.0));
		//myhalf terrainblend = min(cast_myhalf(VertexColor.a) * color.a * 2.0, cast_myhalf(1.0));
		//myhalf terrainblend = cast_myhalf(VertexColor.a) * color.a > 0.5;
		#ifdef USECELTEXTURING
			myhalf4 color2 = cast_myhalf4(dp_texture2D(Texture_SecondaryColor, TexCoord2));
			color.rgb = mix(mix(color2.rgb, Color_SecondaryAverage.rgb, Color_SecondaryAverage.a), color.rgb, terrainblend);
		#else
			color.rgb = mix(cast_myhalf3(dp_texture2D(Texture_SecondaryColor, TexCoord2)), color.rgb, terrainblend);
		#endif
	#endif
	color.a = 1.0;	//color = mix(cast_myhalf4(1, 0, 0, 1), color, terrainblend);
#endif
#ifdef USEALPHAGENVERTEX
	color.a *= VertexColor.a;
#endif

	// get the surface normal
	// get the material colors
	// VorteX: USESCROLLBLEND conflicts with USEVERTEXTEXTUREBLEND, USECOLORMAPPING, ALPHAKILL
#ifdef USESCROLLBLEND
	myhalf3 surfacenormal = ScrollBlendNormalmap(Texture_Normal, TexCoord);
	myhalf3 diffusetex = ScrollBlendTexture(Texture_Color, TexCoord, surfacenormal).rgb;
	#if defined(USESPECULAR) || defined(USEDEFERREDLIGHTMAP)
	myhalf4 glosstex = ScrollBlendTexture(Texture_Gloss, TexCoord, surfacenormal);
	#endif
#else
	#ifdef USEVERTEXTEXTUREBLEND
	myhalf3 surfacenormal = normalize(mix(cast_myhalf3(dp_texture2D(Texture_SecondaryNormal, TexCoord2)), cast_myhalf3(offsetMappedTexture2D(Texture_Normal)), terrainblend) - cast_myhalf3(0.5, 0.5, 0.5));
	#else
	myhalf3 surfacenormal = normalize(cast_myhalf3(offsetMappedTexture2D(Texture_Normal)) - cast_myhalf3(0.5, 0.5, 0.5));;
	#endif
	myhalf3 diffusetex = color.rgb;
	#if defined(USESPECULAR) || defined(USEDEFERREDLIGHTMAP)
	#ifdef USEVERTEXTEXTUREBLEND
	myhalf4 glosstex = mix(cast_myhalf4(dp_texture2D(Texture_SecondaryGloss, TexCoord2)), cast_myhalf4(offsetMappedTexture2D(Texture_Gloss)), terrainblend);
	#else
	myhalf4 glosstex = cast_myhalf4(offsetMappedTexture2D(Texture_Gloss));
	#endif
	#endif
#endif

#ifdef USEREFLECTCUBE
	myhalf4 reflectmask = offsetMappedTexture2D(Texture_ReflectMask);
	vec3 TangentReflectVector = reflect(-EyeVectorFogDepth.xyz, mix(vec3(0.0, 0.0, 1.0), surfacenormal, reflectmask.a));
	vec3 ModelReflectVector = TangentReflectVector.x * VectorS.xyz + TangentReflectVector.y * VectorT.xyz + TangentReflectVector.z * VectorR.xyz;
	vec3 ReflectCubeTexCoord = vec3(ModelToReflectCube * vec4(ModelReflectVector, 0));
	myhalf3 reflectcubesample = dp_textureCube(Texture_ReflectCube, ReflectCubeTexCoord).rgb;
	diffusetex += cast_myhalf3(offsetMappedTexture2D(Texture_ReflectMask)) * cast_myhalf3(dp_textureCube(Texture_ReflectCube, ReflectCubeTexCoord));
#endif
// } VorteX

#ifdef USESPECULAR
	myhalf3 eyenormal = normalize(cast_myhalf3(EyeVectorFogDepth.xyz));
#endif




#ifdef MODE_LIGHTSOURCE
	// light source
#ifdef USEDIFFUSE
	myhalf3 lightnormal = cast_myhalf3(normalize(LightVector));
SHADEDIFFUSE
// VorteX {
	#ifdef USESELFSHADOWING
		#ifdef USEVERTEXTEXTUREBLEND
			diffuse *= SelfShadowing(lightnormal , TexCoord, dp_offsetmapping_dFdx(TexCoordSurfaceLightmap.xy), dp_offsetmapping_dFdy(TexCoordSurfaceLightmap.xy), VertexColor.a);
		#else
			diffuse *= SelfShadowing(lightnormal , TexCoord, dp_offsetmapping_dFdx(TexCoordSurfaceLightmap.xy), dp_offsetmapping_dFdy(TexCoordSurfaceLightmap.xy));
		#endif
		#ifdef SHOWSELFSHADOWING
			diffusetex.rgb = vec3(0.5, 0.5, 0.5);
		#endif
	#endif
// } VorteX
	color.rgb = diffusetex * (Color_Ambient + diffuse * Color_Diffuse);
#ifdef USESPECULAR
SHADESPECULAR(SpecularPower * glosstex.a)
	color.rgb += glosstex.rgb * (specular * Color_Specular);
#endif
#else
	color.rgb = diffusetex * Color_Ambient;
#endif
	color.rgb *= LightColor;
// VorteX {
	myhalf atten = cast_myhalf(dp_texture2D(Texture_Attenuation, vec2(length(CubeVector), 0.0)));
#ifdef USEALPHAGENVERTEX
	atten *= max(0.0, sqrt(VertexColor.a) - 0.1);
#endif
	color.a *= atten;
	color.rgb *= atten;
// } VorteX
#if defined(USESHADOWMAP2D)
	color.rgb *= ShadowMapCompare(CubeVector);
#endif
# ifdef USECUBEFILTER
	color.rgb *= cast_myhalf3(dp_textureCube(Texture_Cube, CubeVector));
# endif
#endif // MODE_LIGHTSOURCE




#ifdef MODE_LIGHTDIRECTION
	#define SHADING
	#ifdef USEDIFFUSE
		myhalf3 lightnormal = cast_myhalf3(normalize(LightVector));
	#endif
	#define lightcolor LightColor
#endif // MODE_LIGHTDIRECTION

// VorteX {
#ifdef MODE_LIGHTDIRECTIONMAP_MODELSPACE
   #define SHADING
	// deluxemap lightmapping using light vectors in modelspace (q3map2 -light -deluxe)
	myhalf3 lightnormal_modelspace = DecodeDeluxemap(dp_texture2D(Texture_Deluxemap, TexCoordSurfaceLightmap.zw)) * 2.0 + cast_myhalf3(-1.0, -1.0, -1.0);
	myhalf3 lightcolor = DecodeLightmap(dp_texture2D(Texture_Lightmap, TexCoordSurfaceLightmap.zw));
	// convert modelspace light vector to tangentspace
	myhalf3 lightnormal;
	lightnormal.x = dot(lightnormal_modelspace, cast_myhalf3(VectorS));
	lightnormal.y = dot(lightnormal_modelspace, cast_myhalf3(VectorT));
	lightnormal.z = max(0.1, dot(lightnormal_modelspace, cast_myhalf3(VectorR)));
	lightnormal = normalize(lightnormal); // VectorS/T/R are not always perfectly normalized, and EXACTSPECULARMATH is very picky about this
	// calculate directional shading (and undoing the existing angle attenuation on the lightmap by the division)
	// note that q3map2 is too stupid to calculate proper surface normals when q3map_nonplanar
	// is used (the lightmap and deluxemap coords correspond to virtually random coordinates
	// on that luxel, and NOT to its center, because recursive triangle subdivision is used
	// to map the luxels to coordinates on the draw surfaces), which also causes
	// deluxemaps to be wrong because light contributions from the wrong side of the surface
	// are added up. To prevent divisions by zero or strong exaggerations, a max()
	// nudge is done here at expense of some additional fps. This is ONLY needed for
	// deluxemaps, tangentspace deluxemap avoid this problem by design.
	lightcolor /= lightnormal.z;
#endif // MODE_LIGHTDIRECTIONMAP_MODELSPACE
#ifdef MODE_LIGHTDIRECTIONMAP_TANGENTSPACE
   #define SHADING
	// deluxemap lightmapping using light vectors in tangentspace (hmap2 -light)
	myhalf3 lightnormal = DecodeDeluxemap(dp_texture2D(Texture_Deluxemap, TexCoordSurfaceLightmap.zw)) * 2.0 + cast_myhalf3(-1.0, -1.0, -1.0);
	myhalf3 lightcolor = DecodeLightmap(dp_texture2D(Texture_Lightmap, TexCoordSurfaceLightmap.zw));
#endif // MODE_LIGHTDIRECTIONMAP_TANGENTSPACE
#ifdef MODE_LIGHTDIRECTIONMAP_FORCED_LIGHTMAP
	#define SHADING
	// forced deluxemap on lightmapped/vertexlit surfaces
	myhalf3 lightnormal = cast_myhalf3(0.08, 0.62, 0.78);
	myhalf3 lightcolor = cast_myhalf3(dp_texture2D(Texture_Lightmap, TexCoordSurfaceLightmap.zw));
#endif // MODE_LIGHTDIRECTIONMAP_FORCED_LIGHTMAP
#ifdef MODE_LIGHTDIRECTIONMAP_FORCED_VERTEXCOLOR
	#define SHADING
	// forced deluxemap on vertexlit surfaces
	myhalf3 lightnormal = cast_myhalf3(0.08, 0.62, 0.78);
	myhalf3 lightcolor = cast_myhalf3(VertexColor.rgb * 1.15);
#endif // MODE_LIGHTDIRECTIONMAP_FORCED_VERTEXCOLOR
#ifdef SHADING
	#ifdef MODE_LIGHTDIRECTIONMAP_MODELSPACE
		#ifdef SHOWDELUXEMAP
			//lightnormal = cast_myhalf3(0.08, 0.62, 0.78);
			lightcolor = lightnormal_modelspace;
		#endif
	#endif
#endif
// } VorteX

#ifdef MODE_FAKELIGHT
	#define SHADING
	myhalf3 lightnormal = cast_myhalf3(normalize(EyeVectorFogDepth.xyz));
	myhalf3 lightcolor = cast_myhalf3(1.0);
#endif // MODE_FAKELIGHT




#ifdef MODE_LIGHTMAP
	color.rgb = diffusetex * (Color_Ambient + cast_myhalf3(dp_texture2D(Texture_Lightmap, TexCoordSurfaceLightmap.zw)) * Color_Diffuse);
#endif // MODE_LIGHTMAP
#ifdef MODE_VERTEXCOLOR
	color.rgb = diffusetex * (Color_Ambient + cast_myhalf3(VertexColor.rgb) * Color_Diffuse);
#endif // MODE_VERTEXCOLOR
#ifdef MODE_FLATCOLOR
	color.rgb = diffusetex * Color_Ambient;
#endif // MODE_FLATCOLOR




#ifdef SHADING
# ifdef USEDIFFUSE
SHADEDIFFUSE
// VorteX {
#ifdef USESUNDIRECTION
	myhalf sundiffuse = min(SUNDIRECTION_MAXDIFFUSE, max(0.0, SUNDIRECTION_DIFFUSEBIAS + (dot(surfacenormal, SunlightVector) - SUNDIRECTION_DIFFUSEBIAS)*SUNDIRECTION_DIFFUSE - diffuse));
	#ifdef USESHADOWMAPORTHO
		#define SUNFADE
		myhalf sunfade = ShadowMapCompare(ShadowMapTC); 
		#if defined(SUNDIRECTION_AMBIENT)
			diffusetex.rgb += diffusetex.rgb * sunfade * sunfade * (sundiffuse + SUNDIRECTION_AMBIENT) * (SUNDIRECTION_BASECOLOR + SunlightColor.rgb) * SunlightColor.a;
		#else
			diffusetex.rgb += diffusetex.rgb * sunfade * sunfade * sundiffuse * (SUNDIRECTION_BASECOLOR + SunlightColor.rgb) * SunlightColor.a;
		#endif
	#else
		#if defined(SUNDIRECTION_AMBIENT)
			diffusetex.rgb += diffusetex.rgb * (sundiffuse + SUNDIRECTION_AMBIENT) * (SUNDIRECTION_BASECOLOR + SunlightColor.rgb) * SunlightColor.a;
		#else
			diffusetex.rgb += diffusetex.rgb * sundiffuse * (SUNDIRECTION_BASECOLOR + SunlightColor.rgb) * SunlightColor.a;
		#endif
	#endif
#endif
#ifdef USESELFSHADOWING
	#if defined(USESUNDIRECTION) && defined(USESHADOWMAPORTHO)
		#ifdef USEVERTEXTEXTUREBLEND
			sunfade = min(sunfade, mix(SelfShadowing(SunlightVector, TexCoord, dp_offsetmapping_dFdx(TexCoordSurfaceLightmap.xy), dp_offsetmapping_dFdy(TexCoordSurfaceLightmap.xy), VertexColor.a), 1.0, ShadowMap_Parameters.w - 0.1));
		#else
			sunfade = min(sunfade, mix(SelfShadowing(SunlightVector, TexCoord, dp_offsetmapping_dFdx(TexCoordSurfaceLightmap.xy), dp_offsetmapping_dFdy(TexCoordSurfaceLightmap.xy)), 1.0, ShadowMap_Parameters.w - 0.1));
		#endif
	#else
		#ifdef USEVERTEXTEXTUREBLEND
			diffuse *= SelfShadowing(lightnormal, TexCoord, dp_offsetmapping_dFdx(TexCoordSurfaceLightmap.xy), dp_offsetmapping_dFdy(TexCoordSurfaceLightmap.xy), VertexColor.a);
		#else
			diffuse *= SelfShadowing(lightnormal, TexCoord, dp_offsetmapping_dFdx(TexCoordSurfaceLightmap.xy), dp_offsetmapping_dFdy(TexCoordSurfaceLightmap.xy));
		#endif
	#endif
	#ifdef SHOWSELFSHADOWING
		diffusetex.rgb = vec3(0.5, 0.5, 0.5);
	#endif
#endif
// } VorteX
#  ifdef USESPECULAR
SHADESPECULAR(SpecularPower * glosstex.a)
	color.rgb = diffusetex * Color_Ambient + (diffusetex * Color_Diffuse * diffuse + glosstex.rgb * Color_Specular * specular) * lightcolor;
#  else
	color.rgb = diffusetex * (Color_Ambient + Color_Diffuse * diffuse * lightcolor);
#  endif
# else
	color.rgb = diffusetex * Color_Ambient;
# endif
#endif

#ifdef USESHADOWMAPORTHO
	// VorteX {
	// added some blue to the shadowed areas
	#ifndef SUNFADE
		myhalf sunfade = ShadowMapCompare(ShadowMapTC);
	#endif
	color.rgb *= sunfade;
	sunfade = 1.0 - sunfade;
	color.g *= 1.0 + sunfade*0.1;
	color.b *= 1.0 + sunfade*0.3;
	// } VorteX
#endif

#ifdef USEDEFERREDLIGHTMAP
	vec2 ScreenTexCoord = gl_FragCoord.xy * PixelToScreenTexCoord;
	color.rgb += diffusetex * cast_myhalf3(dp_texture2D(Texture_ScreenDiffuse, ScreenTexCoord)) * DeferredMod_Diffuse;
	color.rgb += glosstex.rgb * cast_myhalf3(dp_texture2D(Texture_ScreenSpecular, ScreenTexCoord)) * DeferredMod_Specular;
//	color.rgb = dp_texture2D(Texture_ScreenNormalMap, ScreenTexCoord).rgb * vec3(1.0, 1.0, 0.001);
#endif

#ifdef USEBOUNCEGRID
#ifdef USEBOUNCEGRIDDIRECTIONAL
//	myhalf4 bouncegrid_coeff1 = cast_myhalf4(dp_texture3D(Texture_BounceGrid, BounceGridTexCoord                        ));
//	myhalf4 bouncegrid_coeff2 = cast_myhalf4(dp_texture3D(Texture_BounceGrid, BounceGridTexCoord + vec3(0.0, 0.0, 0.125))) * 2.0 + cast_myhalf4(-1.0, -1.0, -1.0, -1.0);
	myhalf4 bouncegrid_coeff3 = cast_myhalf4(dp_texture3D(Texture_BounceGrid, BounceGridTexCoord + vec3(0.0, 0.0, 0.250)));
	myhalf4 bouncegrid_coeff4 = cast_myhalf4(dp_texture3D(Texture_BounceGrid, BounceGridTexCoord + vec3(0.0, 0.0, 0.375)));
	myhalf4 bouncegrid_coeff5 = cast_myhalf4(dp_texture3D(Texture_BounceGrid, BounceGridTexCoord + vec3(0.0, 0.0, 0.500)));
	myhalf4 bouncegrid_coeff6 = cast_myhalf4(dp_texture3D(Texture_BounceGrid, BounceGridTexCoord + vec3(0.0, 0.0, 0.625)));
	myhalf4 bouncegrid_coeff7 = cast_myhalf4(dp_texture3D(Texture_BounceGrid, BounceGridTexCoord + vec3(0.0, 0.0, 0.750)));
	myhalf4 bouncegrid_coeff8 = cast_myhalf4(dp_texture3D(Texture_BounceGrid, BounceGridTexCoord + vec3(0.0, 0.0, 0.875)));
	myhalf3 bouncegrid_dir = normalize(mat3(BounceGridMatrix) * (surfacenormal.x * VectorS.xyz + surfacenormal.y * VectorT.xyz + surfacenormal.z * VectorR.xyz));
	myhalf3 bouncegrid_dirp = max(cast_myhalf3(0.0, 0.0, 0.0), bouncegrid_dir);
	myhalf3 bouncegrid_dirn = max(cast_myhalf3(0.0, 0.0, 0.0), -bouncegrid_dir);
//	bouncegrid_dirp  = bouncegrid_dirn = cast_myhalf3(1.0,1.0,1.0);
	myhalf3 bouncegrid_light = cast_myhalf3(
		dot(bouncegrid_coeff3.xyz, bouncegrid_dirp) + dot(bouncegrid_coeff6.xyz, bouncegrid_dirn),
		dot(bouncegrid_coeff4.xyz, bouncegrid_dirp) + dot(bouncegrid_coeff7.xyz, bouncegrid_dirn),
		dot(bouncegrid_coeff5.xyz, bouncegrid_dirp) + dot(bouncegrid_coeff8.xyz, bouncegrid_dirn));
	color.rgb += diffusetex * bouncegrid_light * BounceGridIntensity;
	color.rgb += diffusetex * cast_myhalf3(dp_texture3D(Texture_BounceGrid, BounceGridTexCoord)) * BounceGridIntensity * 0.05; // VorteX
//	color.rgb = bouncegrid_dir.rgb * 0.5 + vec3(0.5, 0.5, 0.5);
#else
	color.rgb += diffusetex * cast_myhalf3(dp_texture3D(Texture_BounceGrid, BounceGridTexCoord)) * BounceGridIntensity;
#endif
#endif

#ifdef USEGLOW
#ifdef USEVERTEXTEXTUREBLEND
	color.rgb += mix(cast_myhalf3(dp_texture2D(Texture_SecondaryGlow, TexCoord2)), cast_myhalf3(offsetMappedTexture2D(Texture_Glow)), terrainblend) * Color_Glow;
#else
	color.rgb += cast_myhalf3(offsetMappedTexture2D(Texture_Glow)) * Color_Glow;
#endif
#endif

// VorteX {
#ifdef USECELOUTLINES
#ifdef USEDEFERREDLIGHTMAP
	// tweaked outline shader
	vec4 ScreenTexCoordStep = vec4(PixelToScreenTexCoord.x, 0.0, 0.0, PixelToScreenTexCoord.y);
	vec4  DepthSamples;
	#if 0
		// Omnicide ink
		float DepthSampleScale =  0.3;
		float DepthCompareBias = -0.3;
		float DepthCompareMin  = -0.0;
		float OutlineThresh    =  0.02;
		float OutlineScale     =  1.0;
		float OutlineColorize  =  0.1;
		float OutlineBias      =  0.1;
	#else
		// pencil ink
		float DepthSampleScale =  0.16;
		float DepthCompareBias = -0.3;
		float DepthCompareMin  = -0.2;
		float OutlineThresh    =  0.1;
		float OutlineScale     =  1.0;
		float OutlineColorize  =  0.2;
		float OutlineBias      =  0.2;
	#endif
	float DepthCenter = dp_texture2D(Texture_ScreenNormalMap, ScreenTexCoord).b;
	DepthSamples.x = (DepthCenter - dp_texture2D(Texture_ScreenNormalMap, ScreenTexCoord - ScreenTexCoordStep.xy).b) / (DepthCenter * DepthSampleScale);
	DepthSamples.y = (dp_texture2D(Texture_ScreenNormalMap, ScreenTexCoord + ScreenTexCoordStep.xy).b - DepthCenter) / (DepthCenter * DepthSampleScale);
	DepthSamples.z = (DepthCenter - dp_texture2D(Texture_ScreenNormalMap, ScreenTexCoord - ScreenTexCoordStep.zw).b) / (DepthCenter * DepthSampleScale);
	DepthSamples.w = (dp_texture2D(Texture_ScreenNormalMap, ScreenTexCoord + ScreenTexCoordStep.zw).b - DepthCenter) / (DepthCenter * DepthSampleScale);
	float DepthDelta = min(1.0, max(DepthCompareMin, max(abs(DepthSamples.x - DepthSamples.y), abs(DepthSamples.z - DepthSamples.w)) + DepthCompareBias));
	float DepthOutline = 1.0 - min(1.0, max(0.0, abs(DepthDelta) - OutlineThresh) * OutlineScale);
	// sepia
	color.rgb = mix(color.rgb, vec3(dot(color.rgb, vec3(0.299, 0.587, 0.114))) * vec3(1.0, 0.85, 0.6)*1.5, 0.33);
	// darken outlines
	color.rgb *= max(0.33, DepthOutline);
#endif
#endif

#ifdef USEFOG
#if defined(MODE_LIGHTDIRECTIONMAP_MODELSPACE) || defined(MODE_DEFERREDGEOMETRY) || defined(USEREFLECTCUBE) || defined(USEBOUNCEGRIDDIRECTIONAL)
	vec3 EyeVectorModelSpace = vec3(VectorS.w, VectorT.w, VectorR.w);
#endif
#ifdef SHOWFOG
	color.rgb = FogVertex(vec4(0.0, 0.0, 0.0, 1.0), EyeVectorModelSpace, EyeVectorFogDepth.w);
#else
	color.rgb = FogVertex(color, EyeVectorModelSpace, EyeVectorFogDepth.w);
#endif
#endif
#ifdef SHOWVERTEXALPHA
#ifdef USEVERTEXTEXTUREBLEND
	color.rgb = mix(color.rgb, vec3(1.0, 0.5, 0), VertexColor.a * 0.15) + vec3(1.0, 0.5, 0) * VertexColor.a * 0.33;
#endif
#ifdef USEALPHAGENVERTEX
	color.rgb = mix(color.rgb, vec3(1.0, 0.5, 0), VertexColor.a * 0.15) + vec3(1.0, 0.5, 0) * VertexColor.a * 0.33;
	color.a = mix(color.a, VertexColor.a, 0.5);
#endif
#ifdef USEVEGETATION
	color.rgb = VertexColor.rgb;
#endif
#endif
// } VorteX

	// reflection must come last because it already contains exactly the correct fog (the reflection render preserves camera distance from the plane, it only flips the side) and ContrastBoost/SceneBrightness
#ifdef USEREFLECTION
	vec4 ScreenScaleRefractReflectIW = ScreenScaleRefractReflect * (1.0 / ModelViewProjectionPosition.w);
	//vec4 ScreenTexCoord = (ModelViewProjectionPosition.xyxy + normalize(cast_myhalf3(offsetMappedTexture2D(Texture_Normal)) - cast_myhalf3(0.5)).xyxy * DistortScaleRefractReflect * 100) * ScreenScaleRefractReflectIW + ScreenCenterRefractReflect;
	vec2 SafeScreenTexCoord = ModelViewProjectionPosition.xy * ScreenScaleRefractReflectIW.zw + ScreenCenterRefractReflect.zw;
	#ifdef USENORMALMAPSCROLLBLEND
# ifdef USEOFFSETMAPPING
		vec3 normal = dp_textureGrad(Texture_Normal, (TexCoord + vec2(0.08, 0.08)*ClientTime*NormalmapScrollBlend.x*0.5)*NormalmapScrollBlend.y, dPdx*NormalmapScrollBlend.y, dPdy*NormalmapScrollBlend.y).rgb - vec3(1.0);
# else
		vec3 normal = dp_texture2D(Texture_Normal, (TexCoord + vec2(0.08, 0.08)*ClientTime*NormalmapScrollBlend.x*0.5)*NormalmapScrollBlend.y).rgb - vec3(1.0);
# endif
		normal += dp_texture2D(Texture_Normal, (TexCoord + vec2(-0.06, -0.09)*ClientTime*NormalmapScrollBlend.x)*NormalmapScrollBlend.y*0.75).rgb;
		vec2 ScreenTexCoord = SafeScreenTexCoord + vec3(normalize(cast_myhalf3(normal))).xy * DistortScaleRefractReflect.zw;
	#else
		vec2 ScreenTexCoord = SafeScreenTexCoord + vec3(normalize(cast_myhalf3(offsetMappedTexture2D(Texture_Normal)) - cast_myhalf3(0.5))).xy * DistortScaleRefractReflect.zw;
	#endif
	// FIXME temporary hack to detect the case that the reflection
	// gets blackened at edges due to leaving the area that contains actual
	// content.
	// Remove this 'ack once we have a better way to stop this thing from
	// 'appening.
	float f = min(1.0, length(dp_texture2D(Texture_Reflection, ScreenTexCoord + vec2(0.01, 0.01)).rgb) / 0.05);
	f      *= min(1.0, length(dp_texture2D(Texture_Reflection, ScreenTexCoord + vec2(0.01, -0.01)).rgb) / 0.05);
	f      *= min(1.0, length(dp_texture2D(Texture_Reflection, ScreenTexCoord + vec2(-0.01, 0.01)).rgb) / 0.05);
	f      *= min(1.0, length(dp_texture2D(Texture_Reflection, ScreenTexCoord + vec2(-0.01, -0.01)).rgb) / 0.05);
	ScreenTexCoord = mix(SafeScreenTexCoord, ScreenTexCoord, f);
	color.rgb = mix(color.rgb, cast_myhalf3(dp_texture2D(Texture_Reflection, ScreenTexCoord)) * ReflectColor.rgb, ReflectColor.a);
#endif
#ifdef USEOCCLUDE
   color.rgb *= clamp(float(visiblepixels) / float(allpixels), 0.0, 1.0);
#endif

// VorteX {
#ifdef USEGAMMARAMPS
	color.r = dp_texture2D(Texture_GammaRamps, vec2(color.r, 0)).r;
	color.g = dp_texture2D(Texture_GammaRamps, vec2(color.g, 0)).g;
	color.b = dp_texture2D(Texture_GammaRamps, vec2(color.b, 0)).b;
#endif
// } VorteX

	dp_FragColor = vec4(color);
}
#endif // FRAGMENT_SHADER

#endif // !MODE_DEFERREDLIGHTSOURCE
#endif // !MODE_DEFERREDGEOMETRY
#endif // !MODE_WATER
#endif // !MODE_REFRACTION
#endif // !MODE_BLOOMBLUR
#endif // !MODE_GENERIC
#endif // !MODE_POSTPROCESS
#endif // !MODE_DEPTH_OR_SHADOW
