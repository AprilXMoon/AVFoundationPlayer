//
//  PlayerView.h
//  PlayVideoUseAVPlayer
//
//  Created by April Lee on 2015/4/14.
//  Copyright (c) 2015年 april. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol PlayViewDelegate;

@interface PlayerView : UIView

@property (strong, nonatomic)AVPlayer *player;
@property (weak,nonatomic) id <PlayViewDelegate> delegate;

- (void)addTapGesture;

@end

@protocol PlayViewDelegate <NSObject>

@optional
- (void)playViewTapGestureHandler:(PlayerView *)playView;

@end
