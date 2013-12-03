/*
 * CC3Texturable.vsh
 *
 * cocos3d 2.0.0
 * Author: Bill Hollings
 * Copyright (c) 2011-2013 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * http://en.wikipedia.org/wiki/MIT_License
 */

/**
 * This vertex shader provides a general shader for covering a mesh with a material.
 *
 * This shader supports the following features:
 *   - Up to two textures (more can be added by increasing MAX_TEXTURES, v_texCoord[] & a_cc3TexCoordN. See below).
 *   - Realistic interaction with up to four lights (more can be added by increasing MAX_LIGHTS below).
 *   - Positional, directional, or spot lighting with attenuation.
 *   - Vertex skinning (bone rigged characters) using bone matrices to handle both rigid
 *     and non-rigid skeletons.
 *   - Tangent-space or object-space bump-mapping.
 *   - Environmental reflection mapping using a cube-mapped texture (in addition to the 2 visible textures).
 *   - Fog effects.
 *
 * This vertex shader can be paired with the following fragment shaders:
 *   - CC3NoTexture.fsh
 *   - CC3NoTextureAlphaTest.fsh
 *   - CC3NoTextureReflect.fsh
 *   - CC3NoTextureReflectAlphaTest.fsh
 *   - CC3SingleTexture.fsh
 *   - CC3SingleTextureAlphaTest.fsh
 *   - CC3SingleTextureReflect.fsh
 *   - CC3SingleTextureReflectAlphaTest.fsh
 *   - CC3BumpMapObjectSpace.fsh
 *   - CC3BumpMapObjectSpaceAlphaTest.fsh
 *   - CC3BumpMapTangentSpace.fsh
 *   - CC3BumpMapTangentSpaceAlphaTest.fsh
 *   - CC3MultiTextureConfigurable.fsh
 *   - CC3PureColor.fsh (for node picking from touches)
 *
 * The semantics of the variables in this shader can be mapped using a
 * CC3ShaderProgramSemanticsByVarName instance.
 */

// Increase these if more textures, lights, bones per skin section, or bone per vertex are required.
#define MAX_TEXTURES			2
#define MAX_LIGHTS				4
#define MAX_BONES_PER_BATCH		12
#define MAX_BONES_PER_VERTEX	4

precision mediump float;

//-------------- UNIFORMS ----------------------

uniform highp mat4	u_cc3MatrixModel;				/**< Current model-to-world matrix. */
uniform highp mat4	u_cc3MatrixModelViewProj;		/**< Current model-view-projection matrix. */

uniform lowp vec4	u_cc3Color;						/**< Color when lighting & materials are not in use. */
uniform lowp vec4	u_cc3MaterialAmbientColor;		/**< Ambient color of the material. */
uniform lowp vec4	u_cc3MaterialDiffuseColor;		/**< Diffuse color of the material. */
uniform lowp vec4	u_cc3MaterialSpecularColor;		/**< Specular color of the material. */
uniform lowp vec4	u_cc3MaterialEmissionColor;		/**< Emission color of the material. */
uniform float		u_cc3MaterialShininess;			/**< Shininess of the material. */

uniform highp vec3	u_cc3CameraPositionModel;		/**< Location of the camera in local coordinates of model (not camera). */

uniform bool		u_cc3LightIsUsingLighting;						/**< Indicates whether any lighting is enabled */
uniform lowp vec4	u_cc3LightSceneAmbientLightColor;				/**< Ambient light color of the scene. */
uniform bool		u_cc3LightIsLightEnabled[MAX_LIGHTS];			/**< Indicates whether each light is enabled. */
uniform highp vec4	u_cc3LightPositionModel[MAX_LIGHTS];			/**< Position or normalized direction in the local coords of the model of each light. */
uniform lowp vec4	u_cc3LightAmbientColor[MAX_LIGHTS];				/**< Ambient color of each light. */
uniform lowp vec4	u_cc3LightDiffuseColor[MAX_LIGHTS];				/**< Diffuse color of each light. */
uniform lowp vec4	u_cc3LightSpecularColor[MAX_LIGHTS];			/**< Specular color of each light. */
uniform vec3		u_cc3LightAttenuation[MAX_LIGHTS];				/**< Coefficients of the attenuation equation of each light. */
uniform highp vec3	u_cc3LightSpotDirectionModel[MAX_LIGHTS];		/**< Direction of each spotlight in local coordinates of the model (not light). */
uniform float		u_cc3LightSpotExponent[MAX_LIGHTS];				/**< Directional attenuation factor, if spotlight, of each light. */
uniform float		u_cc3LightSpotCutoffAngleCosine[MAX_LIGHTS];	/**< Cosine of spotlight cutoff angle of each light. */

