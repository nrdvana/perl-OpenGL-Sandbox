uniform vec4      iMouse;
uniform vec3      iResolution;
uniform float     iGlobalTime;
uniform float     iChannelTime[4];
uniform vec4      iDate;
uniform float     iSampleRate;
uniform vec3      iChannelResolution[4];
uniform int       iFrame;
uniform float     iTimeDelta;
uniform float     iFrameRate;
uniform mat4      iCamera;
uniform mat4      iModel;
uniform mat4      iProjection;

uniform sampler2D iChannel0;
uniform sampler2D iChannel1;
uniform sampler2D iChannel2;
uniform sampler2D iChannel3;

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    fragColor = vec4(uv,0.5+0.5*sin(iGlobalTime),cos(iGlobalTime)); // 1.0
}

void main() {
    vec4 color = vec4(0.0,0.0,0.0,1.0);
    mainImage( color, gl_FragCoord.xy );
    gl_FragColor = color;
}
