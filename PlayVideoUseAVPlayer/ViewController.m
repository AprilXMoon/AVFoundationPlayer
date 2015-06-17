//
//  ViewController.m
//  PlayVideoUseAVPlayer
//
//  Created by April Lee on 2015/4/14.
//  Copyright (c) 2015年 april. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "PlayerView.h"
#import "MBProgressHUD.h"

#define SCREENHEIGHT [UIScreen mainScreen].bounds.size.height

static void *AVPlayerDemoRateObservationContext = &AVPlayerDemoRateObservationContext;
static void *AVPlayerDemoStatusObservationContext = &AVPlayerDemoStatusObservationContext;
static void *AVPlayerDemoCurrentItemObservationContext = &AVPlayerDemoCurrentItemObservationContext;
static void *AVPlayerDemoLoadedTimeRanges = &AVPlayerDemoLoadedTimeRanges;

@interface ViewController () <PlayViewDelegate>

@property (weak, nonatomic) IBOutlet PlayerView *playerView;
@property (weak, nonatomic) IBOutlet UIButton *controlButton;
@property (weak, nonatomic) IBOutlet UISlider *videoSlider;
@property (weak, nonatomic) IBOutlet UILabel *videoTotalTime;
@property (weak, nonatomic) IBOutlet UILabel *videoCurrtentTime;
@property (weak, nonatomic) IBOutlet UIView *volumeControllerView;
@property (weak, nonatomic) IBOutlet UIView *playControlView;

@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (strong, nonatomic) id playbackTimeObserver;

@property (nonatomic) NSString *fileString;
@property (nonatomic) NSURL *fileURL;

@property (nonatomic) BOOL isPlay;
@property (nonatomic) BOOL isScrubbing;
@property (nonatomic) BOOL isPlayControlShow;
@property (nonatomic) float mRestoreAfterScrubbingRate;
@property (nonatomic) float hidePlayMenuCountdown;

@property (strong,nonatomic) id mTimeObserver;

@property (strong,nonatomic) MBProgressHUD *LoadingHUD;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self setVideoFile];
    [self prepareVideoWithAsset];
    //[self prepareVideoWithURL];
    [self setVideoSliderController];
    [self setVolumnController];
    
    [self initializeParameters];
    [self initiallizeLoadingHUD];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - initailize method

- (void)initializeParameters
{
    self.isPlayControlShow = YES;
    self.hidePlayMenuCountdown = 5;
    
    self.playerView.delegate = self;
    [self.playerView addTapGesture];
}

- (void)initiallizeLoadingHUD
{
    self.LoadingHUD = [[MBProgressHUD alloc] init];
    [self.view addSubview:self.LoadingHUD];
}


- (void)setVideoFile
{
    self.fileString = @"http://devstreaming.apple.com/videos/wwdc/2015/104usewvb5m0qbwafx8p/104/hls_vod_mvp.m3u8";
    self.fileURL = [NSURL URLWithString:self.fileString];
    
    // if the video is local file used "fileURLWithPath";
    //self.fileString = [[NSBundle mainBundle] pathForResource:@"WWDC2014HD" ofType:@"mov"];
    //self.fileURL = [NSURL fileURLWithPath:self.fileString];
}

- (void)setVideoSliderController
{
    UIImage *thumbImage = [UIImage imageNamed:@"Gray"];
    [self.videoSlider setThumbImage:thumbImage forState:UIControlStateNormal];
    [self.videoSlider setThumbImage:thumbImage forState:UIControlStateHighlighted];
    
    UIImage *blueSliderImage = [UIImage imageNamed:@"blueline"];
    UIImage *graySliderImage = [UIImage imageNamed:@"grayline"];
    
    UIImage *sliderRightTrackImage = [graySliderImage resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10, 0, 5)];
    UIImage *sliderLeftTrackImage = [blueSliderImage resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10, 0, 5)];
    
    [self.videoSlider setMinimumTrackImage:sliderLeftTrackImage forState:UIControlStateNormal];
    [self.videoSlider setMaximumTrackImage:sliderRightTrackImage forState:UIControlStateNormal];
}

