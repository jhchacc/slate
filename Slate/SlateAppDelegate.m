//
//  SlateAppDelegate.m
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

#import "Constants.h"
#import "SlateAppDelegate.h"
#import "SlateConfig.h"
#import "Binding.h"
#import "SlateLogger.h"
#import "RunningApplications.h"
//#import <Sparkle/SUUpdater.h>

@implementation SlateAppDelegate

@synthesize modalHotKeyRefs, modalIdToKey;
@synthesize currentModalKey, currentModalHotKeyRefs;

static SlateAppDelegate *selfRef = nil;

- (IBAction)currentWindowInfo {
  [windowInfoController showWindow:windowInfo];
  [windowInfo makeKeyAndOrderFront:NSApp];
  [windowInfo setLevel:(NSScreenSaverWindowLevel - 1)];
}

- (void)loadConfig {
  [[SlateConfig getInstance] load];
}

- (void)registerHotKeys {
  SlateLogger(@"Registering HotKeys...");
  
  EventTypeSpec eventType;
  eventType.eventClass = kEventClassKeyboard;
  eventType.eventKind = kEventHotKeyPressed;
  InstallEventHandler(GetEventMonitorTarget(), &OnHotKeyEvent, 1, &eventType, (__bridge void *)self, NULL);

  NSMutableArray *bindings = [[SlateConfig getInstance] bindings];

  for (NSInteger i = 0; i < [bindings count]; i++) {
    Binding *binding = [bindings objectAtIndex:i];
    SlateLogger(@"REGISTERING KEY: %u, MODIFIERS: %u", [binding keyCode], [binding modifiers]);
    EventHotKeyID myHotKeyID;
    EventHotKeyRef myHotKeyRef;
    myHotKeyID.signature = *[[NSString stringWithFormat:@"hotkey%li",i] cStringUsingEncoding:NSASCIIStringEncoding];
    myHotKeyID.id = (UInt32)i;
    RegisterEventHotKey([binding keyCode], [binding modifiers], myHotKeyID, GetEventMonitorTarget(), 0, &myHotKeyRef);
    [binding setHotKeyRef:myHotKeyRef];
  }

  NSArray *modalKeys = [[[SlateConfig getInstance] modalBindings] allKeys];
  NSInteger i = MODAL_BEGIN_ID;
  for (NSString *modalHashKey in modalKeys) {
    SlateLogger(@"REGISTERING MODAL KEY: %@", modalHashKey);
    NSArray *modalKeyArr = [Binding modalHashKeyToKeyAndModifiers:modalHashKey];
    if (modalKeyArr == nil) continue;
    EventHotKeyID myHotKeyID;
    EventHotKeyRef myHotKeyRef;
    myHotKeyID.signature = *[[NSString stringWithFormat:@"hotkey%li",i] cStringUsingEncoding:NSASCIIStringEncoding];
    myHotKeyID.id = (UInt32)i;
    RegisterEventHotKey([[modalKeyArr objectAtIndex:0] unsignedIntValue], [[modalKeyArr objectAtIndex:1] unsignedIntValue], myHotKeyID, GetEventMonitorTarget(), 0, &myHotKeyRef);
    [[self modalHotKeyRefs] setObject:[NSValue valueWithPointer:myHotKeyRef] forKey:modalHashKey];
    [[self modalIdToKey] setObject:modalHashKey forKey:[NSNumber numberWithInteger:i]];
    i++;
  }
  SlateLogger(@"HotKeys registered.");
}

- (IBAction)aboutWindow {
  [NSApp orderFrontStandardAboutPanel:self];
  NSArray *windows = [NSApp windows];
  for (NSWindow *window in windows) {
    [window setLevel:(NSScreenSaverWindowLevel - 1)];
  }
}

- (void)resetModalKey {
  // clear out bindings
  for (NSValue *hotKeyRef in [self currentModalHotKeyRefs]) {
    UnregisterEventHotKey([hotKeyRef pointerValue]);
  }
  // reset status image
  [statusItem setImage:[NSImage imageNamed:@"status"]];
  currentModalKey = nil;
}

