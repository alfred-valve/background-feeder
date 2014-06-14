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
-(void)parseFeedForImages:(NSData *)pageData;

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextFieldCell *RSSTextEdit;
@property (unsafe_unretained) IBOutlet NSTextView *PageText;
@property (weak) IBOutlet NSImageCell *SampleImage;
@property (weak) IBOutlet NSComboBoxCell *ComboBoxCell;
@property (weak) IBOutlet NSComboBox *ComboConrol;
@property (retain) IBOutlet NSMutableDictionary *dictImageList;
@property (weak) IBOutlet NSComboBox *RefreshTimeCombo;
@property (nonatomic) Reachability *internetReachability;

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