- (void)setVolumnController
{
    //The simulator won't show the volume slider.
    self.volumeControllerView.layer.cornerRadius = 6.0;
    
    MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:self.volumeControllerView.bounds];
    
    UIImage *blueSliderImgae = [UIImage imageNamed:@"blueline"];
    UIImage *graySliderImage = [UIImage imageNamed:@"grayline"];
    
    UIImage *sliderRightTrackImage = [graySliderImage resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
    UIImage *sliderLeftTrackImage = [blueSliderImgae resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
    
    [volumeView setMinimumVolumeSliderImage:sliderLeftTrackImage forState:UIControlStateNormal];
    [volumeView setMaximumVolumeSliderImage:sliderRightTrackImage forState:UIControlStateNormal];
    
    UIImage *thumbImage = [UIImage imageNamed:@"Gray"];
    [volumeView setVolumeThumbImage:thumbImage forState:UIControlStateNormal];
    [volumeView setVolumeThumbImage:thumbImage forState:UIControlStateHighlighted];
    
    [self.volumeControllerView addSubview:volumeView];
}

- (BOOL)isPlay
{
    return self.mRestoreAfterScrubbingRate != 0.f || [self.player rate] != 0.f;
}

#pragma mark - Vodio Asset

- (void)prepareVideoWithAsset
{
    if (self.fileURL != nil)
    {
        /*
         Create an asset for inspection of a resource referenced by a given URL.
         Load the values for the asset keys.
         */
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.fileURL options:nil];
        NSArray *requestedKeys = @[@"tracks",@"playable",@"duration"];
        
        /* Tells the asset to load the values of any of the specified keys that are not already loaded. */
        [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
         ^{
             dispatch_async(dispatch_get_main_queue(), ^{
                 /*IMPORTANT:Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem.*/
                 [self prepareToPlayAsset:asset withKeys:requestedKeys];
             });
         }];
    }

}

- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    /* Make sure that the value of each key has loaded successfully. */
    for (NSString *thisKey in requestedKeys)
    {
        NSError *error = nil;
        AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
        if (keyStatus == AVKeyValueStatusFailed)
        {
            [self failedToPrepareForPlayback:error];
            return;
        }
        /* If you are also implementing -[AVAsset cancelLoading], add your code here to bail out properly in the case of cancellation. */
    }
    
    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (!asset.playable)
    {
        [self ItemErrorHandle];
        return;
    }
    
    /* At this point we're ready to set up for playback of the asset. */
    
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.playerItem)
    {
        [self removePlayerItemObserver];
    }
    [self createPlayItemWithAsset:asset];
    
    
    /* Create new player, if we don't already have one. */
    if (!self.player)
    {
        [self createPlayer];
    }
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.playerItem)
    {
        [self makeCurrentItem];
    }
    
    [self.videoSlider setValue:0.0];
}


- (void)ItemErrorHandle
{
    /* Generate an error describing the failure. */
    NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
    NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
    NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
                               localizedDescription, NSLocalizedDescriptionKey,
                               localizedFailureReason, NSLocalizedFailureReasonErrorKey,
                               nil];
    NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];
    
    /* Display the error to the user. */
    [self failedToPrepareForPlayback:assetCannotBePlayedError];

}

- (void)createPlayItemWithAsset:(AVURLAsset *)asset
{
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.playerItem addObserver:self
                      forKeyPath:@"status"
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoStatusObservationContext];
    
    //Observe the AVPlayer.currectItem "LoadedTimeRanges" property to loading video time
    [self.playerItem addObserver:self
                      forKeyPath:@"loadedTimeRanges"
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoLoadedTimeRanges];
    
    /* When the player item has played to its end time we'll toggle the movie controller Pause button to be the Play button */
    //The video have been ending. Use notification.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayDidEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];

}

#pragma mark - setplayer with URL

- (void)prepareVideoWithURL
{
    if (self.fileURL != nil) {
        [self prepareToURL:self.fileURL];
    }
}

//prepare video with url
- (void)prepareToURL:(NSURL *)videoURL
{
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.playerItem)
    {
        [self removePlayerItemObserver];
    }
    
    [self createPlayItemWithURL:videoURL];
    
    
    /* Create new player, if we don't already have one. */
    if (!self.player)
    {
        [self createPlayer];
    }
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.playerItem)
    {
        [self makeCurrentItem];
    }
    
    [self.videoSlider setValue:0.0];
}


