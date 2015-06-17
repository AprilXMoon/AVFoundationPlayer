//
//  PlayerView.m
//  PlayVideoUseAVPlayer
//
//  Created by April Lee on 2015/4/14.
//  Copyright (c) 2015年 april. All rights reserved.
//

#import "PlayerView.h"


@implementation PlayerView


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        //Initialization code;
        [self addTapGesture];
    }
    
    return self;
}


+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (AVPlayer *)player
{
    return [(AVPlayerLayer *)[self layer]player];
}

- (void)setPlayer:(AVPlayer *)player
{
    [(AVPlayerLayer *)[self layer] setPlayer:player];
}


#pragma mark - tapGestureRecognizer

- (void)addTapGesture
{
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureHander)];
    [self addGestureRecognizer:tapGesture];

}

- (void)tapGestureHander
{
    if ([self.delegate respondsToSelector:@selector(playViewTapGestureHandler:)]) {
        
        [self.delegate playViewTapGestureHandler:self];
    }
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