uniform lowp int	u_cc3VertexBoneCount;								/**< Number of bones influencing each vertex. */
uniform highp mat4	u_cc3BoneMatricesModel[MAX_BONES_PER_BATCH];		/**< Array of bone matrices in the current mesh skin section in model space. */
uniform mat3		u_cc3BoneMatricesInvTranModel[MAX_BONES_PER_BATCH];	/**< Array of inverse-transposes of the bone matrices in the current mesh skin section in model space. */

uniform bool		u_cc3VertexHasTangent;				/**< Whether the vertex tangent is available. */
uniform bool		u_cc3VertexHasColor;				/**< Whether the vertex color is available. */
uniform bool		u_cc3VertexShouldNormalizeNormal;	/**< Whether the vertex normal should be normalized. */
uniform bool		u_cc3VertexShouldRescaleNormal;		/**< Whether the vertex normal should be rescaled. */
uniform bool		u_cc3VertexShouldDrawFrontFaces;	/**< Whether the front side of each face is to be drawn. */
uniform bool		u_cc3VertexShouldDrawBackFaces;		/**< Whether the back side of each face is to be drawn. */

//-------------- VERTEX ATTRIBUTES ----------------------
attribute highp vec4	a_cc3Position;		/**< Vertex position. */
attribute vec3			a_cc3Normal;		/**< Vertex normal. */
attribute vec3			a_cc3Tangent;		/**< Vertex tangent. */
attribute vec4			a_cc3Color;			/**< Vertex color. */
attribute vec4			a_cc3BoneWeights;	/**< Vertex skinning bone weights (each an array of length specified by u_cc3VertexBoneCount). */
attribute vec4			a_cc3BoneIndices;	/**< Vertex skinning bone indices (each an array of length specified by u_cc3VertexBoneCount). */
attribute vec2			a_cc3TexCoord0;		/**< Vertex texture coordinate for texture unit 0. */
attribute vec2			a_cc3TexCoord1;		/**< Vertex texture coordinate for texture unit 1. */
attribute vec2			a_cc3TexCoord2;		/**< Vertex texture coordinate for texture unit 2. */
attribute vec2			a_cc3TexCoord3;		/**< Vertex texture coordinate for texture unit 3. */

//-------------- VARYING VARIABLE OUTPUTS ----------------------
varying vec2			v_texCoord[MAX_TEXTURES];	/**< Fragment texture coordinates. */
varying lowp vec4		v_color;					/**< Fragment front-face color. */
varying lowp vec4		v_colorBack;				/**< Fragment back-face color. */
varying highp float		v_distEye;					/**< Fragment distance in eye coordinates. */
varying vec3			v_bumpMapLightDir;			/**< Direction to the first light in either tangent space or model space. */
varying vec3			v_reflectDirGlobal;			/**< Fragment reflection vector direction in global coordinates. */

//-------------- CONSTANTS ----------------------
const vec3 kVec3Zero = vec3(0.0);
const vec4 kVec4Zero = vec4(0.0);
const vec3 kAttenuationNone = vec3(1.0, 0.0, 0.0);
const vec3 kHalfPlaneOffset = vec3(0.0, 0.0, 1.0);

//-------------- LOCAL VARIABLES ----------------------
highp vec4	vtxPos;				/**< The vertex position. High prec to match vertex attribute. */
vec3		vtxNorm;			/**< The vertex normal. */
lowp vec4	matColorAmbient;	/**< Ambient color of material...from either material or vertex colors. */
lowp vec4	matColorDiffuse;	/**< Diffuse color of material...from either material or vertex colors. */

//-------------- FUNCTIONS ----------------------

