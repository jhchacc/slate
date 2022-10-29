//
//  SlateConfig.h
//  Slate
//
//  Created by Jigish Patel on 5/18/11.
//  Copyright 2011 Jigish Patel. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see http://www.gnu.org/licenses

#import <Foundation/Foundation.h>

@class Binding;

@interface SlateConfig : NSObject {
@private
  NSMutableDictionary *configs;
  NSMutableDictionary *configDefaults;
  NSMutableArray *bindings;
  NSMutableDictionary *modalBindings;
  NSMutableDictionary *aliases;
}
@property NSMutableDictionary *configs;
@property NSMutableDictionary *configDefaults;
@property NSMutableDictionary *appConfigs; // two layer map
@property NSMutableArray *bindings;
@property NSMutableDictionary *modalBindings;
@property NSMutableDictionary *aliases;

+ (SlateConfig *)getInstance;
+ (NSAlert *)warningAlertWithKeyEquivalents:(NSArray *)titles;
- (BOOL)load;
- (BOOL)loadConfigFileWithPath:(NSString *)file;
- (void)addBinding:(Binding *)bind;
- (BOOL)append:(NSString *)configString;
- (BOOL)getBoolConfig:(NSString *)key;
- (void)setConfig:(NSString *)key to:(NSString *)value;
- (NSInteger)getIntegerConfig:(NSString *)key;
- (double)getDoubleConfig:(NSString *)key;
- (float)getFloatConfig:(NSString *)key;
- (NSString *)getConfig:(NSString *)key;
- (NSString *)getConfigDefault:(NSString *)key;
- (NSString *)getConfig:(NSString *)key app:(NSString *)app;
- (NSArray *)getArrayConfig:(NSString *)key;
- (void)addAlias:(NSString *)line;
- (NSString *)replaceAliases:(NSString *)line;
- (void)onScreenChange:(id)notification;
- (void)setupDefaultConfigs;
- (NSString *)stripComments:(NSString *)line;
//- (void)processNotification:(id)notification;

@end

void onDisplayReconfiguration (CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo);
