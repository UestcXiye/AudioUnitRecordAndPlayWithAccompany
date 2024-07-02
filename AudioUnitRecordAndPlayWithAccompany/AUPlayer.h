//
//  AUPlayer.h
//  AudioUnitRecordAndPlay
//
//  Created by 刘文晨 on 2024/6/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AUPlayer;

@protocol AUPlayerDelegate <NSObject>

- (void)onPlayToEnd:(AUPlayer *)player;

@end

@interface AUPlayer : NSObject

@property (nonatomic, weak) id<AUPlayerDelegate> delegate;

- (void)start; // 开始录音
- (void)stop; // 结束录音

@end

NS_ASSUME_NONNULL_END
