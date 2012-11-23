//#version 110

//uniform mat4 g_WorldViewProjectionMatrix;
//uniform mat4 g_WorldMatrix;
//uniform mat4 g_NormalMatrix;
//uniform vec3 v3CameraPos;       // The camera's current position
uniform vec3 v3LightPos;        // The Light Position
uniform vec3 v3InvWavelength;   // 1 / pow(wavelength, 4) for the red, green, and blue channels
uniform float fCameraHeight;    // The camera's current height
uniform float fCameraHeight2;   // fCameraHeight^2
uniform float fOuterRadius;     // The outer (atmosphere) radius
uniform float fOuterRadius2;    // fOuterRadius^2
uniform float fInnerRadius;     // The inner (planetary) radius
uniform float fInnerRadius2;    // fInnerRadius^2
uniform float fKrESun;          // Kr * ESun
uniform float fKmESun;          // Km * ESun
uniform float fKr4PI;           // Kr * 4 * PI
uniform float fKm4PI;           // Km * 4 * PI
uniform float fScale;           // 1 / (fOuterRadius - fInnerRadius)
uniform float fScaleDepth;      // The scale depth (i.e. the altitude at which the atmosphere's average density is found)
uniform float fScaleOverScaleDepth; // fScale / fScaleDepth
//uniform int nSamples;
uniform float fSamples;
//attribute vec4 inPosition;
varying vec3 v3Direction;
varying vec4 v4RayleighColor;
varying vec4 v4MieColor;

// assign as constant since "Loop index cannot be compared with non-constant expression"
const int nSamples = 3;

float fInvScaleDepth = (1.0 / fScaleDepth);

// Returns the near intersection point of a line and a sphere
float getNearIntersection(vec3 v3Pos, vec3 v3Ray, float fDistance2, float fRadius2)
{
   float B = 2.0 * dot(v3Pos, v3Ray);
   float C = fDistance2 - fRadius2;
   float fDet = max(0.0, B*B - 4.0 * C);
   return 0.5 * (-B - sqrt(fDet));
}

float scale(float fCos)
{
   float x = 1.0 - fCos;
   return fScaleDepth * exp(-0.00287 + x*(0.459 + x*(3.83 + x*(-6.80 + x*5.25))));
}

void main(void)
{
   vec4 inPosition = vec4(position, 1.0);
   mat4 g_WorldViewProjectionMatrix = projectionMatrix * modelViewMatrix;
   mat4 g_WorldMatrix = modelMatrix;
   g_WorldMatrix = modelViewMatrix;

   gl_Position = g_WorldViewProjectionMatrix * inPosition;
   // Get the ray from the camera to the vertex and its length (which is the far point of the ray passing through the atmosphere)
   //vec3 v3Pos = vec3(g_WorldMatrix * inPosition);
   // modelViewMatrix == g_WorldMatrix

   vec3 v3Pos = vec3(g_WorldMatrix * inPosition);
   vec3 v3Ray = v3Pos - cameraPosition;
   float fFar = length(v3Ray);

   v3Ray /= fFar;

   // Calculate the closest intersection of the ray with the outer atmosphere (which is the near point of the ray passing through the atmosphere)
   float fNear = getNearIntersection(cameraPosition, v3Ray, fCameraHeight2, fOuterRadius2);

   // Calculate the ray's starting position, then calculate its scattering offset
   vec3 v3Start = cameraPosition + v3Ray * fNear;
   fFar -= fNear;
//v3Start = cameraPosition + v3Ray;
   // Calculate the ray's start and end positions in the atmosphere, then calculate its scattering offset
   float fStartAngle = dot(v3Ray, v3Start) / fOuterRadius;
   float fStartDepth = exp(-fInvScaleDepth);
   float fStartOffset = fStartDepth*scale(fStartAngle);

   // Initialize the scattering loop variables
   float fSampleLength = fFar / fSamples;
   float fScaledLength = fSampleLength * fScale;
   vec3 v3SampleRay = v3Ray * fSampleLength;
   vec3 v3SamplePoint = v3Start + v3SampleRay * 0.5;

   // Now loop through the sample rays
   vec3 v3FrontColor = vec3(0.0, 0.0, 0.0);

   for(int i=0; i<nSamples; i++)
   {
      float fHeight = length(v3SamplePoint);
      float fDepth = exp(fScaleOverScaleDepth * (fInnerRadius - fHeight));
      float fLightAngle = dot(v3LightPos, v3SamplePoint) / fHeight;
      float fCameraAngle = dot(v3Ray, v3SamplePoint) / fHeight;
      float fScatter = (fStartOffset + fDepth*(scale(fLightAngle) - scale(fCameraAngle)));
      vec3 v3Attenuate = exp(-fScatter * (v3InvWavelength * fKr4PI + fKm4PI));
      v3FrontColor += v3Attenuate * (fDepth * fScaledLength);
      v3SamplePoint += v3SampleRay;
   }

   // Finally, scale the Mie and Rayleigh colors and set up the varying variables for the pixel shader
   v4MieColor = vec4(v3FrontColor * fKmESun, 1.0);
   v4RayleighColor = vec4(v3FrontColor * (v3InvWavelength * fKrESun), 1.0);
   v3Direction = cameraPosition - v3Pos;
  // last line used to debug....
  //fgds
   float f2near = fNear / 1000.0;
}