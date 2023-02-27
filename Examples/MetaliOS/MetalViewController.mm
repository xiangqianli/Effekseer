#import "MetalViewController.h"
#import "CppInterface.h"
#include <Metal/LLGI.CommandListMetal.h>
#include <Metal/LLGI.GraphicsMetal.h>
#include <LLGI.Compiler.h>
#include <LLGI.Graphics.h>
#include <LLGI.Platform.h>
#include <Utils/LLGI.CommandListPool.h>
#include <EffekseerRendererMetal.h>

@interface MetalViewController ()
{
    CppInterface* i;
}
@end

@implementation MetalViewController {
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
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
//    [self initMetalPlatform];
    
//    [self initRenderManager];
}

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
    
    auto viewerPosition = ::Effekseer::Vector3D(10.0f, 5.0f, 20.0f);
    ::Effekseer::Matrix44 projectionMatrix;
    
    CGSize rect = self.view.bounds.size;
    projectionMatrix.PerspectiveFovRH(90.0f / 180.0f * 3.14f, (float)rect.width / (float)rect.height, 1.0f, 500.0f);
    
    ::Effekseer::Matrix44 cameraMatrix;
    cameraMatrix.LookAtRH(viewerPosition, ::Effekseer::Vector3D(0.0f, 0.0f, 0.0f), ::Effekseer::Vector3D(0.0f, 1.0f, 0.0f));
    
    auto effect = Effekseer::Effect::Create(efkManager, EFK_EXAMPLE_ASSETS_DIR_U16 "Laser01.efkefc");

    int32_t time = 20;
    Effekseer::Handle efkHandle = 0;
    
    while ([self newFrame]) {
        if (time % 120 == 0)
        {
            // Play an effect
            // エフェクトの再生
            efkHandle = efkManager->Play(effect, 0, 0, 0);
        }

        if (time % 120 == 119)
        {
            // Stop effects
            // エフェクトの停止
            efkManager->StopEffect(efkHandle);
        }

        // Move the effect
        // エフェクトの移動
        efkManager->AddLocation(efkHandle, ::Effekseer::Vector3D(0.2f, 0.0f, 0.0f));

        // Set layer parameters
        // レイヤーパラメータの設定
        Effekseer::Manager::LayerParameter layerParameter;
        layerParameter.ViewerPosition = viewerPosition;
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
        efkRenderer->SetTime(time);

        // Specify a projection matrix
        // 投影行列を設定
        efkRenderer->SetProjectionMatrix(projectionMatrix);

        // Specify a camera matrix
        // カメラ行列を設定
        efkRenderer->SetCameraMatrix(cameraMatrix);

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

        time++;
    }
}

- (void)initMetalPlatform {
    commandList = nullptr;
    
    LLGI::PlatformParameter platformParam{};
    platformParam.Device = LLGI::DeviceType::Metal;
    platformParam.WaitVSync = true;
    
    CGSize rect = self.view.bounds.size;
    window = std::shared_ptr<LLGI::Window>(LLGI::CreateWindow("testWindown", { static_cast<int32_t>(rect.width), static_cast<int32_t>(rect.height) }));
    platform = LLGI::CreateSharedPtr(LLGI::CreatePlatform(platformParam, window.get()));
    graphics = LLGI::CreateSharedPtr(platform->CreateGraphics());
    
    memoryPool = LLGI::CreateSharedPtr(graphics->CreateSingleFrameMemoryPool(1024 * 1024, 128));
    commandListPool = std::make_shared<LLGI::CommandListPool>(graphics.get(), memoryPool.get(), 3);
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

- (void)ClearScreen {
    
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

@end
