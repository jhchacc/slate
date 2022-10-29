//
//  SlateConfig.m
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

#import "Binding.h"
#import "Constants.h"
#import "ScreenState.h"
#import "ScreenWrapper.h"
#import "SlateConfig.h"
#import "StringTokenizer.h"
#import "SlateLogger.h"
#import "Operation.h"

@implementation SlateConfig

@synthesize configs;
@synthesize configDefaults;
@synthesize bindings;
@synthesize modalBindings;
@synthesize aliases;
@synthesize appConfigs;

static SlateConfig *_instance = nil;

+ (SlateConfig *)getInstance {
  @synchronized([SlateConfig class]) {
    if (!_instance) {
      [ScreenWrapper updateStatics];
      _instance = [[[SlateConfig class] alloc] init];
    }
    return _instance;
  }
}

- (id)init {
  self = [super init];
  if (self) {
    [self setupDefaultConfigs];
    [self setBindings:[NSMutableArray arrayWithCapacity:10]];
    [self setModalBindings:[NSMutableDictionary dictionary]];
    [self setAliases:[NSMutableDictionary dictionary]];
    
    // Listen for screen change notifications with Quartz
    CGDisplayRegisterReconfigurationCallback(onDisplayReconfiguration, (__bridge void *)(self));
    //[nc addObserver:self selector:@selector(processNotification:) name:nil object:nil];
  }
  return self;
}

- (BOOL)getBoolConfig:(NSString *)key {
  return [[self getConfig:key] boolValue];
}

- (NSInteger)getIntegerConfig:(NSString *)key {
  return [[self getConfig:key] integerValue];
}

- (double)getDoubleConfig:(NSString *)key {
  return [[self getConfig:key] doubleValue];
}

- (float)getFloatConfig:(NSString *)key {
  return [[self getConfig:key] floatValue];
}

- (NSArray *)getArrayConfig:(NSString *)key {
  return [[self getConfig:key] componentsSeparatedByString:SEMICOLON];
}

- (NSString *)getConfig:(NSString *)key {
  return [configs objectForKey:key];
}

- (void)setConfig:(NSString *)key to:(NSString *)value {
  [configs setObject:value forKey:key];
}

- (NSString *)getConfigDefault:(NSString *)key {
  return [configDefaults objectForKey:key];
}

- (NSString *)getConfig:(NSString *)key app:(NSString *)app {
  NSMutableDictionary *configsForApp = [appConfigs objectForKey:app];
  if (configsForApp == nil) return [self getConfigDefault:key];
  NSString *config = [configsForApp objectForKey:key];
  if (config == nil) return [self getConfigDefault:key];
  return config;
}

+ (NSAlert *)warningAlertWithKeyEquivalents:(NSArray *)titles {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setAlertStyle:NSWarningAlertStyle];
  for (NSString *title in titles) {
    [[alert addButtonWithTitle:title] setKeyEquivalent:[[title substringToIndex: 1] lowercaseString]];
  }
  return alert;
}

- (BOOL)load {
  SlateLogger(@"Loading config...");

  // Reset configs and bindings in case we are calling from menu
  [self setupDefaultConfigs];
  [self setBindings:[[NSMutableArray alloc] initWithCapacity:10]];
  [self setAliases:[[NSMutableDictionary alloc] init]];

  BOOL loadedDefault = [self loadConfigFileWithPath:@"~/.slate"];
  if (!loadedDefault) {
    SlateLogger(@"  ERROR Could not load ~/.slate");
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Continue", @"Quit", nil]];
    [alert setMessageText:@"Could not load ~/.slate"];
    [alert setInformativeText:@"The default configuration will be used. You can find the default .slate file at https://github.com/jigish/slate/blob/master/Slate/default.slate"];
    if ([alert runModal] == NSAlertSecondButtonReturn) {
      SlateLogger(@"User selected exit");
      [NSApp terminate:nil];
    }
    return [self loadConfigFileWithPath:[[NSBundle mainBundle] pathForResource:@"default" ofType:@"slate"]];
  }

  if ([[SlateConfig getInstance] getBoolConfig:CHECK_DEFAULTS_ON_LOAD]) {
    SlateLogger(@"Config loaded. Checking defaults...");
    [self checkDefaults];
    SlateLogger(@"Defaults loaded.");
  } else {
    SlateLogger(@"Config loaded.");
  }

  return YES;
}

- (BOOL)loadConfigFileWithPath:(NSString *)file {
  if (file == nil) return NO;
  NSString *configFile = file;
  if ([file rangeOfString:SLASH].location != 0 && [file rangeOfString:TILDA].location != 0)
    configFile = [NSString stringWithFormat:@"~/%@", file];
  NSError *err;
  NSString *fileString = [NSString stringWithContentsOfFile:[configFile stringByExpandingTildeInPath] encoding:NSUTF8StringEncoding error:&err];
  if (err == nil && fileString != nil && fileString != NULL) { return [self append:fileString]; }
  return NO;
}

