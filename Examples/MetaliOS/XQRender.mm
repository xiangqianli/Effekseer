//
//  XQRender.m
//  MetalT
//
//  Created by 李向前 on 2023/2/27.
//

#import "XQRender.h"
#include <Metal/LLGI.CommandListMetal.h>
#include <Metal/LLGI.GraphicsMetal.h>
#include <LLGI.Compiler.h>
#include <LLGI.Graphics.h>
#include <LLGI.Platform.h>
#include <Utils/LLGI.CommandListPool.h>
#include <EffekseerRendererMetal.h>
#include <string>
#include <codecvt>
#include <iostream>

static int32_t animationTime = 20;

using namespace std;
std::u16string to_utf16( std::string str )
{ return std::wstring_convert< std::codecvt_utf8_utf16<char16_t>, char16_t >{}.from_bytes(str); }

@interface XQRender()

@property (nonatomic, strong) MTKView *metalView;

@end

@implementation XQRender {
    std::shared_ptr<LLGI::Window> window;
    std::shared_ptr<LLGI::Platform> platform;
    std::shared_ptr<LLGI::Graphics> graphics;
    std::shared_ptr<LLGI::SingleFrameMemoryPool> memoryPool;
    std::shared_ptr<LLGI::CommandListPool> commandListPool;
    LLGI::CommandList* commandList;

    ::Effekseer::ManagerRef efkManager;
    ::EffekseerRenderer::RendererRef efkRenderer;
    ::Effekseer::RefPtr<EffekseerRenderer::SingleFrameMemoryPool> efkMemoryPool;
    ::Effekseer::RefPtr<EffekseerRenderer::CommandList> efkCommandList;
    
    ::Effekseer::EffectRef effect_;
    Effekseer::Handle efkHandle_;
    
    ::Effekseer::Matrix44 cameraMatrix_;
    ::Effekseer::Matrix44 projectionMatrix_;
    ::Effekseer::Vector3D viewerPosition_;
}

- (instancetype)initWithMetalKitView:(MTKView *)mtkView {
    if (self = [super init]) {
        _metalView = mtkView;
        [self initMetalPlatform];
        [self initRenderManager];
        
        [self initData];
    }
    return self;
}

#pragma mark -- Private Method
- (void)initRenderManager {
    efkManager = ::Effekseer::Manager::Create(8000);
    efkRenderer = ::EffekseerRendererMetal::Create(
                                                   8000, MTLPixelFormatBGRA8Unorm, MTLPixelFormatInvalid, false);
    
    efkMemoryPool = EffekseerRenderer::CreateSingleFrameMemoryPool(efkRenderer->GetGraphicsDevice());
    efkCommandList = EffekseerRenderer::CreateCommandList(efkRenderer->GetGraphicsDevice(), efkMemoryPool);
    efkManager->SetSpriteRenderer(efkRenderer->CreateSpriteRenderer());
    efkManager->SetRibbonRenderer(efkRenderer->CreateRibbonRenderer());
    efkManager->SetRingRenderer(efkRenderer->CreateRingRenderer());
    efkManager->SetTrackRenderer(efkRenderer->CreateTrackRenderer());
    efkManager->SetModelRenderer(efkRenderer->CreateModelRenderer());
    
    // jessicatli 不设置这个，资源会加载不出来
    efkManager->SetTextureLoader(efkRenderer->CreateTextureLoader());
    efkManager->SetModelLoader(efkRenderer->CreateModelLoader());
    efkManager->SetMaterialLoader(efkRenderer->CreateMaterialLoader());
    efkManager->SetCurveLoader(Effekseer::MakeRefPtr<Effekseer::CurveLoader>());
}

- (void)initMetalPlatform {
    commandList = nullptr;
    
    LLGI::PlatformParameter platformParam{};
    platformParam.Device = LLGI::DeviceType::Metal;
    platformParam.WaitVSync = true;
    
    CGSize rect = [UIScreen mainScreen].bounds.size;
    window = std::shared_ptr<LLGI::Window>(LLGI::CreateWindow("testWindown", { static_cast<int32_t>(rect.width), static_cast<int32_t>(rect.height) }));
    platform = LLGI::CreateSharedPtr(LLGI::CreatePlatformWithView(platformParam, window.get(), (__bridge void *)self.metalView));
    graphics = LLGI::CreateSharedPtr(platform->CreateGraphics());
    
    memoryPool = LLGI::CreateSharedPtr(graphics->CreateSingleFrameMemoryPool(1024 * 1024, 128));
    commandListPool = std::make_shared<LLGI::CommandListPool>(graphics.get(), memoryPool.get(), 3);
}

