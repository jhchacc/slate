//
//  Binding.m
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
#import "SlateConfig.h"
#import "StringTokenizer.h"
#import "SlateLogger.h"
#import "Operation.h"
#import "SlateAppDelegate.h"

@implementation Binding

@synthesize op;
@synthesize keyCode;
@synthesize modifiers;
@synthesize modalKey;
@synthesize hotKeyRef;

static NSDictionary *dictionary = nil;

- (id)init {
  self = [super init];
  if (self) {
    [self setModalKey:nil];
  }
  return self;
}

// Yes, this method is huge. Deal with it.
- (id)initWithString:(NSString *)binding {
  self = [self init];
  if (self) {
    // bind <key:modifiers|modal-key> <op> <parameters>
    NSMutableArray *tokens = [[NSMutableArray alloc] initWithCapacity:10];
    [StringTokenizer tokenize:binding into:tokens maxTokens:3];
    if ([tokens count] <=2) {
      @throw([NSException exceptionWithName:@"Unrecognized Bind" reason:binding userInfo:nil]);
    }
    [self setKeystroke:[tokens objectAtIndex:1]];
    [self setOperation:[tokens objectAtIndex:2]];
  }

  return self;
}

+ (UInt32)getModifierKey:(NSString *)mod {
  if ([mod isEqualToString:CONTROL]) { return controlKey; }
  if ([mod isEqualToString:OPTION]) { return optionKey; }
  if ([mod isEqualToString:COMMAND]) { return cmdKey; }
  if ([mod isEqualToString:SHIFT]) { return shiftKey; }
  if ([mod isEqualToString:FUNCTION]) { return FUNCTION_KEY; }
  @throw([NSException exceptionWithName:@"Unrecognized Modifier" reason:[NSString stringWithFormat:@"'%@'", mod] userInfo:nil]);
}

+ (NSArray *)getKeystroke:(NSString *)keystroke {
  NSNumber *theKeyCode = [NSNumber numberWithUnsignedInt:0];
  UInt32 theModifiers = 0;
  NSNumber *theModalKey = nil;
  NSArray *keyAndModifiers = [keystroke componentsSeparatedByString:COLON];
  if ([keyAndModifiers count] >= 1) {
    NSString *theKey = [keyAndModifiers objectAtIndex:0];
    theKeyCode = [[Binding asciiToCodeDict] objectForKey:theKey];
    if (theKeyCode == nil) {
      SlateLogger(@"ERROR: Unrecognized key \"%@\" in \"%@\"", theKey, keystroke);
      @throw([NSException exceptionWithName:@"Unrecognized Key" reason:[NSString stringWithFormat:@"Unrecognized key \"%@\" in \"%@\"", theKey, keystroke] userInfo:nil]);
    }
    if ([keyAndModifiers count] >= 2) {
      theModalKey = [[Binding asciiToCodeDict] objectForKey:[keyAndModifiers objectAtIndex:1]];
      if (theModalKey == nil) {
        // normal case
        NSArray *modifiersArray = [[keyAndModifiers objectAtIndex:1] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",;"]];
        NSEnumerator *modEnum = [modifiersArray objectEnumerator];
        NSString *mod = [modEnum nextObject];
        while (mod) {
          NSNumber *_theModalKey = [[Binding asciiToCodeDict] objectForKey:mod];
          if (_theModalKey != nil) {
            theModalKey = _theModalKey;
          } else {
            theModifiers += [Binding getModifierKey:mod];
          }
          mod = [modEnum nextObject];
        }
      }
    }
  }
  return [NSArray arrayWithObjects:theKeyCode, [NSNumber numberWithInteger:theModifiers], theModalKey, nil];
}

- (void)setKeystroke:(NSString*)keystroke {
  NSArray *modalAndKey = [keystroke componentsSeparatedByString:COLON];
  if ([modalAndKey count] > 0) {
    NSArray *keyarr = [Binding getKeystroke:keystroke];
    keyCode = [[keyarr objectAtIndex:0] unsignedIntValue];
    modifiers = [[keyarr objectAtIndex:1] unsignedIntValue];
    if ([keyarr count] >= 3 ) {
      [self setModalKey:[keyarr objectAtIndex:2]];
    }
  }
}

- (void)setOperation:(NSString*)token {
  NSMutableString *opStr = [[NSMutableString alloc] initWithCapacity:10];
  [StringTokenizer firstToken:token into:opStr];

  Operation *theOp = [Operation operation:token];
  if (theOp == nil) {
    SlateLogger(@"ERROR: Unable to create binding");
    @throw([NSException exceptionWithName:@"Unable To Create Binding" reason:[NSString stringWithFormat:@"Unable to create '%@'", token] userInfo:nil]);
  }

  @try {
    [theOp testOperation];
  } @catch (NSException *ex) {
    SlateLogger(@"ERROR: Unable to test binding '%@'", token);
    @throw([NSException exceptionWithName:@"Unable To Parse Binding" reason:[NSString stringWithFormat:@"Unable to parse '%@' in '%@'", [ex reason], token] userInfo:nil]);
  }

  op = theOp;
}

- (BOOL)doOperation {
  return [op doOperation];
}

- (NSString *)modalHashKey {
  if ([self modalKey] == nil) {
    return nil;
  }
  return [NSString stringWithFormat:@"%@%@%u", [self modalKey], PLUS, [self modifiers]];
}

+ (NSArray *)modalHashKeyToKeyAndModifiers:(NSString *)modalHashKey {
  NSArray *modalKeyArr = [modalHashKey componentsSeparatedByString:PLUS];
  NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
  NSNumber *theKey = [nf numberFromString:[modalKeyArr objectAtIndex:0]];
  NSNumber *theModifiers = [nf numberFromString:[modalKeyArr objectAtIndex:1]];
  return [NSArray arrayWithObjects:theKey, theModifiers, nil];
}

- (void)dealloc {
  [self setHotKeyRef:nil];
}

// This returns a dictionary containing mappings from ASCII to keyCode
+ (NSDictionary *)asciiToCodeDict {
  if (dictionary == nil) {
    NSString *configLayout = [[SlateConfig getInstance] getConfig:KEYBOARD_LAYOUT];
    NSString *filename;
    if ([configLayout isEqualToString:KEYBOARD_LAYOUT_DVORAK]) {
      filename = @"ASCIIToCode_Dvorak";
    } else if ([configLayout isEqualToString:KEYBOARD_LAYOUT_COLEMAK]) {
      filename = @"ASCIIToCode_Colemak";
    } else if ([configLayout isEqualToString:KEYBOARD_LAYOUT_AZERTY]) {
      filename = @"ASCIIToCode_Azerty";
    } else {
      filename = @"ASCIIToCode";
    }
    dictionary = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:filename ofType:@"plist"]];
  }
  return dictionary;
}

@end
