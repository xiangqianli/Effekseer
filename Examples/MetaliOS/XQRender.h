//
//  XQRender.h
//  MetalT
//
//  Created by 李向前 on 2023/2/27.
//

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface XQRender : NSObject<MTKViewDelegate>

- (instancetype)initWithMetalKitView:(MTKView *)mtkView;

@end

NS_ASSUME_NONNULL_END
