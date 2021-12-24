//
//  TZVideoPlayerController.m
//  TZImagePickerController
//
//  Created by 谭真 on 16/1/5.
//  Copyright © 2016年 谭真. All rights reserved.
//

#import "TZVideoPlayerController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "UIView+TZLayout.h"
#import "TZImageManager.h"
#import "TZAssetModel.h"
#import "TZImagePickerController.h"
#import "TZPhotoPreviewController.h"
#import "TZVideoCropController.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface TZVideoPlayerController () {
    AVPlayer *_player;
    AVPlayerLayer *_playerLayer;
    UIButton *_playButton;
    UIImage *_cover;
    NSString *_outputPath;
    NSString *_errorMsg;
    
    UIView *_toolBar;
    UIButton *_doneButton;
    UIButton *_editButton;
    UIProgressView *_progress;
    
    UIButton *_backButton;
    
    UIStatusBarStyle _originStatusBarStyle;
}
@property (assign, nonatomic) BOOL needShowStatusBar;

// iCloud无法同步提示UI
@property (nonatomic, strong) UIView *iCloudErrorView;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation TZVideoPlayerController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.needShowStatusBar = ![UIApplication sharedApplication].statusBarHidden;
    self.view.backgroundColor = [UIColor blackColor];
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (tzImagePickerVc) {
        self.navigationItem.title = tzImagePickerVc.previewBtnTitleStr;
    }
    self.edgesForExtendedLayout = UIRectEdgeAll;
    [self configMoviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pausePlayerAndShowNaviBar) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _originStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.needShowStatusBar) {
        [UIApplication sharedApplication].statusBarHidden = NO;
    }
    [UIApplication sharedApplication].statusBarStyle = _originStatusBarStyle;
}

- (void)configMoviePlayer {
    [[TZImageManager manager] getPhotoWithAsset:_model.asset completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
        BOOL iCloudSyncFailed = !photo && [TZCommonTools isICloudSyncError:info[PHImageErrorKey]];
        self.iCloudErrorView.hidden = !iCloudSyncFailed;
        if (!isDegraded && photo) {
            self->_cover = photo;
            self->_doneButton.enabled = YES;
            self->_editButton.enabled = YES;
        }
    }];
    [[TZImageManager manager] getVideoWithAsset:_model.asset completion:^(AVPlayerItem *playerItem, NSDictionary *info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_player = [AVPlayer playerWithPlayerItem:playerItem];
            self->_playerLayer = [AVPlayerLayer playerLayerWithPlayer:self->_player];
            self->_playerLayer.videoGravity = AVLayerVideoGravityResizeAspect; //视频拉伸方式
            self->_playerLayer.frame = self.view.bounds;
            [self.view.layer addSublayer:self->_playerLayer];
            [self addProgressObserver];
            [self configPlayButton];
            [self configBackButton];
            [self configBottomToolBar];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pausePlayerAndShowNaviBar) name:AVPlayerItemDidPlayToEndTimeNotification object:self->_player.currentItem];
        });
    }];
}

- (void)configBackButton {
    _backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _backButton.frame = CGRectMake(20, 40, 30, 30);
    [_backButton setImage:[UIImage imageNamed:@"icon_backButton"] forState:UIControlStateNormal];
    [_backButton addTarget:self action:@selector(backButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_backButton];
}

- (void)backButtonClick {
    [self.navigationController popViewControllerAnimated:YES];
    [self.navigationController setNavigationBarHidden:NO];
}

/// Show progress，do it next time / 给播放器添加进度更新,下次加上
- (void)addProgressObserver{
    AVPlayerItem *playerItem = _player.currentItem;
    UIProgressView *progress = _progress;
    [_player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        float current = CMTimeGetSeconds(time);
        float total = CMTimeGetSeconds([playerItem duration]);
        if (current) {
            [progress setProgress:(current/total) animated:YES];
        }
    }];
}

- (void)configPlayButton {
    _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_playButton setImage:[UIImage tz_imageNamedFromMyBundle:@"MMVideoPreviewPlay"] forState:UIControlStateNormal];
    [_playButton setImage:[UIImage tz_imageNamedFromMyBundle:@"MMVideoPreviewPlayHL"] forState:UIControlStateHighlighted];
    [_playButton addTarget:self action:@selector(playButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_playButton];
}