- (NSString *)stripComments:(NSString *)line {
  if (line == nil || [line length] == 0) {
    return nil;
  }
  NSRange range = [line rangeOfString:[NSString stringWithCharacters:&COMMENT_CHARACTER length:1]];
  if ( range.length > 0 ) {
    line = [line substringToIndex:range.location];
  }
  line = [line stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:WHITESPACE]];
  return [line length] > 0 ? line : nil;
}

- (void)addBinding:(Binding *)bind {
  if ([bind modalKey] != nil) {
    NSMutableArray *theBindings = [modalBindings objectForKey:[bind modalHashKey]];
    if (theBindings == nil) theBindings = [NSMutableArray array];
    [theBindings addObject:bind];
    [modalBindings setObject:theBindings forKey:[bind modalHashKey]];
  } else {
    [bindings addObject:bind];
  }
}

- (BOOL)append:(NSString *)configString {
  if (configString == nil)
    return NO;
  NSArray *lines = [configString componentsSeparatedByString:@"\n"];

  NSEnumerator *e = [lines objectEnumerator];
  NSString *line = [e nextObject];
  while (line) {
    line = [self stripComments:line];
    if (line == nil || [line length] == 0) { line = [e nextObject]; continue; }
    @try {
      line = [self replaceAliases:line];
    } @catch (NSException *ex) {
      SlateLogger(@"   ERROR %@",[ex name]);
      NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
      [alert setMessageText:[ex name]];
      [alert setInformativeText:[ex reason]];
      if ([alert runModal] == NSAlertFirstButtonReturn) {
        SlateLogger(@"User selected exit");
        [NSApp terminate:nil];
      }
    }
    NSMutableArray *tokens = [[NSMutableArray alloc] initWithCapacity:10];
    [StringTokenizer tokenize:line into:tokens];
    if ([tokens count] >= 3 && [[tokens objectAtIndex:0] isEqualToString:CONFIG]) {
      // config <key>[:<app>] <value>
      SlateLogger(@"  LoadingC: %@",line);
      NSArray *splitKey = [[tokens objectAtIndex:1] componentsSeparatedByString:@":"];
      NSString *key = [splitKey count] > 1 ? [splitKey objectAtIndex:0] : [tokens objectAtIndex:1];
      if ([configs objectForKey:key] == nil) {
        SlateLogger(@"   ERROR Unrecognized config '%@'",[tokens objectAtIndex:1]);
        NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
        [alert setMessageText:[NSString stringWithFormat:@"Unrecognized Config '%@'",[tokens objectAtIndex:1]]];
        [alert setInformativeText:line];
        if ([alert runModal] == NSAlertFirstButtonReturn) {
          SlateLogger(@"User selected exit");
          [NSApp terminate:nil];
        }
      } else {
        if ([splitKey count] > 1 && [[splitKey objectAtIndex:1] length] > 2) {
          NSString *appName = [[splitKey objectAtIndex:1] substringWithRange:NSMakeRange(1, [[splitKey objectAtIndex:1] length] - 2)];
          SlateLogger(@"    Found App Config for App: '%@' Key: %@", appName, key);
          NSMutableDictionary *configsForApp = [appConfigs objectForKey:appName];
          if (configsForApp == nil) { configsForApp = [NSMutableDictionary dictionary]; }
          [configsForApp setObject:[tokens objectAtIndex:2] forKey:key];
          [appConfigs setObject:configsForApp forKey:appName];
        } else {
          [configs setObject:[tokens objectAtIndex:2] forKey:[tokens objectAtIndex:1]];
        }
      }
    } else if ([tokens count] >= 3 && [[tokens objectAtIndex:0] isEqualToString:BIND]) {
      // bind <key:modifiers|modal-key> <op> <parameters>
      @try {
        SlateLogger(@"  LoadingB: %@",line);
        Binding *bind = [[Binding alloc] initWithString:line];
        [self addBinding:bind];
      } @catch (NSException *ex) {
        SlateLogger(@"   ERROR %@",[ex name]);
        NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
        [alert setMessageText:[ex name]];
        [alert setInformativeText:[ex reason]];
        if ([alert runModal] == NSAlertFirstButtonReturn) {
          SlateLogger(@"User selected exit");
          [NSApp terminate:nil];
        }
      }
    } else if ([tokens count] >= 3 && [[tokens objectAtIndex:0] isEqualToString:ALIAS]) {
      // alias <name> <value>
      @try {
        [self addAlias:line];
        SlateLogger(@"  LoadingA: %@",line);
      } @catch (NSException *ex) {
        SlateLogger(@"   ERROR %@",[ex name]);
        NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
        [alert setMessageText:[ex name]];
        [alert setInformativeText:[ex reason]];
        if ([alert runModal] == NSAlertFirstButtonReturn) {
          SlateLogger(@"User selected exit");
          [NSApp terminate:nil];
        }
      }
    } else if ([tokens count] >= 2 && [[tokens objectAtIndex:0] isEqualToString:SOURCE]) {
      // source filename optional:if_exists
      SlateLogger(@"  LoadingS: %@",line);
      if (![self loadConfigFileWithPath:[tokens objectAtIndex:1]]) {
        if ([tokens count] >= 3 && [[tokens objectAtIndex:2] isEqualToString:IF_EXISTS]) {
          SlateLogger(@"   Could not find file '%@' but that's ok. User specified if_exists.",[tokens objectAtIndex:1]);
        } else {
          SlateLogger(@"   ERROR Sourcing file '%@'",[tokens objectAtIndex:1]);
          NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Quit", @"Skip", nil]];
          [alert setMessageText:[NSString stringWithFormat:@"ERROR Sourcing file '%@'",[tokens objectAtIndex:1]]];
          [alert setInformativeText:@"I dunno. Figure it out."];
          if ([alert runModal] == NSAlertFirstButtonReturn) {
            SlateLogger(@"User selected exit");
            [NSApp terminate:nil];
          }
        }
      }
    }
    line = [e nextObject];
  }
  return YES;
}

