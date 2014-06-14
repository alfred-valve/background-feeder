//
//  AppDelegate.h
//  RSS Desktop Backgrounds
//
//  Created by Alfred Reynolds on 5/19/14.
//  Copyright (c) 2014 Alfred. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Reachability.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSComboBoxDelegate> {
	IBOutlet NSMenu *statusMenu;
	NSStatusItem * statusItem;
	bool bLoadedImage;
	NSTimer *updateTimer;
	NetworkStatus netStatus;
	bool bReloadOnNetUp;
}

@property (assign) IBOutlet NSWindow *window; // main window
@property (weak) IBOutlet NSTextFieldCell *RSSTextEdit; // text edit showing rss url we load
@property (weak) IBOutlet NSImageCell *SampleImage; // shows currently loaded background
@property (weak) IBOutlet NSComboBoxCell *ComboBoxCell; // selected rss feed type item
@property (weak) IBOutlet NSComboBox *ComboConrol; // combo pulldown for feed types
@property (retain) IBOutlet NSMutableDictionary *dictImageList; // dictionary for images we loaded from the rss feed
@property (weak) IBOutlet NSComboBox *RefreshTimeCombo; //combo for reload time of urls
@property (nonatomic) Reachability *internetReachability; // helper object for network status

- (void)parseFeedForImages:(NSData *)pageData;
- (IBAction)ChangeBackground:(id)sender;
- (IBAction)Configure:(id)sender;
- (IBAction)SetTimerFromCombo:(id)sender;
- (void)comboBoxSelectionDidChange:(NSNotification *)notification;
- (void)updateInterfaceWithReachability:(Reachability *)reachability;
- (void) reachabilityChanged:(NSNotification *)note;
- (void)dealloc;
- (void) receiveWakeNote: (NSNotification*) note;
- (void) receiveSleepNote: (NSNotification*) note;

@end


@interface LoadedURLEntry : NSObject <NSCoding> {
    NSDate *dLastUsed;
    NSNumber *nViewedCount;
}

@property (copy, nonatomic) NSDate *dLastUsed;
@property (copy, nonatomic) NSNumber *nViewedCount;

@end