- (OSStatus)activateBinding:(EventHotKeyID)eventKey {
  SlateLogger(@"ACTIVATING BINDING: %u", eventKey.id);

  // check modal stuffs
  NSNumber *hkId = [NSNumber numberWithInteger:eventKey.id];
  NSString *modalKey = [[self modalIdToKey] objectForKey:hkId];
  if (modalKey != nil) {
    if (currentModalKey != nil && [modalKey isEqualToString:currentModalKey]) {
      [self resetModalKey];
      return noErr;
    } else if (currentModalKey == nil) {
      SlateLogger(@"FOUND MODAL KEY BINDING, REGISTERING!");
      // register all these bindings
      [[self currentModalHotKeyRefs] removeAllObjects];
      NSArray *modalOperations = [[[SlateConfig getInstance] modalBindings] objectForKey:modalKey];
      NSInteger i = CURRENT_MODAL_BEGIN_ID;
      for (Binding *binding in modalOperations) {
        EventHotKeyID myHotKeyID;
        EventHotKeyRef myHotKeyRef;
        myHotKeyID.signature = *[[NSString stringWithFormat:@"hotkey%li",i] cStringUsingEncoding:NSASCIIStringEncoding];
        myHotKeyID.id = (UInt32)i;
        RegisterEventHotKey([binding keyCode], 0, myHotKeyID, GetEventMonitorTarget(), 0, &myHotKeyRef);
        [binding setHotKeyRef:myHotKeyRef];
        [[self currentModalHotKeyRefs] addObject:[NSValue valueWithPointer:myHotKeyRef]];
        i++;
      }
      if (![EMPTY isEqualToString:[[SlateConfig getInstance] getConfig:MODAL_ESCAPE_KEY]]) {
        EventHotKeyID myHotKeyID;
        EventHotKeyRef myHotKeyRef;
        myHotKeyID.signature = *[[NSString stringWithFormat:@"hotkey%li",MODAL_ESCAPE_ID] cStringUsingEncoding:NSASCIIStringEncoding];
        myHotKeyID.id = (UInt32)MODAL_ESCAPE_ID;
        NSArray *keyarr = [Binding getKeystrokeFromString:[[SlateConfig getInstance] getConfig:MODAL_ESCAPE_KEY]];
        RegisterEventHotKey([[keyarr objectAtIndex:0] unsignedIntValue], [[keyarr objectAtIndex:1] unsignedIntValue], myHotKeyID, GetEventMonitorTarget(), 0, &myHotKeyRef);
        [[self currentModalHotKeyRefs] addObject:[NSValue valueWithPointer:myHotKeyRef]];
      }
      [self setCurrentModalKey:modalKey];
      // change status image
      [statusItem setImage:[NSImage imageNamed:@"statusActive"]];
      return noErr;
    }
  }

  if (eventKey.id >= [[[SlateConfig getInstance] bindings] count]) {
    if (currentModalKey != nil) {
      if (eventKey.id == MODAL_ESCAPE_ID) {
        [self resetModalKey];
      } else {
        NSInteger potentialId = eventKey.id - CURRENT_MODAL_BEGIN_ID;
        if (potentialId >= 0 && potentialId < [[[[SlateConfig getInstance] modalBindings] objectForKey:currentModalKey] count]) {
          Binding *binding = [[[[SlateConfig getInstance] modalBindings] objectForKey:currentModalKey] objectAtIndex:potentialId];
          [binding doOperation];
        }
      }
    }
    return noErr;
  }
  Binding *binding = [[[SlateConfig getInstance] bindings] objectAtIndex:eventKey.id];
  if (binding) {
    SlateLogger(@"Running Operation %@", [[[SlateConfig getInstance] bindings] objectAtIndex:eventKey.id]);
    [binding doOperation];
  }
  return noErr;
}

OSStatus OnHotKeyEvent(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
  if (![(__bridge id)userData isKindOfClass:[SlateAppDelegate class]]) return noErr;
  EventHotKeyID hkCom;
  GetEventParameter(theEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(hkCom), NULL, &hkCom);
  return [(__bridge SlateAppDelegate *)userData activateBinding:hkCom];
}

- (void)awakeFromNib {
  [self setModalHotKeyRefs:[NSMutableDictionary dictionary]];
  [self setModalIdToKey:[NSMutableDictionary dictionary]];
  [self setCurrentModalHotKeyRefs:[NSMutableArray array]];

  windowInfoController = [[NSWindowController alloc] initWithWindow:windowInfo];

  NSMenuItem *aboutItem = [statusMenu insertItemWithTitle:@"About Slate" action:@selector(aboutWindow) keyEquivalent:@"" atIndex:0];
  [aboutItem setTarget:self];

  NSMenuItem *windowInfoItem = [statusMenu insertItemWithTitle:@"Current Window Info" action:@selector(currentWindowInfo) keyEquivalent:@"" atIndex:1];
  [windowInfoItem setTarget:self];

  statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSVariableStatusItemLength];
  [statusItem setMenu:statusMenu];
  NSImage *statusImage = [NSImage imageNamed:@"status"];
  [statusImage setTemplate:YES];
  [statusItem setImage:statusImage];
  [statusItem setHighlightMode:YES];

  // Check if Accessibility API is enabled
  if (!AXAPIEnabled()) {
    NSAlert *alert = [SlateConfig warningAlertWithKeyEquivalents: [NSArray arrayWithObjects:@"Enable", @"Quit", nil]];
    [alert setMessageText:[NSString stringWithFormat:@"Slate cannot run without \"Access for assistive devices\". Would you like to enable it?"]];
    [alert setInformativeText:[NSString stringWithFormat:@"You may be prompted for your administrator password."]];
    [alert setAlertStyle:NSCriticalAlertStyle];
    NSInteger alertIndex = [alert runModal];
    if (alertIndex == NSAlertFirstButtonReturn) {
      SlateLogger(@"User wants to enable Access for assistive devices");
      NSDictionary* errorDictionary;
      NSAppleScript* applescript = [[NSAppleScript alloc] initWithSource:@"tell application \"System Events\" to set UI elements enabled to true"];
      [applescript executeAndReturnError:&errorDictionary];
    }
    else if (alertIndex == NSAlertSecondButtonReturn) {
      SlateLogger(@"User selected quit");
      [NSApp terminate:nil];
    }
  }

  // Read Config
  [self loadConfig];

  // Register Hot Keys
  [self registerHotKeys];

  selfRef = self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  return YES;
}

@end