//createPlayItemWithUrl
- (void)createPlayItemWithURL:(NSURL*)videoURL
{
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.playerItem = [AVPlayerItem playerItemWithURL:videoURL];
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.playerItem addObserver:self
                      forKeyPath:@"status"
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoStatusObservationContext];
    
    //Observe the AVPlayer.currectItem "LoadedTimeRanges" property to loading video time
    [self.playerItem addObserver:self
                      forKeyPath:@"loadedTimeRanges"
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoLoadedTimeRanges];
    
    /* When the player item has played to its end time we'll toggle the movie controller Pause button to be the Play button */
    //The video have been ending. Use notification.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayDidEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.playerItem];
    
}



#pragma mark -  Error

-(void)failedToPrepareForPlayback:(NSError *)error
{
    //before the video play
    
    [self removePlayerTimeObserver];
    [self syncScrubber];
    [self disableScrubber];
    
    self.controlButton.enabled = NO;
    
    /* Display the error. */
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                        message:[error localizedFailureReason]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}


#pragma mark - Player and PlayerItem

- (void)removePlayerItemObserver
{
    /* Remove existing player item key value observers and notifications. */
    [self.playerItem removeObserver:self forKeyPath:@"status"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:self.playerItem];
    
}

- (void)createPlayer
{
    /* Get a new AVPlayer initialized to play the specified player item. */
    [self setPlayer:[AVPlayer playerWithPlayerItem:self.playerItem]];
    
    /* Observe the AVPlayer "currentItem" property to find out when any
     AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did
     occur.*/
    [self.player addObserver:self
                  forKeyPath:@"currentItem"
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:AVPlayerDemoCurrentItemObservationContext];
    
    /* Observe the AVPlayer "rate" property to update the scrubber control. */
    [self.player addObserver:self
                  forKeyPath:@"rate"
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:AVPlayerDemoRateObservationContext];
    
}

