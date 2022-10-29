//
//  PushOperation.m
//  Slate
//
//  Created by Jigish Patel on 1/20/13.
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

#import "PushOperation.h"
#import "StringTokenizer.h"
#import "SlateLogger.h"
#import "Constants.h"

@implementation PushOperation

+ (id)pushOperation:(NSString *)pushOperation {
  // push <top|bottom|up|down|left|right> <optional:none|center|bar|bar-resize:expression> <optional:monitor (must specify previous option to specify monitor)>
  NSMutableArray *tokens = [[NSMutableArray alloc] initWithCapacity:10];
  [StringTokenizer tokenize:pushOperation into:tokens];

  if ([tokens count] < 2) {
    SlateLogger(@"ERROR: Invalid Parameters '%@'", pushOperation);
    @throw([NSException exceptionWithName:@"Invalid Parameters" reason:[NSString stringWithFormat:@"Invalid Parameters in '%@'. Push operations require the following format: 'push direction [optional:style]'", pushOperation] userInfo:nil]);
  }

  NSString *direction = [tokens objectAtIndex:1];
  NSString *dimensions = @"windowSizeX;windowSizeY";
  NSString *topLeft = nil;
  NSString *style = NONE;
  if ([tokens count] >= 3) {
    style = [tokens objectAtIndex:2];
  }
  if ([direction isEqualToString:TOP] || [direction isEqualToString:UP]) {
    if ([style isEqualToString:CENTER]) {
      topLeft = @"screenOriginX+(screenSizeX-windowSizeX)/2;screenOriginY";
    } else if ([style isEqualToString:BAR]) {
      topLeft = @"screenOriginX;screenOriginY";
      dimensions = @"screenSizeX;windowSizeY";
    } else if ([style hasPrefix:BAR_RESIZE_WITH_VALUE]) {
      NSString *resizeExpression = [[style componentsSeparatedByString:COLON] objectAtIndex:1];
      topLeft = @"screenOriginX;screenOriginY";
      dimensions = [@"screenSizeX;" stringByAppendingString:resizeExpression];
    } else if ([style isEqualToString:NONE]) {
      topLeft = @"windowTopLeftX;screenOriginY";
    } else {
      SlateLogger(@"ERROR: Unrecognized style '%@'", style);
      @throw([NSException exceptionWithName:@"Unrecognized Style" reason:[NSString stringWithFormat:@"Unrecognized style '%@' in '%@'", style, pushOperation] userInfo:nil]);
    }
  } else if ([direction isEqualToString:BOTTOM] || [direction isEqualToString:DOWN]) {
    if ([style isEqualToString:CENTER]) {
      topLeft = @"screenOriginX+(screenSizeX-windowSizeX)/2;screenOriginY+screenSizeY-windowSizeY";
    } else if ([style isEqualToString:BAR]) {
      topLeft = @"screenOriginX;screenOriginY+screenSizeY-windowSizeY";
      dimensions = @"screenSizeX;windowSizeY";
    } else if ([style hasPrefix:BAR_RESIZE_WITH_VALUE]) {
      NSString *resizeExpression = [[style componentsSeparatedByString:COLON] objectAtIndex:1];
      topLeft = [@"screenOriginX;screenOriginY+screenSizeY-" stringByAppendingString:resizeExpression];
      dimensions = [@"screenSizeX;" stringByAppendingString:resizeExpression];
    } else if ([style isEqualToString:NONE]) {
      topLeft = @"windowTopLeftX;screenOriginY+screenSizeY-windowSizeY";
    } else {
      SlateLogger(@"ERROR: Unrecognized style '%@'", style);
      @throw([NSException exceptionWithName:@"Unrecognized Style" reason:[NSString stringWithFormat:@"Unrecognized style '%@' in '%@'", style, pushOperation] userInfo:nil]);
    }
  } else if ([direction isEqualToString:LEFT]) {
    if ([style isEqualToString:CENTER]) {
      topLeft = @"screenOriginX;screenOriginY+(screenSizeY-windowSizeY)/2";
    } else if ([style isEqualToString:BAR]) {
      topLeft = @"screenOriginX;screenOriginY";
      dimensions = @"windowSizeX;screenSizeY";
    } else if ([style hasPrefix:BAR_RESIZE_WITH_VALUE]) {
      NSString *resizeExpression = [[style componentsSeparatedByString:COLON] objectAtIndex:1];
      topLeft = @"screenOriginX;screenOriginY";
      dimensions = [resizeExpression stringByAppendingString:@",screenSizeY"];
    } else if ([style isEqualToString:NONE]) {
      topLeft = @"screenOriginX;windowTopLeftY";
    } else {
      SlateLogger(@"ERROR: Unrecognized style '%@'", style);
      @throw([NSException exceptionWithName:@"Unrecognized Style" reason:[NSString stringWithFormat:@"Unrecognized style '%@' in '%@'", style, pushOperation] userInfo:nil]);
    }
  } else if ([direction isEqualToString:RIGHT]) {
    if ([style isEqualToString:CENTER]) {
      topLeft = @"screenOriginX+screenSizeX-windowSizeX;screenOriginY+(screenSizeY-windowSizeY)/2";
    } else if ([style isEqualToString:BAR]) {
      topLeft = @"screenOriginX+screenSizeX-windowSizeX;screenOriginY";
      dimensions = @"windowSizeX;screenSizeY";
    } else if ([style hasPrefix:BAR_RESIZE_WITH_VALUE]) {
      NSString *resizeExpression = [[style componentsSeparatedByString:COLON] objectAtIndex:1];
      topLeft = [[@"screenOriginX+screenSizeX-" stringByAppendingString:resizeExpression] stringByAppendingString:@";screenOriginY"];
      dimensions = [resizeExpression stringByAppendingString:@";screenSizeY"];
    } else if ([style isEqualToString:NONE]) {
      topLeft = @"screenOriginX+screenSizeX-windowSizeX;windowTopLeftY";
    } else {
      SlateLogger(@"ERROR: Unrecognized style '%@'", style);
      @throw([NSException exceptionWithName:@"Unrecognized Style" reason:[NSString stringWithFormat:@"Unrecognized style '%@' in '%@'", style, pushOperation] userInfo:nil]);
    }
  } else {
    SlateLogger(@"ERROR: Unrecognized direction '%@'", direction);
    @throw([NSException exceptionWithName:@"Unrecognized Direction" reason:[NSString stringWithFormat:@"Unrecognized direction '%@' in '%@'", direction, pushOperation] userInfo:nil]);
  }
  Operation *op = [[MoveOperation alloc] init:topLeft dimensions:dimensions monitor:([tokens count] >=4 ? [tokens objectAtIndex:3] : REF_CURRENT_SCREEN)];
  return op;
}

@end
