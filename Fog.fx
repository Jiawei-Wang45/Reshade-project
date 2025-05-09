#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform float timer < source = "timer"; >;
uniform float FogStart < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 0.5;
    ui_step=0.05;
	ui_label = "FogStart";
    ui_tooltip = "The linear depth for the fog to start bloom";
> = 0.0;

uniform float FogEnd < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.5; ui_max = 1.0;
    ui_step=0.05;
	ui_label = "FogEnd";
    ui_tooltip = "The linear depth for the fog to maximun beyond this distance";
> = 1.0;

uniform float3 FogColor <ui_type = "color";> = float3(0.7, 0.7, 0.7);

uniform float MovingSpeed < __UNIFORM_SLIDER_FLOAT1 
    ui_min = 1.0; 
    ui_max = 8.0; 
    ui_step=1;
	ui_label = "MovingSpeed" ;
    ui_tooltip = "Control the moving speed of fog" ;
> = 2.0;

uniform float amplitude < __UNIFORM_SLIDER_FLOAT1 
    ui_min = 2.0; 
    ui_max = 10.0; 
    ui_step=1;
    ui_label = "amplitude" ;
	ui_tooltip = "Control the amplitude of the irregularity of fog" ;
> = 5.0;

uniform float distortion < __UNIFORM_SLIDER_FLOAT1 
    ui_min = 10.0; 
    ui_max = 100.0; 
    ui_step=10.0;
    ui_label = "distortion" ;
	ui_tooltip = "Control the distortion effect of local fog" ;
> = 30.0;

uniform float breathingSpeed < __UNIFORM_SLIDER_FLOAT1 
    ui_min = 0.0; 
    ui_max = 1.0; 
    ui_step=0.05;
    ui_label = "breathingSpeed" ;
	ui_tooltip = "Control the breathing speed between original fog and blurred fog " ;
> = 0.333;


texture2D Noise1Tex < source = "Noise1.png"; > {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format  = R8;
};
sampler2D Noise1Smp {
    Texture = Noise1Tex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU  = WRAP;  
    AddressV  = WRAP;
};

texture2D Noise2Tex < source = "Noise2.png"; > {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format  = R8;
};
sampler2D Noise2Smp {
    Texture = Noise2Tex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU  = WRAP;  
    AddressV  = WRAP;
};

texture2D Noise3Tex < source = "Noise3.png"; > {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format  = R8;
};
sampler2D Noise3Smp {
    Texture = Noise3Tex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU  = WRAP;  
    AddressV  = WRAP;
};

float3 Fog(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float3 color=tex2D(ReShade::BackBuffer,texcoord).rgb;
    float depth=ReShade::GetLinearizedDepth(texcoord);
    float revisedDepth=smoothstep(FogStart,FogEnd,depth);
    float density=2.0;
    float fogFactor = 1.0 - exp(-revisedDepth * density);
    float time=timer/3000.0;     //turn unit into seconds
    int index=int(floor(time))%3;
    float residual=frac(time); 
    int next=(index+1)%3;
    float noise0, noise1;
    float2 revisedcoord=texcoord+float2(sin(time* MovingSpeed + texcoord.y * distortion)*amplitude, cos(time* MovingSpeed + texcoord.x * distortion)*amplitude) * ReShade::PixelSize;
    switch(index)
    {
        case 0:noise0=tex2D(Noise1Smp,revisedcoord).r;break;
        case 1:noise0=tex2D(Noise2Smp,revisedcoord).r;break;
        default:noise0=tex2D(Noise3Smp,revisedcoord).r;break;
    }
    switch(next)
    {
        case 0:noise1=tex2D(Noise1Smp,revisedcoord).r;break;
        case 1:noise1=tex2D(Noise2Smp,revisedcoord).r;break;
        default:noise1=tex2D(Noise3Smp,revisedcoord).r;break;
    }
    float baseNoise=lerp(noise0,noise1,residual);
    baseNoise=lerp(baseNoise,sin(time),0.05);
    float3 depthTint = lerp(
    float3(1.0, 1.0, 1.0),
    float3(0.8, 0.9, 1.0), 
    pow(revisedDepth, 3.0));
    color*=depthTint;
    float3 blurredColor=lerp(color,FogColor,baseNoise*fogFactor);
    float breathFac=0.2*abs(sin(time*breathingSpeed))+0.5;
    color=lerp(color,blurredColor,breathFac);    
    return color;
}

technique Fog
{
    pass p0
    {
        VertexShader = PostProcessVS;
        PixelShader = Fog;
    }
}