- (void)configBottomToolBar {
    _toolBar = [[UIView alloc] initWithFrame:CGRectZero];
//    CGFloat rgb = 34 / 255.0;
//    _toolBar.backgroundColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:0.7];
    
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.titleLabel.font = [UIFont systemFontOfSize:16];
    if (!_cover) {
        _doneButton.enabled = NO;
    }
    [_doneButton addTarget:self action:@selector(doneButtonClick) forControlEvents:UIControlEventTouchUpInside];
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (tzImagePickerVc) {
//        [_doneButton setTitle:tzImagePickerVc.doneBtnTitleStr forState:UIControlStateNormal];
//        [_doneButton setTitleColor:tzImagePickerVc.oKButtonTitleColorNormal forState:UIControlStateNormal];
        [_doneButton setTitle:@"完成" forState:UIControlStateNormal];
        [_doneButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        [_doneButton setTitle:[NSBundle tz_localizedStringForKey:@"Done"] forState:UIControlStateNormal];
//        [_doneButton setTitleColor:[UIColor colorWithRed:(83/255.0) green:(179/255.0) blue:(17/255.0) alpha:1.0] forState:UIControlStateNormal];
        [_doneButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    _doneButton.backgroundColor = [UIColor colorWithRed:77/255.0 green:129/255.0 blue:239/255.0 alpha:1.0];
    _doneButton.layer.cornerRadius = 4;
    [_doneButton setTitleColor:tzImagePickerVc.oKButtonTitleColorDisabled forState:UIControlStateDisabled];
    [_toolBar addSubview:_doneButton];
    [self.view addSubview:_toolBar];
    
    if (tzImagePickerVc && tzImagePickerVc.allowEditVideo && roundf(self.model.asset.duration) > 1) {
        _editButton = [UIButton buttonWithType:UIButtonTypeCustom];
//        _editButton.titleLabel.font = [UIFont systemFontOfSize:16];
        if (!_cover) {
            _editButton.enabled = NO;
        }
        [_editButton addTarget:self action:@selector(editButtonClick) forControlEvents:UIControlEventTouchUpInside];
//        [_editButton setTitle:tzImagePickerVc.editBtnTitleStr forState:UIControlStateNormal];
//        [_editButton setTitleColor:tzImagePickerVc.oKButtonTitleColorNormal forState:UIControlStateNormal];
//        [_editButton setTitleColor:tzImagePickerVc.oKButtonTitleColorDisabled forState:UIControlStateDisabled];
        [_editButton setImage:[UIImage imageNamed:@"icon_cropButton"] forState:UIControlStateNormal];
        [_toolBar addSubview:_editButton];
    }
    
    if (tzImagePickerVc.videoPreviewPageUIConfigBlock) {
        tzImagePickerVc.videoPreviewPageUIConfigBlock(_playButton, _toolBar, _editButton, _doneButton);
    }
    
    //进入界面直接播放视频
    CMTime currentTime = _player.currentItem.currentTime;
    CMTime durationTime = _player.currentItem.duration;
    if (_player.rate == 0.0f) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TZ_VIDEO_PLAY_NOTIFICATION" object:_player];
        if (currentTime.value == durationTime.value) [_player.currentItem seekToTime:CMTimeMake(0, 1)];
        [_player play];
        [self.navigationController setNavigationBarHidden:YES];
//        _toolBar.hidden = YES;
        [_playButton setImage:nil forState:UIControlStateNormal];
        [UIApplication sharedApplication].statusBarHidden = YES;
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    TZImagePickerController *tzImagePicker = (TZImagePickerController *)self.navigationController;
    if (tzImagePicker && [tzImagePicker isKindOfClass:[TZImagePickerController class]]) {
        return tzImagePicker.statusBarStyle;
    }
    return [super preferredStatusBarStyle];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    
    BOOL isFullScreen = self.view.tz_height == [UIScreen mainScreen].bounds.size.height;
    CGFloat statusBarHeight = isFullScreen ? [TZCommonTools tz_statusBarHeight] : 0;
    CGFloat statusBarAndNaviBarHeight = statusBarHeight + self.navigationController.navigationBar.tz_height;
    _playerLayer.frame = self.view.bounds;

    CGFloat toolBarHeight = 44 + [TZCommonTools tz_safeAreaInsets].bottom;
    _toolBar.frame = CGRectMake(0, self.view.tz_height - toolBarHeight, self.view.tz_width, toolBarHeight);
//    [_doneButton sizeToFit];
//    _doneButton.frame = CGRectMake(self.view.tz_width - _doneButton.tz_width - 12, 0, MAX(44, _doneButton.tz_width), 44);
    _doneButton.frame = CGRectMake(self.view.tz_width - 60 - 12, 0, 60, 30);

    _playButton.frame = CGRectMake(0, statusBarAndNaviBarHeight, self.view.tz_width, self.view.tz_height - statusBarAndNaviBarHeight - toolBarHeight);
    if (tzImagePickerVc.allowEditVideo) {
        _editButton.frame = CGRectMake(12, 0, 24, 20);
//        [_editButton sizeToFit];
        _editButton.tz_height = 44;
    }
    if (tzImagePickerVc.videoPreviewPageDidLayoutSubviewsBlock) {
        tzImagePickerVc.videoPreviewPageDidLayoutSubviewsBlock(_playButton, _toolBar, _editButton, _doneButton);
    }
}

#pragma mark - Click Event

- (void)playButtonClick {
    CMTime currentTime = _player.currentItem.currentTime;
    CMTime durationTime = _player.currentItem.duration;
    if (_player.rate == 0.0f) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TZ_VIDEO_PLAY_NOTIFICATION" object:_player];
        if (currentTime.value == durationTime.value) [_player.currentItem seekToTime:CMTimeMake(0, 1)];
        [_player play];
        [self.navigationController setNavigationBarHidden:YES];
        [_playButton setImage:nil forState:UIControlStateNormal];
        [UIApplication sharedApplication].statusBarHidden = YES;
    } else {
        [self pausePlayerAndShowNaviBar];
    }
}

- (void)editButtonClick {
    
    [_player pause];
    [_playButton setImage:[UIImage tz_imageNamedFromMyBundle:@"MMVideoPreviewPlay"] forState:UIControlStateNormal];
    _playButton.hidden = NO;
    if (self.needShowStatusBar) {
        [UIApplication sharedApplication].statusBarHidden = NO;
    }
    
    TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
    TZVideoCropController *videoCropVc = [[TZVideoCropController alloc] init];
    videoCropVc.model = self.model;
    videoCropVc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    videoCropVc.modalPresentationStyle = UIModalPresentationFullScreen;
    videoCropVc.modalPresentationCapturesStatusBarAppearance = YES;
    videoCropVc.imagePickerVc = imagePickerVc;
    [self presentViewController:videoCropVc animated:YES completion:nil];
}

- (void)doneButtonClick {
    if ([[TZImageManager manager] isAssetCannotBeSelected:_model.asset]) {
        return;
    }
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
        if (imagePickerVc.allowEditVideo) {
            [imagePickerVc showProgressHUD];
            [[TZImageManager manager] getVideoOutputPathWithAsset:self->_model.asset presetName:imagePickerVc.presetName success:^(NSString *outputPath) {
                [imagePickerVc hideProgressHUD];
                self->_outputPath = outputPath;
                [self dismissAndCallDelegateMethod];
            } failure:^(NSString *errorMessage, NSError *error) {
                [imagePickerVc hideProgressHUD];
                self->_errorMsg = errorMessage;
                [self dismissAndCallDelegateMethod];
            }];
        } else {
            [self dismissAndCallDelegateMethod];
        }
    });
    
    /*
    // 判断选中的图片或者视频的大小
    [TZImageManager judgeAssetBigger:self.model isNeedSizeControl:YES result:^(BOOL isFail, NSString *errorMsg) {
        if(isFail){
            [SVProgressHUD showInfoWithStatus:errorMsg];
            return ;
        }else {
            dispatch_async(dispatch_get_main_queue(), ^{
                TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
                if (imagePickerVc.allowEditVideo) {
                    [imagePickerVc showProgressHUD];
                    [[TZImageManager manager] getVideoOutputPathWithAsset:self->_model.asset presetName:imagePickerVc.presetName success:^(NSString *outputPath) {
                        [imagePickerVc hideProgressHUD];
                        self->_outputPath = outputPath;
                        [self dismissAndCallDelegateMethod];
                    } failure:^(NSString *errorMessage, NSError *error) {
                        [imagePickerVc hideProgressHUD];
                        self->_errorMsg = errorMessage;
                        [self dismissAndCallDelegateMethod];
                    }];
                } else {
                    [self dismissAndCallDelegateMethod];
                }
            });
        }
    }];
    */
    
  
}