- (void)makeCurrentItem
{
    /* Replace the player item with a new player item. The item replacement occurs
     asynchronously; observe the currentItem property to find out when the
     replacement will/did occur
     
     If needed, configure player item here (example: adding outputs, setting text style rules,
     selecting media options) before associating it with a player
     */
    
    [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
    
    self.controlButton.enabled = YES;
}



#pragma mark - Key Value Observing method

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    /* AVPlayerItem "status" property value observer. */
    if (context == AVPlayerDemoStatusObservationContext)
    {
        [self showLoadingHUDWithText:@"Loading..."];
        
        NSLog(@"Status");
        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
            // Indicates that the status of the player is not yet known because it has not tried to load new media resources for playback.
            case AVPlayerItemStatusUnknown:
            {
                [self removePlayerTimeObserver];
                [self syncScrubber];
                
                [self disableScrubber];
                self.controlButton.enabled = NO;
            }
                break;
                
            case AVPlayerItemStatusReadyToPlay:
            {
                [self AVPlayerItemStatusReadyToPlayAction];
            }
                break;
                
            case AVPlayerItemStatusFailed:
            {
                AVPlayerItem *playerItem = (AVPlayerItem *)object;
                [self failedToPrepareForPlayback:playerItem.error];
            }
                break;
        }
    }
    /* AVPlayer "rate" property value observer. */
    else if (context == AVPlayerDemoRateObservationContext)
    {
        NSLog(@"Rate %f",self.player.rate);
        [self convertControlState];
    }
    /* AVPlayer "currentItem" property observer. Called when the AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did occur. */
    else if (context == AVPlayerDemoCurrentItemObservationContext)
    {
        NSLog(@"CurrentItem");
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        /* Is the new player item null? */
        if (newPlayerItem == (id)[NSNull null])
        {
            [self disableScrubber];
        }
        else /* Replacement of player currentItem has occurred */
        {
            /* Set the AVPlayer for which the player layer displays visual output. */
            [self.playerView setPlayer:self.player];
            
        }
    }
    else if(context == AVPlayerDemoLoadedTimeRanges)
    {
        NSLog(@"LoadedTimeRanges");
        id object = change[NSKeyValueChangeNewKey];
        
        if (![object isEqual:[NSNull null]]) {
            NSArray *timeRanges = object;
            
            if ([timeRanges count]) {
                CMTimeRange timerange = [timeRanges[0] CMTimeRangeValue];
                float time = CMTimeGetSeconds(timerange.duration);
                float percentage = (time/10.0) * 100;
                
                if (percentage < 100) {
                    self.LoadingHUD.labelText = [NSString stringWithFormat:@"%.0f%%", percentage];
                }
            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }

}

- (void)AVPlayerItemStatusReadyToPlayAction
{
    /* Once the AVPlayerItem becomes ready to play, i.e.
     [playerItem status] == AVPlayerItemStatusReadyToPlay,
     its duration can be fetched from the item. */
    
    self.controlButton.enabled = YES;
    
    //calculate totoal Second.
    CGFloat totalSecond = self.playerItem.duration.value / self.playerItem.duration.timescale;
    self.videoTotalTime.text = [self converTime:totalSecond];
    
    [self enableScrubber];
    
    if (!self.mTimeObserver) {
        [self initScrubberTimer];
    }
    
    [self.LoadingHUD hide:YES];
    [self convertPlayerState];
}

#pragma mark - control Button
    
- (IBAction)controlButtonPressed:(id)sender
{
    NSLog(@"controlButtonPressed");
    [self convertControlState];
    [self convertPlayerState];
}

- (void)convertControlState
{
    if (self.isPlay) {
        [self.controlButton setTitle:@"Stop" forState:UIControlStateNormal];
    } else {
        [self.controlButton setTitle:@"Play" forState:UIControlStateNormal];
    }
}

- (void)convertPlayerState
{
    if (self.isPlay) {
        [self.player pause];
    } else {
        [self.player play];
    }
}

#pragma mark - videoSlider
- (void)updateVideoSlider:(CGFloat)currentSecond
{
    [self.videoSlider setValue:currentSecond animated:YES];
}

#pragma mark - time convert method
- (NSString *)converTime:(CGFloat)second
{
    int seconds = (int)second % 60;
    int minute = (int)second / 60 % 60;
    int hour = (int)second / 3600;
    
    NSString *coverTime = [NSString stringWithFormat:@"%02d:%02d:%02d",hour,minute,seconds];
    return coverTime;
}


- (void)setCurrentTimeLabel:(CGFloat)second
{
    NSString *CurrentTime = [self converTime:second];
    
    self.videoCurrtentTime.text = CurrentTime;
}


#pragma mark - Notification

- (void)moviePlayDidEnd:(NSNotification *)notification
{
    NSLog(@"Play end");
    
    [self.player seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        [self updateVideoSlider:0.0];
        [self convertControlState];
        
    }];
}

#pragma mark - Timer Observer

/* ---------------------------------------------------------
 **  Methods to handle manipulation of the movie scrubber control
 ** ------------------------------------------------------- */

/* Requests invocation of a given block during media playback to update the movie scrubber control. */
-(void)initScrubberTimer
{
    double interval = 1.0f;
    
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration))
    {
        return;
    }
    
    /* Update the scrubber during normal playback. */
    __weak typeof(self) weakSelf = self;
    self.mTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC)
                                                               queue:NULL /* If you pass NULL, the main queue is used. */
                                                          usingBlock:^(CMTime time)
                     {
                         [weakSelf syncScrubber];
                     }];
}

/* Set the scrubber based on the player current time. */
- (void)syncScrubber
{
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration))
    {
        self.videoSlider.minimumValue = 0.0;
        return;
    }
    
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration))
    {
        double time = CMTimeGetSeconds([self.player currentTime]);
        
        [self.videoSlider setValue:(time / duration)];

        [self setCurrentTimeLabel:time];
        
        if(self.isPlayControlShow)
        {
            self.hidePlayMenuCountdown--;
            if (self.hidePlayMenuCountdown == 0) {
                [self hidePlayMenu];
            }
        }
    }
}

/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
    if (self.mTimeObserver)
    {
        [self.player removeTimeObserver:self.mTimeObserver];
        self.mTimeObserver = nil;
    }
}

#pragma mark - Scrubber control

