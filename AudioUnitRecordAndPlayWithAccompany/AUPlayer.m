//
//  AUPlayer.m
//  AudioUnitRecordAndPlay
//
//  Created by 刘文晨 on 2024/6/28.
//

#import "AUPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

#define INPUT_BUS 1
#define OUTPUT_BUS 0
#define CONST_BUFFER_SIZE 2048 * 2 * 10

@implementation AUPlayer
{
    AudioUnit audioUnit;
    AudioBufferList *audioBufferList;
        
    NSInputStream *inputSteam;
    Byte *buffer;
}

- (void)start
{
    [self initAudioInit];
    AudioOutputUnitStart(audioUnit);
}

- (void)initAudioInit
{
    // open accompany file
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"accompany" withExtension:@"pcm"];
    inputSteam = [NSInputStream inputStreamWithURL:url];
    if (inputSteam == nil)
    {
        NSLog(@"failed to open accompany file: %@", url);
        return;
    }
    [inputSteam open];
    
    NSError *audioSessionError = nil;
    // set audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&audioSessionError];
    [audioSession setActive:YES error:&audioSessionError];
    if (audioSessionError)
    {
        NSLog(@"failed to set session category: %@", audioSessionError);
        return;
    }
    // 设置音频硬件 I/O 缓冲区持续时间
    [audioSession setPreferredIOBufferDuration:0.05 error:&audioSessionError];
    if (audioSessionError)
    {
        NSLog(@"failed to set preferred IOBuffer duration: %@", audioSessionError);
        return;
    }
    
    // buffer list
    uint32_t numberBuffers = 1;
    audioBufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + (numberBuffers - 1) * sizeof(AudioBuffer));
    audioBufferList->mNumberBuffers = numberBuffers;
    for (int i = 0; i < numberBuffers; i++)
    {
        audioBufferList->mBuffers[i].mNumberChannels = 1;
        audioBufferList->mBuffers[i].mDataByteSize = CONST_BUFFER_SIZE;
        audioBufferList->mBuffers[i].mData = malloc(CONST_BUFFER_SIZE);
    }
    buffer = malloc(CONST_BUFFER_SIZE);
    
    // create an audio component description to identify an audio unit
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    OSStatus status = noErr;
    // obtain an audio unit instance using the audio unit API
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    if (status != noErr)
    {
        NSLog(@"failed to create audio unit: %d", status);
        return;
    }

    // enable input & output
    UInt32 flag = 1;
    if (flag)
    {
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      INPUT_BUS,
                                      &flag,
                                      sizeof(flag));
    }
    if (status != noErr)
    {
        NSLog(@"Audio Unit enable input error with status: %d", status);
        return;
    }
    
    flag = 1;
    if (flag)
    {
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
    }
    if (status != noErr)
    {
        NSLog(@"Audio Unit enable output error with status: %d", status);
        return;
    }
    
    // input format
    AudioStreamBasicDescription inputFormat = {0};
    inputFormat.mSampleRate = 44100.0; // 采样率
    inputFormat.mFormatID = kAudioFormatLinearPCM; // PCM 格式
    inputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved; // 整形、非交错
    inputFormat.mFramesPerPacket = 1; // 每帧只有 1 个 packet
    inputFormat.mChannelsPerFrame = 1; // 声道数
    inputFormat.mBytesPerFrame = 2; // 每帧只有 2 个 byte，声道*位深*Packet
    inputFormat.mBytesPerPacket = 2; // 每个 Packet 只有 2 个 byte
    inputFormat.mBitsPerChannel = 16; // 位深
    [self printAudioStreamBasicDescription:inputFormat];
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  INPUT_BUS,
                                  &inputFormat,
                                  sizeof(inputFormat));
    if (status != noErr)
    {
        NSLog(@"Audio Unit set input property eror with status: %d", status);
        return;
    }
    
    // output format
    AudioStreamBasicDescription outputFormat = inputFormat;
    [self printAudioStreamBasicDescription:outputFormat];
    
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status != noErr)
    {
        NSLog(@"Audio Unit set output property eror with status: %d", status);
        return;
    }
    
    // set callback
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(audioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Output,
                         INPUT_BUS,
                         &recordCallback,
                         sizeof(recordCallback));
    if (status != noErr)
    {
        NSLog(@"Audio Unit set callback eror with status: %d", status);
        return;
    }
    
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(audioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         OUTPUT_BUS,
                         &playCallback,
                         sizeof(playCallback));
    if (status != noErr)
    {
        NSLog(@"Audio Unit set callback eror with status: %d", status);
        return;
    }
    
    OSStatus result = AudioUnitInitialize(audioUnit);
    NSLog(@"result: %d", result);
}

#pragma mark - Callback

OSStatus RecordCallback(void *inRefCon,
                      AudioUnitRenderActionFlags *ioActionFlags,
                      const AudioTimeStamp *inTimeStamp,
                      UInt32 inBusNumber,
                      UInt32 inNumberFrames,
                      AudioBufferList *ioData)
{
    AUPlayer *player = (__bridge AUPlayer *)inRefCon;
    
    player->audioBufferList->mNumberBuffers = 1;
    
    OSStatus status = AudioUnitRender(player->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, player->audioBufferList);
    if (status != noErr)
    {
        NSLog(@"Audio Unit render error: %d", status);
        return status;
    }
    NSLog(@"input buffer size: %d", player->audioBufferList->mBuffers[0].mDataByteSize);
    
    [player writePCMData:player->audioBufferList->mBuffers[0].mData size:player->audioBufferList->mBuffers[0].mDataByteSize];
    
    return noErr;
}