- (void)dismissAndCallDelegateMethod {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
        if (!imagePickerVc) {
            [self dismissViewControllerAnimated:YES completion:nil];
            return;
        }
        if (imagePickerVc.autoDismiss) {
            [imagePickerVc dismissViewControllerAnimated:YES completion:^{
                [self callDelegateMethod];
            }];
        } else {
            [self callDelegateMethod];
        }

    });
}

- (void)callDelegateMethod {
    TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
    if (imagePickerVc.allowEditVideo) {
        if (_outputPath) {
            if ([imagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishPickingAndEditingVideo:outputPath:error:)]) {
                [imagePickerVc.pickerDelegate imagePickerController:imagePickerVc didFinishPickingAndEditingVideo:self->_cover outputPath:self->_outputPath error:nil];
            }
            if (imagePickerVc.didFinishPickingAndEditingVideoHandle) {
                imagePickerVc.didFinishPickingAndEditingVideoHandle(self->_cover, self->_outputPath, nil);
            }
        } else {
            if ([imagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishPickingAndEditingVideo:outputPath:error:)]) {
                [imagePickerVc.pickerDelegate imagePickerController:imagePickerVc didFinishPickingAndEditingVideo:nil outputPath:nil error:self->_errorMsg];
            }
            if (imagePickerVc.didFinishPickingAndEditingVideoHandle) {
                imagePickerVc.didFinishPickingAndEditingVideoHandle(nil, nil, self->_errorMsg);
            }
        }
    } else {
        if ([imagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishPickingVideo:sourceAssets:)]) {
            [imagePickerVc.pickerDelegate imagePickerController:imagePickerVc didFinishPickingVideo:_cover sourceAssets:_model.asset];
        }
        if (imagePickerVc.didFinishPickingVideoHandle) {
            imagePickerVc.didFinishPickingVideoHandle(_cover,_model.asset);
        }
    }
}

