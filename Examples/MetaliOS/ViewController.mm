//
//  ViewController.m
//  Project1
//
//  Created by 李向前 on 2023/2/15.
//

#import "ViewController.h"
#import "XQRender.h"
#include <string>

@interface ViewController ()

@property (nonatomic, strong) UIButton *button;

@property (nonatomic, strong) XQRender *render;

@property (nonatomic, strong) MTKView *renderView;

@end

@implementation ViewController {
    
}

- (instancetype)init {
    if (self = [super init]) {
        
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor redColor];
    
//    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
//    self.button.frame = CGRectMake(50, 50, 100, 40);
//    [self.button setTitle:@"测试按钮" forState:UIControlStateNormal];
//    [self.button setTitle:@"测试按钮" forState:UIControlStateHighlighted];
//    [self.button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
//    [self.button setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
//    [self.button addTarget:self action:@selector(clickButton) forControlEvents:UIControlEventTouchUpInside];
//    [self.view addSubview:self.button];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_render == nullptr) {
        _renderView = [[MTKView alloc] initWithFrame:self.view.bounds];
        _renderView.device = MTLCreateSystemDefaultDevice();
        if(!_renderView.device)
        {
            NSLog(@"Metal is not supported on this device");
            return;
        }
        
        _render = [[XQRender alloc] initWithMetalKitView:_renderView];
        if(!_render)
        {
            NSLog(@"Renderer failed initialization");
            return;
        }
        
        //用视图大小初始化渲染器
        [_render mtkView:_renderView drawableSizeWillChange:_renderView.drawableSize];
        
        _renderView.delegate = _render;
        
        [self.view addSubview:_renderView];
    }
}

@end