- (void)initData {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    std::u16string bundlePath16 = to_utf16(bundlePath.UTF8String);
    const char16_t *bundle16 = bundlePath16.c_str();
    
    NSString *resourcePath = [[NSBundle mainBundle] pathForResource:@"Laser01" ofType:@"efkefc"];
    std::u16string resourcePath16 = to_utf16(resourcePath.UTF8String);
    const char16_t *char16 = resourcePath16.c_str();
    effect_ = Effekseer::Effect::Create(efkManager, char16, 1, bundle16);
    
    efkHandle_ = 0;
    
    viewerPosition_ = ::Effekseer::Vector3D(10.0f, 5.0f, 20.0f);
    ::Effekseer::Matrix44 projectionMatrix;
    
    CGSize rect = [UIScreen mainScreen].bounds.size;
    projectionMatrix.PerspectiveFovRH(90.0f / 180.0f * 3.14f, (float)rect.width / (float)rect.height, 1.0f, 500.0f);
    
    ::Effekseer::Matrix44 cameraMatrix;
    cameraMatrix.LookAtRH(viewerPosition_, ::Effekseer::Vector3D(0.0f, 0.0f, 0.0f), ::Effekseer::Vector3D(0.0f, 1.0f, 0.0f));
    
    projectionMatrix_ = projectionMatrix;
    cameraMatrix_ = cameraMatrix;
}

- (BOOL)newFrame {
    if (!platform->NewFrame())
        return false;

    memoryPool->NewFrame();

    commandList = commandListPool->Get();

    LLGI::Color8 color;
    color.R = 0;
    color.G = 0;
    color.B = 0;
    color.A = 255;

    commandList->Begin();
    commandList->BeginRenderPass(platform->GetCurrentScreen(color, true, false));

    // Call on starting of a frame
    // フレームの開始時に呼ぶ
    efkMemoryPool->NewFrame();

    // Begin a command list
    // コマンドリストを開始する。
    EffekseerRendererMetal::BeginCommandList(efkCommandList, [self GetEncoder]);
    efkRenderer->SetCommandList(efkCommandList);

    return true;
}

- (id<MTLRenderCommandEncoder>)GetEncoder {
    LLGI::CommandList* command = commandList;;
    return static_cast<LLGI::CommandListMetal*>(command)->GetRenderCommandEncorder();
}

- (void)PresentDevice {
    // Finish a command list
    // コマンドリストを終了する。
    efkRenderer->SetCommandList(nullptr);
    EffekseerRendererMetal::EndCommandList(efkCommandList);

    commandList->EndRenderPass();
    commandList->End();

    graphics->Execute(commandList);

    platform->Present();
}

- (void)ClearScreen {
    
}

#pragma mark - Delegate
- (void)drawInMTKView:(nonnull MTKView *)view {
    [self newFrame];
    if (animationTime % 120 == 0)
    {
        // Play an effect
        // エフェクトの再生
        efkHandle_ = efkManager->Play(effect_, 0, 0, 0);
    }

    if (animationTime % 120 == 119)
    {
        // Stop effects
        // エフェクトの停止
        efkManager->StopEffect(efkHandle_);
    }

    // Move the effect
    // エフェクトの移動
    efkManager->AddLocation(efkHandle_, ::Effekseer::Vector3D(0.2f, 0.0f, 0.0f));

    // Set layer parameters
    // レイヤーパラメータの設定
    Effekseer::Manager::LayerParameter layerParameter;
    layerParameter.ViewerPosition = viewerPosition_;
    efkManager->SetLayerParameter(0, layerParameter);

    // Update the manager
    // マネージャーの更新
    Effekseer::Manager::UpdateParameter updateParameter;
    efkManager->Update(updateParameter);

    // Execute functions about DirectX
    // DirectXの処理
    [self ClearScreen];

    // Update a time
    // 時間を更新する
    efkRenderer->SetTime(animationTime);
    NSLog(@"animationTime %d", animationTime);

    // Specify a projection matrix
    // 投影行列を設定
    efkRenderer->SetProjectionMatrix(projectionMatrix_);

    // Specify a camera matrix
    // カメラ行列を設定
    efkRenderer->SetCameraMatrix(cameraMatrix_);

    // Begin to rendering effects
    // エフェクトの描画開始処理を行う。
    efkRenderer->BeginRendering();

    // Render effects
    // エフェクトの描画を行う。
    Effekseer::Manager::DrawParameter drawParameter;
    drawParameter.ZNear = 0.0f;
    drawParameter.ZFar = 1.0f;
    drawParameter.ViewProjectionMatrix = efkRenderer->GetCameraProjectionMatrix();
    efkManager->Draw(drawParameter);

    // Finish to rendering effects
    // エフェクトの描画終了処理を行う。
    efkRenderer->EndRendering();

    // Execute functions about DirectX
    // DirectXの処理
    [self PresentDevice];

    animationTime++;
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    
}

@end
