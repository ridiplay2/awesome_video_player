// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Flutter/Flutter.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "BetterPlayer.h"

@interface BetterPlayerPlugin : NSObject<FlutterPlugin, FlutterPlatformViewFactory>
@property(readonly, strong, nonatomic) NSObject<FlutterPluginRegistrar> *registrar;
@property(nonatomic, strong) NSObject<FlutterBinaryMessenger> *messenger;
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, BetterPlayer*> *players;
// Maps viewId -> textureId for platform view mode
@property(nonatomic, strong) NSMutableDictionary<NSNumber*, NSNumber*> *platformViewMapping;
@end