/** If this model has bones, transforms the vertex position and normal with the bones. */
void skinVertex() {
	if (u_cc3VertexBoneCount == 0) {		// No vertex skinning
		vtxPos = a_cc3Position;
		vtxNorm = a_cc3Normal;
	} else {								// Mesh is bone-rigged for vertex skinning
		vtxPos = kVec4Zero;					// Start at zero to accumulate weighted values
		vtxNorm = kVec3Zero;
		for (lowp int i = 0; i < MAX_BONES_PER_VERTEX; ++i) {
			if (i < u_cc3VertexBoneCount) {

				// Get the index and weight of this bone
				int boneIdx = int(a_cc3BoneIndices[i]);
				float boneWeight = a_cc3BoneWeights[i];

				// Rotate and translate the vertex position and add its weighted contribution.
				vtxPos += u_cc3BoneMatricesModel[boneIdx] * a_cc3Position * boneWeight;

				// Rotate the vertex normal and add its weighted contribution.
				vtxNorm += u_cc3BoneMatricesInvTranModel[boneIdx] * a_cc3Normal * boneWeight;
			}
		}
		if (u_cc3VertexShouldNormalizeNormal)
			vtxNorm = normalize(vtxNorm);
		else if (u_cc3VertexShouldRescaleNormal)
			vtxNorm = normalize(vtxNorm);	// TODO - rescale without having to normalize
	}
}

/**
 * Returns a vector the contains the direction and intensity of light from the light at the
 * specified index, taking into consideration attenuation due to distance and spotlight dispersion.
 *
 * The use of highp on the floats is required due to the sensitivity of the calculations.
 * Compiler can crash when attempting to cast back and forth.
 */
highp vec4 illuminationFrom(int ltIdx) {

	// Position vector from light. Use high precision for accuracy.
	highp vec3 ltPos = u_cc3LightPositionModel[ltIdx].xyz;

	// Directional light. Position is expected to be a normalized direction!
	if (u_cc3LightPositionModel[ltIdx].w == 0.0) return highp vec4(ltPos, 1.0);
	
	// Positional light. Find the directional vector from vertex to light, but don't normalize yet.
	ltPos -= vtxPos.xyz;
	highp float intensity = 1.0;
	
	// Calculate intensity due to distance attenuation (must be performed in high precision)
	if (u_cc3LightAttenuation[ltIdx] != kAttenuationNone) {
		highp float ltDist = length(ltPos);
		highp vec3 distAtten = highp vec3(1.0, ltDist, ltDist * ltDist);
		highp float distIntensity = 1.0 / dot(distAtten, u_cc3LightAttenuation[ltIdx]);	// needs highp
		intensity *= min(abs(distIntensity), 1.0);
	}

	ltPos = normalize(ltPos);	// Now normalize into a normalized direction vector.
	
	// Determine intensity due to spotlight component
	highp float spotCutoffCos = u_cc3LightSpotCutoffAngleCosine[ltIdx];
	if (spotCutoffCos >= 0.0) {
		highp vec3 spotDir = u_cc3LightSpotDirectionModel[ltIdx];
		highp float cosDir = -dot(ltPos, spotDir);
		if (cosDir >= spotCutoffCos){
			highp float spotExp = u_cc3LightSpotExponent[ltIdx];
			intensity *= pow(cosDir, spotExp);
		} else {
			intensity = 0.0;
		}
	}
	
	return highp vec4(ltPos, intensity);	// Return combined light direction & intensity
}

/**
 * Returns the portion of vertex color attributed to the specified illumination, which
 * contains the direction and intensity of the light at the specified index. The color is
 * determined by the interaction between the illumination and the specified vertex normal.
 *
 * The use of highp on the illumination is required due to the sensitivity of the
 * calculations, as the compiler can crash when attempting to cast back and forth.
 * Similarly, the use of the default mediump for the return value, instead of lowp,
 * avoids a strange execution stalling during drawing if lowp is returned!
 */
vec4 illuminateWith(highp vec4 illumination, int ltIdx, vec3 vNorm) {

	highp float intensity = illumination.w;
	if (intensity <= 0.0) return kVec4Zero;		// If no intensity, short-circuit to no color

	highp vec3 ltDir = illumination.xyz;
	
	// Employ lighting equation to calculate vertex color, using mediump for accuracy.
	vec4 vtxColor = (u_cc3LightAmbientColor[ltIdx] * matColorAmbient);
	vtxColor += (u_cc3LightDiffuseColor[ltIdx] * matColorDiffuse * max(0.0, dot(vNorm, ltDir)));
	
	// Project normal onto half-plane vector to determine specular component
	float specProj = dot(vNorm, normalize(ltDir + kHalfPlaneOffset));
	if (specProj > 0.0) vtxColor += (pow(specProj, u_cc3MaterialShininess) *
									 u_cc3MaterialSpecularColor *
									 u_cc3LightSpecularColor[ltIdx]);
	
	return vtxColor * intensity;	// Return the attenuated vertex color
}