/* The user is dragging the movie controller thumb to scrub through the movie. */
- (IBAction)beginScrubbing:(id)sender
{
    self.mRestoreAfterScrubbingRate = [self.player rate];
    [self.player setRate:0.f];
    
    /* Remove previous timer. */
    [self removePlayerTimeObserver];
}

/* Set the player current time to match the scrubber position. */
- (IBAction)scrub:(id)sender
{
    CMTime playerDuration = [self playerItemDuration];
    
    if (CMTIME_IS_INVALID(playerDuration)) {
        self.videoSlider.minimumValue = 0.0;
        return;
    }
    
    if ([sender isKindOfClass:[UISlider class]])
    {
        UISlider *slider = sender;
        
        double duration = CMTimeGetSeconds(playerDuration);
        float value = [slider value];
        
        double time = value *duration;
        
        [self setCurrentTimeLabel:time];
    }
    
}

/* The user has released the movie thumb control to stop scrubbing through the movie. */
- (IBAction)endScrubbing:(id)sender
{
    if ([sender isKindOfClass:[UISlider class]])
    {
        UISlider* slider = sender;
        
        [self showLoadingHUDWithText:@"Loading..."];
        
        CMTime playerDuration = [self playerItemDuration];
        if (CMTIME_IS_INVALID(playerDuration)) {
            return;
        }
        
        double duration = CMTimeGetSeconds(playerDuration);
        if (isfinite(duration))
        {
            float minValue = [slider minimumValue];
            float maxValue = [slider maximumValue];
            float value = [slider value];
        
            double time = duration * (value - minValue) / (maxValue - minValue);
            [self setCurrentTimeLabel:time];
            
            [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self endScrubbingAction];
                });
            }];
        }
    }

}

- (void)endScrubbingAction
{
    if (!self.mTimeObserver)
    {
        [self initScrubberTimer];
    }
    
    if (self.mRestoreAfterScrubbingRate)
    {
        [self.player setRate:self.mRestoreAfterScrubbingRate];
        self.mRestoreAfterScrubbingRate = 0.f;
    }

    [self.LoadingHUD hide:YES];
}

- (BOOL)isScrubbing
{
    return self.mRestoreAfterScrubbingRate != 0.f;
}

-(void)enableScrubber
{
    self.videoSlider.enabled = YES;
}

-(void)disableScrubber
{
    self.videoSlider.enabled = NO;
}

//Get the duration for a AVPlayerItem.
- (CMTime)playerItemDuration
{
    AVPlayerItem *playerItem = [self.player currentItem];
    if (playerItem.status == AVPlayerItemStatusReadyToPlay)
    {
        return([playerItem duration]);
    }
    
    return(kCMTimeInvalid);
}

#pragma mark - MBProcessHUD 

- (void)showLoadingHUDWithText:(NSString *)labeltext
{
    self.LoadingHUD.labelText = labeltext;
    [self.LoadingHUD show:YES];
}

#pragma mark - PlayMenu Animation

- (void)showPlayMenu
{
    self.isPlayControlShow = YES;
    
    [UIView animateWithDuration:0.5 animations:^{
        self.playControlView.transform = CGAffineTransformIdentity;
        self.volumeControllerView.transform = CGAffineTransformIdentity;
    }];
}

- (void)hidePlayMenu
{
    CGFloat BottomDistance = SCREENHEIGHT - self.volumeControllerView.frame.origin.y;
    
    self.isPlayControlShow = NO;
    self.hidePlayMenuCountdown = 5;
    
    [UIView animateWithDuration:0.5 animations:^{
        self.playControlView.transform = CGAffineTransformTranslate(self.playControlView.transform, 0, -(CGRectGetHeight(self.playControlView.frame) + 20));
        self.volumeControllerView.transform = CGAffineTransformTranslate(self.volumeControllerView.transform, 0, BottomDistance);
    }];
}

#pragma mark - PlayViewDelegate

- (void)playViewTapGestureHandler:(PlayerView *)playView
{
    if (!self.mTimeObserver) {
        [self initScrubberTimer];
    }
    
    if (self.isPlayControlShow) {
        [self hidePlayMenu];
    } else {
        [self showPlayMenu];
    }
}

@end
