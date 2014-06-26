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
	NSTimer *updateTimer;
	NSDate *updateBackgroundDate;
	NSTimer *reloadRSSTimer;
	NSDate *reloadRSSDate;
	NetworkStatus netStatus;
	bool bReloadOnNetUp;
	bool bReloadRSSOnNetUp;
	NSString *imageURLCurrent;
	NSString *imageURLPrevious;
	NSDate *lastRSSFeedLoadtime;
}

@property (assign) IBOutlet NSWindow *window; // main window
@property (weak) IBOutlet NSTextFieldCell *RSSTextEdit; // text edit showing rss url we load
@property (weak) IBOutlet NSImageCell *SampleImage; // shows currently loaded background
@property (weak) IBOutlet NSComboBox *ComboConrol; // combo pulldown for feed types
@property (retain) IBOutlet NSMutableDictionary *dictImageList; // dictionary for images we loaded from the rss feed
@property (weak) IBOutlet NSComboBox *RefreshTimeCombo; //combo for reload time of urls
@property (nonatomic) Reachability *internetReachability; // helper object for network status
@property (weak) IBOutlet NSMenuItem *FavoriteMenuItem;
@property (weak) IBOutlet NSTextField *RSSLastLoadedLabel;
@property (weak) IBOutlet NSButton *RunAtLoginCheck;
@property (weak) IBOutlet NSMenuItem *PauseMenuItem;

- (void) parseFeedForImages:(NSData *)pageData;
- (IBAction) ReloadRssFeed:(id)sender;
- (IBAction) ChangeBackground:(id)sender;
- (IBAction) Configure:(id)sender;
- (IBAction) SetTimerFromCombo:(id)sender;
- (void) LoadRSSFeed;
- (void) comboBoxSelectionDidChange:(NSNotification *)notification;
- (void) updateInterfaceWithReachability:(Reachability *)reachability;
- (void) reachabilityChanged:(NSNotification *)note;
- (void)applicationWillTerminate:(NSNotification *)aNotification;
- (void) receiveWakeNote: (NSNotification*) note;
- (void) receiveSleepNote: (NSNotification*) note;
- (void) saveSettings;
- (IBAction)MarkAsFavorite:(id)sender;
- (void) clearOldImageListEntriesIfNeeded;
- (IBAction)previousBackground:(id)sender;
- (bool)loadImage:(NSString *)urlToLoad;
- (void) saveImageDictToPlist;
- (IBAction)deleteBackground:(id)sender;
- (IBAction)RunAtLoginChecked:(id)sender;
- (BOOL)isLaunchAtStartup;
- (void)setLaunchAtStartup:(bool)bLaunchAtStartup;
- (LSSharedFileListItemRef)itemRefInLoginItems;
- (IBAction)PauseBackground:(id)sender;
@end


@interface LoadedURLEntry : NSObject <NSCoding> {
    NSDate *dLastUsed;
    NSNumber *nViewedCount;
	NSNumber *bFavorite;
}

@property (copy, nonatomic) NSDate *dLastUsed;
@property (copy, nonatomic) NSNumber *nViewedCount;
@property (copy, nonatomic) NSNumber *bFavorite;

@end
