//
//  ViewController.m
//  AudioUnitRecordAndPlayWithAccompany
//
//  Created by 刘文晨 on 2024/7/2.
//

#import "ViewController.h"
#import "AUPlayer.h"

@interface ViewController () <AUPlayerDelegate>

@end

@implementation ViewController
{
    AUPlayer *player;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = UIColor.whiteColor;
    
    self.label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
    self.label.textColor = [UIColor blackColor];
    self.label.text = @"使用 Audio Unit 录音、播放伴奏和耳返";
    self.label.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.recordButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    [self.recordButton setTitle:@"Start" forState:UIControlStateNormal];
    [self.recordButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.recordButton addTarget:self action:@selector(startRecord:) forControlEvents:UIControlEventTouchUpInside];
    self.recordButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.recordButton.hidden = NO;

    self.stopButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
    [self.stopButton setTitle:@"Stop" forState:UIControlStateNormal];
    [self.stopButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.stopButton addTarget:self action:@selector(stopRecord:) forControlEvents:UIControlEventTouchUpInside];
    self.stopButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.stopButton.hidden = YES;
    
    [self.view addSubview:self.label];
    [self.view addSubview:self.recordButton];
    [self.view addSubview:self.stopButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.label.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:95],
        [self.label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.recordButton.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.recordButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:75]
    ]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.stopButton.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.stopButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-75]
    ]];
}

- (void)startRecord:(UIButton *)sender
{
    sender.hidden = YES;
    self.stopButton.hidden = NO;
    
    player = [[AUPlayer alloc] init];
    // AUPlayer delegate
    player.delegate = self;
    [player start];
}

- (void)stopRecord:(UIButton *)sender
{
    sender.hidden = YES;
    self.recordButton.hidden = NO;
    
    [player stop];
    player = nil;
}

#pragma mark - AUPlayer Delegate Method

- (void)onPlayToEnd:(AUPlayer *)player
{
    [self recordButton];
    player = nil;
    self.recordButton.hidden = NO;
    self.stopButton.hidden = YES;
}

@end
