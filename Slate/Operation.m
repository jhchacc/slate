//
//  Operation.m
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

#import "Operation.h"
#import "MoveOperation.h"
#import "FocusOperation.h"
#import "StringTokenizer.h"
#import "Constants.h"
#import "SlateLogger.h"
#import "SlateConfig.h"
#import <WebKit/WebKit.h>
#import "CornerOperation.h"
#import "ThrowOperation.h"
#import "PushOperation.h"

@implementation Operation

@synthesize opName;
@synthesize options;

- (id)init {
  self = [super init];
  if (self) {
    [self setOpName:nil];
    [self setOptions:[NSMutableDictionary dictionary]];
  }

  return self;
}

- (BOOL)doOperation {
  return YES;
}

- (BOOL)testOperation {
  return YES;
}

- (BOOL)testOperationWithAccessibilityWrapper:(AccessibilityWrapper *)aw screenWrapper:(ScreenWrapper *)sw {
  return [self testOperation];
}

+ (id)operation:(NSString *)opString {
  NSMutableArray *tokens = [[NSMutableArray alloc] initWithCapacity:10];
  [StringTokenizer tokenize:opString into:tokens maxTokens:2];
  NSString *op = [tokens objectAtIndex:0];
  Operation *operation = nil;
  if ([op isEqualToString:MOVE]) {
    operation = [MoveOperation moveOperation:opString];
  } else if ([op isEqualToString:PUSH]) {
    operation = [PushOperation pushOperation:opString];
  } else if ([op isEqualToString:THROW]) {
    operation = [ThrowOperation throwOperation:opString];
  } else if ([op isEqualToString:CORNER]) {
    operation = [CornerOperation cornerOperation:opString];
  } else if ([op isEqualToString:FOCUS]) {
    operation = [FocusOperation focusOperation:opString];
  } else {
    SlateLogger(@"ERROR: Unrecognized operation '%@'", opString);
    @throw([NSException exceptionWithName:@"Unrecognized Operation" reason:[NSString stringWithFormat:@"Unrecognized operation '%@' in '%@'", op, opString] userInfo:nil]);
  }
  if (operation != nil) { [operation setOpName:op]; }
  return operation;
}

@end