- (void)addAlias:(NSString *)line {
  NSMutableArray *tokens = [[NSMutableArray alloc] initWithCapacity:10];
  [StringTokenizer tokenize:line into:tokens maxTokens:3];
  [aliases setObject:[tokens objectAtIndex:2] forKey:[NSString stringWithFormat:@"${%@}",[tokens objectAtIndex:1]]];
}

- (NSString *)replaceAliases:(NSString *)line {
  NSArray *aliasNames = [aliases allKeys];
  for (NSInteger i = 0; i < [aliasNames count]; i++) {
    line = [line stringByReplacingOccurrencesOfString:[aliasNames objectAtIndex:i] withString:[aliases objectForKey:[aliasNames objectAtIndex:i]]];
  }
  if ([line rangeOfString:@"${"].length > 0) {
    @throw([NSException exceptionWithName:@"Unrecognized Alias" reason:[NSString stringWithFormat:@"Unrecognized alias in '%@'", line] userInfo:nil]);
  }
  return line;
}

/*- (void)processNotification:(id)notification {
  SlateLogger(@"Notification: %@", notification);
  SlateLogger(@"Notification Name: <%@>", [notification name]);
}*/

- (void)checkDefaults {
  ScreenWrapper *sw = [[ScreenWrapper alloc] init];
  NSInteger screenCount = [sw getScreenCount];
  NSMutableArray *resolutions = [[NSMutableArray alloc] initWithCapacity:10];
  [sw getScreenResolutionStrings:resolutions];
  [resolutions sortUsingSelector:@selector(compare:)];
}

- (void)onScreenChange:(id)notification {
  SlateLogger(@"onScreenChange");
  if (![ScreenWrapper hasScreenConfigChanged]) return;
  [self checkDefaults];
}

- (void)setupDefaultConfigs {
  [self setConfigDefaults:[NSMutableDictionary dictionaryWithCapacity:10]];
  [configDefaults setObject:DEFAULT_TO_CURRENT_SCREEN_DEFAULT forKey:DEFAULT_TO_CURRENT_SCREEN];
  [configDefaults setObject:RESIZE_PERCENT_OF_DEFAULT forKey:RESIZE_PERCENT_OF];
  [configDefaults setObject:CHECK_DEFAULTS_ON_LOAD_DEFAULT forKey:CHECK_DEFAULTS_ON_LOAD];
  [configDefaults setObject:FOCUS_CHECK_WIDTH_DEFAULT forKey:FOCUS_CHECK_WIDTH];
  [configDefaults setObject:FOCUS_CHECK_WIDTH_MAX_DEFAULT forKey:FOCUS_CHECK_WIDTH_MAX];
  [configDefaults setObject:FOCUS_PREFER_SAME_APP_DEFAULT forKey:FOCUS_PREFER_SAME_APP];
  [configDefaults setObject:ORDER_SCREENS_LEFT_TO_RIGHT_DEFAULT forKey:ORDER_SCREENS_LEFT_TO_RIGHT];
  [configDefaults setObject:KEYBOARD_LAYOUT_DEFAULT forKey:KEYBOARD_LAYOUT];
  [configDefaults setObject:UNDO_MAX_STACK_SIZE_DEFAULT forKey:UNDO_MAX_STACK_SIZE];
  [configDefaults setObject:MODAL_ESCAPE_KEY_DEFAULT forKey:MODAL_ESCAPE_KEY];
  [configDefaults setObject:JS_RECEIVE_MOVE_EVENT_DEFAULT forKey:JS_RECEIVE_MOVE_EVENT];
  [configDefaults setObject:JS_RECEIVE_RESIZE_EVENT_DEFAULT forKey:JS_RECEIVE_RESIZE_EVENT];
  [self setConfigs:[NSMutableDictionary dictionary]];
  [self setAppConfigs:[NSMutableDictionary dictionary]];
  [configs setValuesForKeysWithDictionary:configDefaults];
}

@end

void onDisplayReconfiguration (CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {
    SlateLogger(@"onDisplayReconfiguration");
    [(__bridge id)userInfo onScreenChange:nil];
}