OSStatus PlayCallback(void *inRefCon,
                      AudioUnitRenderActionFlags *ioActionFlags,
                      const AudioTimeStamp *inTimeStamp,
                      UInt32 inBusNumber,
                      UInt32 inNumberFrames,
                      AudioBufferList *ioData)
{
    AUPlayer *player = (__bridge AUPlayer *)inRefCon;
    memcpy(ioData->mBuffers[0].mData, player->audioBufferList->mBuffers[0].mData, player->audioBufferList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = player->audioBufferList->mBuffers[0].mDataByteSize;
    NSLog(@"output left channel buffer size: %d", ioData->mBuffers[0].mDataByteSize);
    
    if (ioData->mBuffers[0].mDataByteSize <= 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
        });
    }
    
    return noErr;
}

//OSStatus PlayCallback(void *inRefCon,
//                      AudioUnitRenderActionFlags *ioActionFlags,
//                      const AudioTimeStamp *inTimeStamp,
//                      UInt32 inBusNumber,
//                      UInt32 inNumberFrames,
//                      AudioBufferList *ioData)
//{
//    AUPlayer *player = (__bridge AUPlayer *)inRefCon;
//    ioData->mNumberBuffers = 2;
//    for (int i = 0; i < ioData->mNumberBuffers; i++)
//    {
//        ioData->mBuffers[i].mNumberChannels = 1;
//        ioData->mBuffers[i].mDataByteSize = 4096;
//        ioData->mBuffers[i].mData = malloc(4096);
//    }
//    //  人声位于左声道
////    ioData->mBuffers[0].mNumberChannels = 1;
//    memcpy(ioData->mBuffers[0].mData, player->audioBufferList->mBuffers[0].mData, player->audioBufferList->mBuffers[0].mDataByteSize);
//    ioData->mBuffers[0].mDataByteSize = player->audioBufferList->mBuffers[0].mDataByteSize;
//    // 伴奏位于右声道
////    ioData->mBuffers[1].mNumberChannels = 1;
////    ioData->mBuffers[1].mDataByteSize = ioData->mBuffers[0].mDataByteSize;
////    ioData->mBuffers[1].mData = malloc(ioData->mBuffers[1].mDataByteSize);
//    ioData->mBuffers[1].mDataByteSize = (UInt32)[player->inputSteam read:ioData->mBuffers[1].mData maxLength:ioData->mBuffers[1].mDataByteSize];
////    NSInteger bytes = CONST_BUFFER_SIZE < ioData->mBuffers[1].mDataByteSize * 2 ? CONST_BUFFER_SIZE : ioData->mBuffers[1].mDataByteSize * 2;
////    bytes = [player->inputSteam read:player->buffer maxLength:bytes];
////
////    for (int i = 0; i < bytes; i++)
////    {
////        ((Byte*)ioData->mBuffers[1].mData)[i / 2] = player->buffer[i];
////    }
////    ioData->mBuffers[1].mDataByteSize = (UInt32)bytes / 2;
//    
//    if (ioData->mBuffers[1].mDataByteSize < ioData->mBuffers[0].mDataByteSize)
//    {
//        ioData->mBuffers[0].mDataByteSize = ioData->mBuffers[1].mDataByteSize;
//    }
//    NSLog(@"output left channel buffer size: %d", ioData->mBuffers[0].mDataByteSize);
//    NSLog(@"output right channel buffer size: %d", ioData->mBuffers[1].mDataByteSize);
//    
//    if (ioData->mBuffers[1].mDataByteSize <= 0)
//    {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [player stop];
//        });
//    }
//    
//    return noErr;
//}

- (void)stop
{
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    
    if (audioBufferList != nil)
    {
        if (audioBufferList->mBuffers[0].mData)
        {
            free(audioBufferList->mBuffers[0].mData);
            audioBufferList->mBuffers[0].mData = nil;
        }
        free(audioBufferList);
        audioBufferList = nil;
    }
    
    [inputSteam close];
    buffer = nil;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(onPlayToEnd:)])
    {
        __strong typeof(AUPlayer) *player = self;
        [self.delegate onPlayToEnd:player];
    }

    AudioComponentInstanceDispose(audioUnit);
}

- (void)writePCMData:(Byte *)buffer size:(int)size
{
    static FILE *fp = NULL;
    // NSString *path = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/record.pcm"];
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/record.pcm"];
    if (fp == nil)
    {
        fp = fopen(path.UTF8String, "w");
    }
    fwrite(buffer, size, 1, fp);
}

- (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd
{
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy(&formatID, formatIDString, 4);
    formatIDString[4] = '\0';

    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10X",    asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10d",    asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10d",    asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10d",    asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10d",    asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10d",    asbd.mBitsPerChannel);
    
    printf("\n");
}

//- (void)dealloc
//{
//    AudioOutputUnitStop(audioUnit);
//    AudioUnitUninitialize(audioUnit);
//    
//    if (audioBufferList != nil)
//    {
//        free(audioBufferList);
//        audioBufferList = nil;
//    }
//    
//    AudioComponentInstanceDispose(audioUnit);
//}

@end