/** Adjusts the vertex color by illuminating the material with each enabled light. */
void illuminateVertex() {
	for (int ltIdx = 0; ltIdx < MAX_LIGHTS; ltIdx++) {
		if (u_cc3LightIsLightEnabled[ltIdx]) {
			highp vec4 illum = illuminationFrom(ltIdx);
			if (u_cc3VertexShouldDrawFrontFaces) v_color += illuminateWith(illum, ltIdx, vtxNorm);
			if (u_cc3VertexShouldDrawBackFaces) v_colorBack += illuminateWith(illum, ltIdx, -vtxNorm);
		}
	}
}

/**
 * If mesh has per-vertex tangents, returns the direction to the specified light in tangent
 * space coordinates. The associated normal-map texture must match this and specify its
 * normals in tangent-space. If no per-vertex tangents, simply return a zero vector.
 */
vec3 bumpMapDirectionForLight(int ltIdx) {
	if ( !u_cc3VertexHasTangent ) return kVec3Zero;
	
	// Get the light direction in model space. If the light is positional
	// calculate the normalized direction from the light and vertex positions.
	vec3 ltDir = u_cc3LightPositionModel[ltIdx].xyz;
	if (u_cc3LightPositionModel[ltIdx].w != 0.0) ltDir = normalize(ltDir - vtxPos.xyz);
	
	// Create a matrix that transforms from model space to tangent space, and transform light direction.
	vec3 bitangent = cross(a_cc3Normal, a_cc3Tangent);
	mat3 tangentSpaceXfm = mat3(a_cc3Tangent, bitangent, a_cc3Normal);
	ltDir *= tangentSpaceXfm;

	return ltDir;
}

/** 
 * For environmental mapping reflection effect, reflects the camera direction into a global-coordinate
 * reflection vector, v_reflectDirGlobal that can be used in a cube-map texture sampler.
 */
void reflectVertex() {
	vec3 camDir = vtxPos.xyz - u_cc3CameraPositionModel;
	v_reflectDirGlobal = (u_cc3MatrixModel * vec4(reflect(camDir, vtxNorm), 0.0)).xyz;
}


//-------------- ENTRY POINT ----------------------
void main() {

	skinVertex();	// If model has bones, transform vertex position & normal into vtxPos & vtxNorm, respectively
	
	v_distEye = length(vtxPos.xyz);	// Distance from vertex to eye. Used for fog effect.

	reflectVertex();	// Populate v_reflectDirGlobal for reflective environmental mapping
	
	// Determine the color of the vertex by applying material & lighting, or using a pure color
	if (u_cc3LightIsUsingLighting) {

		// If vertices have individual colors, use them for ambient and diffuse material colors.
		matColorAmbient = u_cc3VertexHasColor ? a_cc3Color : u_cc3MaterialAmbientColor;
		matColorDiffuse = u_cc3VertexHasColor ? a_cc3Color : u_cc3MaterialDiffuseColor;
		
		v_color = u_cc3MaterialEmissionColor + (matColorAmbient * u_cc3LightSceneAmbientLightColor);
		v_colorBack = v_color;

		illuminateVertex();

		v_color.a = matColorDiffuse.a;
		v_colorBack.a = matColorDiffuse.a;
		
		// If the model uses tanget-space bump-mapping, we need a variable to track the light direction.
		// It's a varying because when using tangent-space normals, we need the light direction per fragment.
		v_bumpMapLightDir = bumpMapDirectionForLight(0);

	} else {
		v_color = u_cc3VertexHasColor ? a_cc3Color : u_cc3Color;
		v_colorBack = v_color;
		v_bumpMapLightDir = kVec3Zero;
	}
	
	// Fragment texture coordinates. Add more as needed.
	v_texCoord[0] = a_cc3TexCoord0;
	v_texCoord[1] = a_cc3TexCoord1;
//	v_texCoord[2] = a_cc3TexCoord2;		// Uncomment if MAX_TEXTURES increased
//	v_texCoord[3] = a_cc3TexCoord3;		// Uncomment if MAX_TEXTURES increased
	
	gl_Position = u_cc3MatrixModelViewProj * vtxPos;
}

