/* === This file is part of Tomahawk Player - <http://tomahawk-player.org> ===
 *
 *   Copyright 2010-2011, Leo Franchi <lfranchi@kde.org>
 *
 *   Tomahawk is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   Tomahawk is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with Tomahawk. If not, see <http://www.gnu.org/licenses/>.
 */

#include "TomahawkApp_Mac.h"

#include "MacDelegate.h"
#include "MacShortcutHandler.h"
#include "config.h"
#include "audio/AudioEngine.h"
#include "utils/Logger.h"
#include "Tomahawkapp_MacDelegate.h"

#include <AvailabilityMacros.h>

#import <Cocoa/Cocoa.h>

#ifdef HAVE_SPARKLE
#import <Sparkle/SUUpdater.h>
#endif

#include <QApplication>

@interface MacApplication :NSApplication {
    Tomahawk::MacShortcutHandler* shortcut_handler_;
    Tomahawk::PlatformInterface* application_handler_;
}

- (Tomahawk::MacShortcutHandler*) shortcutHandler;
- (void) setShortcutHandler: (Tomahawk::MacShortcutHandler*)handler;

- (Tomahawk::PlatformInterface*) application_handler;
- (void) setApplicationHandler: (Tomahawk::PlatformInterface*)handler;
- (void) mediaKeyEvent: (int)key state: (BOOL)state repeat: (BOOL)repeat;

#ifdef HAVE_SPARKLE
// SUUpdaterDelegate
- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update;
#endif

@end


@implementation AppDelegate

- (id) init {
  if ((self = [super init])) {
    application_handler_ = nil;
//    dock_menu_ = nil;
  }
  return self;
}

- (id) initWithHandler: (Tomahawk::PlatformInterface*)handler {
  application_handler_ = handler;

  return self;
}

- (BOOL) applicationShouldHandleReopen: (NSApplication*)app hasVisibleWindows:(BOOL)flag {
  if (application_handler_) {
    application_handler_->activate();
  }
  return YES;
}

/*
- (void) setDockMenu: (NSMenu*)menu {
  dock_menu_ = menu;
}

- (NSMenu*) applicationDockMenu: (NSApplication*)sender {
  return dock_menu_;
}
*/

- (BOOL) application: (NSApplication*)app openFile:(NSString*)filename {

  if (application_handler_->loadUrl(QString::fromUtf8([filename UTF8String]))) {
    return YES;
  }

  return NO;
}

@end

@implementation MacApplication

- (id) init {
  if ((self = [super init])) {
      [self setShortcutHandler:nil];
      [self setApplicationHandler:nil];

      NSAppleEventManager *em = [NSAppleEventManager sharedAppleEventManager];
      [em
        setEventHandler:self
            andSelector:@selector(getUrl:withReplyEvent:)
          forEventClass:kInternetEventClass
             andEventID:kAEGetURL];
      [em
        setEventHandler:self
            andSelector:@selector(getUrl:withReplyEvent:)
          forEventClass:'WWW!'
             andEventID:'OURL'];
      NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
      OSStatus httpResult = LSSetDefaultHandlerForURLScheme((CFStringRef)@"tomahawk", (CFStringRef)bundleID);

      Q_UNUSED(httpResult);
      //TODO: Check httpResult and httpsResult for errors
  }
  return self;
}

- (Tomahawk::MacShortcutHandler*) shortcutHandler {
    return shortcut_handler_;
}

- (void) setShortcutHandler: (Tomahawk::MacShortcutHandler*)handler {
    // should be the same as AppDelegate's
  shortcut_handler_ = handler;
}

- (Tomahawk::PlatformInterface*) application_handler {
  return application_handler_;
}

- (void) setApplicationHandler: (Tomahawk::PlatformInterface*)handler {
  AppDelegate* delegate = [[AppDelegate alloc] initWithHandler:handler];
  [self setDelegate:delegate];
}

-(void) sendEvent: (NSEvent*)event {
  if ([event type] == NSSystemDefined && [event subtype] == 8) {
    int keycode = (([event data1] & 0xFFFF0000) >> 16);
    int keyflags = ([event data1] & 0x0000FFFF);
    int keystate = (((keyflags & 0xFF00) >> 8)) == 0xA;
    int keyrepeat = (keyflags & 0x1);

    [self mediaKeyEvent: keycode state: keystate repeat: keyrepeat];
  }
  [super sendEvent: event];
}

-(void) mediaKeyEvent: (int)key state: (BOOL)state repeat: (BOOL)repeat {
  if (!shortcut_handler_) {
    return;
  }
  if (state == 0) {
    shortcut_handler_->macMediaKeyPressed(key);
  }
}

#ifdef HAVE_SPARKLE
- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update
{
//    tLog() << "NSApp in willInstallUpdate, deleting Phonon objects";
    AudioEngine::instance()->stop();
    delete AudioEngine::instance();
}
#endif

@end

void Tomahawk::macMain() {
  [[NSAutoreleasePool alloc] init];
  // Creates and sets the magic global variable so QApplication will find it.
  [MacApplication sharedApplication];
#ifdef HAVE_SPARKLE
    // Creates and sets the magic global variable for Sparkle.
    [[SUUpdater sharedUpdater] setDelegate: NSApp];
#endif
}

void Tomahawk::setShortcutHandler(Tomahawk::MacShortcutHandler* handler) {
  [NSApp setShortcutHandler: handler];
}

void Tomahawk::setApplicationHandler(Tomahawk::PlatformInterface* handler) {
  [NSApp setApplicationHandler: handler];
}

void Tomahawk::checkForUpdates() {
#ifdef HAVE_SPARKLE
  [[SUUpdater sharedUpdater] checkForUpdates: NSApp];
#endif
}
