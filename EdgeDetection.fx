#include "ReShadeUI.fxh"
#include "ReShade.fxh"

uniform float timer < source = "timer"; >;
uniform float3 outLineColor <
ui_type = "color";
ui_label = "Color and brightness of outline";
> = float3(1.0, 1.0, 1.0);

uniform int BackGround <
	ui_type = "combo";
    ui_label = "Background Type";
	ui_items = "BackBuffer\0Customized\0";
> = 0;
uniform float3 CustomizedBackgroundColor <ui_type = "color";> = float3(0.0, 0.0, 0.0);

uniform float EdgeThreshhold < __UNIFORM_SLIDER_ANY
	ui_min = 0.0; ui_max = 250;
    ui_step=0.05;
	ui_label = "EdgeThreshhold";
    ui_tooltip = "How much variance in depth should I draw a outline";
> = 100.0;

uniform float OutlineVisible < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
    ui_step=0.05;
	ui_label = "OutlineVisible";
    ui_tooltip = "The visibility of the outline";
> = 0.5;

uniform bool GlowOrNot < 
    ui_type = "checkbox";
    ui_label = "Glowing outline" ;
	ui_tooltip = "Activate glowing effect of outline";
> = true;

uniform bool JitterOrNot < 
    ui_type = "checkbox";
    ui_label = "Jittering effect" ;
	ui_tooltip = "Activate jittering effect horizontally";
> = true;

uniform float JitterSpeed < __UNIFORM_SLIDER_FLOAT1 
    ui_min = 1.0; 
    ui_max = 10.0; 
    ui_step=1;
	ui_label = "JitterSpeed" ;
    ui_tooltip = "Control the jittering speed of outline" ;
> = 2.0;

uniform float freq < __UNIFORM_SLIDER_FLOAT1 
    ui_min = 10.0; 
    ui_max = 100.0; 
    ui_step=10.0;
    ui_label = "jittering frequency" ;
	ui_tooltip = "Control the jittering frequency along the y axis" ;
> = 60.0;

uniform float amplitude < __UNIFORM_SLIDER_FLOAT1 
    ui_min = 1.0; 
    ui_max = 5.0; 
    ui_step=0.5;
    ui_label = "jittering amplitude" ;
	ui_tooltip = "Control the jittering amplitude along the x axis" ;
> = 3.0;

texture2D maskTex < source = "offscreen"; > {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format  = R32F;
};
sampler2D maskSmp {Texture = maskTex;};

texture2D blurHTex < source = "offscreen"; >{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format  = R32F;
};
sampler blurHSmp { Texture = blurHTex;};

texture2D blurVTex < source = "offscreen"; >{
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format  = R32F;
};
sampler blurVSmp { Texture = blurVTex;};

float2 calculatejitter(float y)
{
    return float2(sin(timer/1000 * JitterSpeed + y * freq) * (amplitude*ReShade::PixelSize.x), 0);
}

float sobelDetection(float2 texcoord)
{
    float topleft=ReShade::GetLinearizedDepth(texcoord+ReShade::PixelSize*float2(-1, 1));
    float topMiddle=ReShade::GetLinearizedDepth(texcoord+ReShade::PixelSize*float2(0, 1));
    float topRight=ReShade::GetLinearizedDepth(texcoord+ReShade::PixelSize*float2(1, 1));

    float middleLeft=ReShade::GetLinearizedDepth(texcoord+ReShade::PixelSize*float2(-1, 0));
    float middleRight=ReShade::GetLinearizedDepth(texcoord+ReShade::PixelSize*float2(1, 0));

    float bottomLeft=ReShade::GetLinearizedDepth(texcoord+ReShade::PixelSize*float2(-1, -1));
    float bottomMiddle=ReShade::GetLinearizedDepth(texcoord+ReShade::PixelSize*float2(0, -1));
    float bottomRight=ReShade::GetLinearizedDepth(texcoord+ReShade::PixelSize*float2(1, -1));

    float horizontal=topRight+bottomRight-topleft-bottomLeft+2*(middleRight-middleLeft);
    float vertical=topleft+topRight-bottomLeft-bottomRight+2*(topMiddle-bottomMiddle);
    return sqrt(horizontal*horizontal+vertical*vertical);


}
float MaskEdgeDetection(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	if(JitterOrNot)
	{
		texcoord+=calculatejitter(texcoord.y);
	}
    float edgeFactor=sobelDetection(texcoord);
	return saturate((edgeFactor - (EdgeThreshhold / 100.0)) * 50.0);
    //return saturate(edgeFactor - (EdgeThreshhold / 100.0));
}

float BlurHorizontal(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float sum=0;
	sum+=tex2D(maskSmp,texcoord+ReShade::PixelSize*float2(-4,0)).r*0.05;
	sum+=tex2D(maskSmp,texcoord+ReShade::PixelSize*float2(-2,0)).r*0.25;
	sum+=tex2D(maskSmp,texcoord).r*0.4;
	sum+=tex2D(maskSmp,texcoord+ReShade::PixelSize*float2(2,0)).r*0.25;
	sum+=tex2D(maskSmp,texcoord+ReShade::PixelSize*float2(4,0)).r*0.05;
	return sum;
}

float BlurVeitical(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float sum=0;
	sum+=tex2D(blurHSmp,texcoord+ReShade::PixelSize*float2(0,-4)).r*0.05;
	sum+=tex2D(blurHSmp,texcoord+ReShade::PixelSize*float2(0,-2)).r*0.25;
	sum+=tex2D(blurHSmp,texcoord).r*0.4;
	sum+=tex2D(blurHSmp,texcoord+ReShade::PixelSize*float2(0,2)).r*0.25;
	sum+=tex2D(blurHSmp,texcoord+ReShade::PixelSize*float2(0,4)).r*0.05;
	return sum;
}

float3 GlowEdge(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float3 color;
    if (BackGround==0)
    {
        color=tex2D(ReShade::BackBuffer,texcoord).rgb;
    }
    else if (BackGround==1)
    {
        color=CustomizedBackgroundColor;
    }
    float glowMask=tex2D(maskSmp,texcoord).r;;
    if (GlowOrNot)
    {
	    float blurMask=tex2D(blurVSmp,texcoord).r;
        glowMask=lerp(glowMask,blurMask,0.5);
    }
	float3 glow  = outLineColor * glowMask;

    return /*color+glow;*/lerp(color,color+glow,OutlineVisible);
}

technique test
{

    pass Mask
    {
        VertexShader = PostProcessVS;
        PixelShader = MaskEdgeDetection;
		RenderTarget=maskTex;
    }
	pass BlurHorizontal
	{
		VertexShader = PostProcessVS;
        PixelShader = BlurHorizontal;
		RenderTarget=blurHTex;
	}
	pass BlurVeitical
	{
		VertexShader = PostProcessVS;
        PixelShader = BlurVeitical;
		RenderTarget=blurVTex;
	}
	pass Glow
	{
		VertexShader = PostProcessVS;
        PixelShader = GlowEdge;
	}
}