#pragma mark - Notification Method

- (void)pausePlayerAndShowNaviBar {
    [_player pause];
    _toolBar.hidden = NO;
    [self.navigationController setNavigationBarHidden:NO];
    [_playButton setImage:[UIImage tz_imageNamedFromMyBundle:@"MMVideoPreviewPlay"] forState:UIControlStateNormal];
    [self.navigationController setNavigationBarHidden:YES];
    if (self.needShowStatusBar) {
        [UIApplication sharedApplication].statusBarHidden = NO;
    }
}

#pragma mark - lazy
- (UIView *)iCloudErrorView{
    if (!_iCloudErrorView) {
        _iCloudErrorView = [[UIView alloc] initWithFrame:CGRectMake(0, [TZCommonTools tz_statusBarHeight] + 44 + 10, self.view.tz_width, 28)];
        UIImageView *icloud = [[UIImageView alloc] init];
        icloud.image = [UIImage tz_imageNamedFromMyBundle:@"iCloudError"];
        icloud.frame = CGRectMake(20, 0, 28, 28);
        [_iCloudErrorView addSubview:icloud];
        UILabel *label = [[UILabel alloc] init];
        label.frame = CGRectMake(53, 0, self.view.tz_width - 63, 28);
        label.font = [UIFont systemFontOfSize:10];
        label.textColor = [UIColor whiteColor];
        label.text = [NSBundle tz_localizedStringForKey:@"iCloud sync failed"];
        [_iCloudErrorView addSubview:label];
        [self.view addSubview:_iCloudErrorView];
        _iCloudErrorView.hidden = YES;
    }
    return _iCloudErrorView;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma clang diagnostic pop

@end
