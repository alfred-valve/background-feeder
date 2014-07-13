//
//  AppDelegate.m
//  RSS Desktop Backgrounds
//
//  Created by Alfred Reynolds on 5/19/14.
//  Copyright (c) 2014 Alfred. All rights reserved.
//

#import "AppDelegate.h"
#import "GDataXMLNode.h"
#import "NSDate+InternetDateTime.h"
#import "HTMLParser.h"

#define IMAGEURL_PLIST @"BackgroundLoader/Images.plist" // plist we save off the images we loaded from the rss feed
#define SETTINGS_PLIST @"BackgroundLoader/Settings.plist" // plist we save off the images we loaded from the rss feed
#define MAX_RSS_IMAGES 100

//------------------------------------------------------
// Purpose: list item to track viewed RSS items
//------------------------------------------------------
@implementation LoadedURLEntry

@synthesize dLastUsed;
@synthesize nViewedCount;
@synthesize bFavorite;

- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [super init]) {
		self.dLastUsed = [decoder decodeObjectForKey:@"lastused"];
		self.nViewedCount = [decoder decodeObjectForKey:@"viewcount"];
		self.bFavorite = [decoder decodeObjectForKey:@"favorite"];
		if ( !self.bFavorite )
			self.bFavorite = [NSNumber numberWithBool: NO ];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:dLastUsed forKey:@"lastused"];
	[encoder encodeObject:nViewedCount forKey:@"viewcount"];
	[encoder encodeObject:bFavorite forKey:@"favorite"];
}


@end


//------------------------------------------------------
// Purpose: helper for xml parsing
//------------------------------------------------------
@implementation GDataXMLElement(Extras)

- (GDataXMLElement *)elementForChild:(NSString *)childName {
    NSArray *children = [self elementsForName:childName];
    if (children.count > 0) {
        GDataXMLElement *childElement = (GDataXMLElement *) [children objectAtIndex:0];
        return childElement;
    } else return nil;
}

- (NSString *)valueForChild:(NSString *)childName {
    return [[self elementForChild:childName] stringValue];
}

@end

@implementation AppDelegate


//------------------------------------------------------
// Purpose: app full loaded, getting ready to display
//------------------------------------------------------
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	self.RefreshTimeCombo.delegate = self;
	self.ComboConrol.delegate = self;

	// setup the update timer to run
	[self SetTimerFromCombo: nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    
	//These notifications are filed on NSWorkspace's notification center, not the default
    // notification center. You will not receive sleep/wake notifications if you file
    //with the default notification center.
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
														   selector: @selector(receiveSleepNote:)
															   name: NSWorkspaceWillSleepNotification object: nil];
	
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
														   selector: @selector(receiveWakeNote:)
															   name: NSWorkspaceDidWakeNotification object: nil];
	
	self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    [self updateInterfaceWithReachability:self.internetReachability];

	// load up a new background based on our cached data
	[self ChangeBackground: self ];
	
	// now try to reload the rss feed from the web
	[self ReloadRssFeed: self ];
	
	[self.window orderOut:self];
}


//------------------------------------------------------
// Purpose: app exit
//------------------------------------------------------
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
	
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self
															   name: NSWorkspaceWillSleepNotification object: nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self
															   name: NSWorkspaceDidWakeNotification object: nil];
}


//------------------------------------------------------
// Purpose: network state change callback
//------------------------------------------------------
- (void) reachabilityChanged:(NSNotification *)note
{
    Reachability* curReach = [note object];
    [self updateInterfaceWithReachability:curReach];
}


//------------------------------------------------------
// Purpose: act based on current network state
//------------------------------------------------------
- (void)updateInterfaceWithReachability:(Reachability *)reachability
{
	NetworkStatus prevNetStatus = netStatus;
	netStatus = [reachability currentReachabilityStatus];

	if ( bReloadOnNetUp && !bReloadRSSOnNetUp )
	{
		if ( netStatus != NotReachable &&
			prevNetStatus == NotReachable )
		{
			[self ChangeBackground:nil ];
			bReloadOnNetUp = false;
		}
	}
	
	if ( bReloadRSSOnNetUp )
	{
		if ( netStatus != NotReachable &&
			prevNetStatus == NotReachable )
		{
			[self ReloadRssFeed:nil ];
			bReloadOnNetUp = false;
			bReloadRSSOnNetUp = false;
		}
	}
}


//------------------------------------------------------
// Purpose: machine is waking from sleep
//------------------------------------------------------
- (void) receiveWakeNote: (NSNotification*) note
{
	if ( netStatus == NotReachable )
	{
		netStatus = [self.internetReachability currentReachabilityStatus];
	}
	
	if ( netStatus == NotReachable )
		bReloadOnNetUp = true;
	else
		[self ChangeBackground:nil ];
	
	if ( reloadRSSDate )
	{
		// readjust the rss reload time to account for the sleep interval
		if ( [reloadRSSDate timeIntervalSinceNow] <= 0 ) // just slept for more than 24 hours, reload now
		{
			if ( netStatus == NotReachable )
				bReloadRSSOnNetUp = true;
			else
				[self ReloadRssFeed: self];
		}
		else
		{
			if ( reloadRSSTimer != nil )
				reloadRSSTimer = nil;
			
			// reload RSS once a day
			reloadRSSTimer = [NSTimer scheduledTimerWithTimeInterval: [reloadRSSDate timeIntervalSinceNow]
															  target:self
															selector:@selector(ReloadRssFeed:)
															userInfo:nil
															 repeats:NO];
		}
	}
	
	if ( updateBackgroundDate && netStatus != NotReachable )
	{
		// readjust the rss reload time to account for the sleep interval
		if ( [updateBackgroundDate timeIntervalSinceNow] <= 0 ) // just slept for more than 24 hours, reload now
			[self ChangeBackground: self]; //
		else
		{
			if ( updateTimer != nil )
				updateTimer = nil;
			
			// fixup background change timer too
			updateTimer = [NSTimer scheduledTimerWithTimeInterval: [updateBackgroundDate timeIntervalSinceNow]
															  target:self
															selector:@selector(ChangeBackground:)
															userInfo:nil
															 repeats:NO];
		}
		
	}
}


//------------------------------------------------------
// Purpose: machine is going to sleep
//------------------------------------------------------
- (void) receiveSleepNote: (NSNotification*) note
{
	netStatus = NotReachable;
}


//------------------------------------------------------
// Purpose: reload the current RSS feed off the network
//------------------------------------------------------
- (IBAction)ReloadRssFeed:(id)sender
{
	if ( netStatus != NotReachable )
	{
		[self LoadRSSFeed];
	}
	else
		bReloadRSSOnNetUp = true;
	
	if ( reloadRSSTimer != nil )
		reloadRSSTimer = nil;
	
	// reload RSS once a day
	reloadRSSTimer = [NSTimer scheduledTimerWithTimeInterval: 24*60*60
												   target:self
												 selector:@selector(ReloadRssFeed:)
												 userInfo:nil
												  repeats:NO];
	// also write down the wall clock time we expect to reload on, so we can track this when we wake from sleep
	reloadRSSDate = [NSDate dateWithTimeIntervalSinceNow:24*60*60];
}


//------------------------------------------------------
// Purpose: load a new background image from the current rss feed
//------------------------------------------------------
- (IBAction) ChangeBackground:(id)sender
{
	if ( !self.dictImageList )
		return;
	
	// if we have no items loaded (a new install most likely) then reload the rss feed right now
	if ( self.dictImageList.count == 0 )
	{
		[self ReloadRssFeed:self ];
		return;
	}
	
	id loadItemKey;
	LoadedURLEntry *entryToLoad = nil;
	int nViewCountToUse = 0;
	while ( !entryToLoad && nViewCountToUse < 100 )
	{
		NSEnumerator *enumerator = [self.dictImageList keyEnumerator];
		id key;
		while ((key = [enumerator nextObject])) {
			LoadedURLEntry *entry = [self.dictImageList objectForKey:key];
			if ( [entry.nViewedCount intValue] == nViewCountToUse &&
				(!entryToLoad || [[entry dLastUsed] compare: [entryToLoad dLastUsed]] == NSOrderedAscending ) )
			{
				loadItemKey = key;
				entryToLoad = entry;
			}
		}
		nViewCountToUse++;
	}

	if ( ![self loadImage: loadItemKey ] )
	{
		// failed to load image, just delete the entry and grab a new one
		[self.dictImageList removeObjectForKey:loadItemKey];
		[self ChangeBackground:sender]; // call ourselves again with the new image list
		return;
	}
	
	entryToLoad.dLastUsed = [NSDate date];
	entryToLoad.nViewedCount = [NSNumber numberWithInt:([entryToLoad.nViewedCount intValue] + 1) ];

	if ( [entryToLoad.bFavorite boolValue ] == YES )
		[self.FavoriteMenuItem setState:NSOnState];
	else
		[self.FavoriteMenuItem setState:NSOffState];
	
	[self clearOldImageListEntriesIfNeeded];
	[self saveImageDictToPlist];
}
	

//------------------------------------------------------
// Purpose: save off our current image diction to disk
//------------------------------------------------------
- (void) saveImageDictToPlist
{
	// now save off the plist
	if ( self.dictImageList.count > 0 )
	{
		NSError *saveError;
		NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString *plistPath = [rootPath stringByAppendingPathComponent:IMAGEURL_PLIST];
		
		if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
			[[NSFileManager defaultManager] createDirectoryAtPath:[plistPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
		}
		
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.dictImageList];
		
		NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:data
																	   format:NSPropertyListXMLFormat_v1_0
																	  options:0 error:&saveError];
		
		//[self.dictImageList writeToFile:plistPath atomically:YES ];
		if(plistData) {
			[plistData writeToFile:plistPath atomically:YES];
		}
		else {
			NSLog( @"%@", saveError);
		}
	}

	// reset the load timer
	[self SetTimerFromCombo: self ];
}


//------------------------------------------------------
// Purpose: delete the currently displayed background
//------------------------------------------------------
- (IBAction)deleteBackground:(id)sender {

	if ( imageURLCurrent )
	{
		[self.dictImageList removeObjectForKey:imageURLCurrent];
		imageURLCurrent = nil;
		[self ChangeBackground:sender];
	}
}


//------------------------------------------------------
// Purpose: run at login toggled
//------------------------------------------------------
- (IBAction)RunAtLoginChecked:(id)sender {
	if ( [self.RunAtLoginCheck state] == NSOnState )
	{
		[self setLaunchAtStartup:true];
	}
	else
	{
		[self setLaunchAtStartup:false];
	}
}


//------------------------------------------------------
// Purpose: delete entries from dictionary of images till we
//   get under our storage limit
//------------------------------------------------------
-(void)clearOldImageListEntriesIfNeeded
{
	// while we have too many entries
	while ( self.dictImageList.count > MAX_RSS_IMAGES )
	{
		NSEnumerator *enumerator = [self.dictImageList keyEnumerator];
		id key;
		id oldestItemKey;
		LoadedURLEntry *entryToDelete = nil;
		// find the currently oldest entry
		while ((key = [enumerator nextObject])) {
			LoadedURLEntry *entry = [self.dictImageList objectForKey:key];
			if ( !entryToDelete || (
					[[entry dLastUsed] compare: [entryToDelete dLastUsed]] == NSOrderedAscending
						&& (entry.bFavorite == nil ||  [entry.bFavorite boolValue] == NO ) ) )
			{ // we have no entry OR this one is older AND it isn't a favorite (or doesn't have a favorite number due to older plist entry
				oldestItemKey = key;
				entryToDelete = entry;
			}
		}
		
		// no item to delete, all favorites perhaps? Just bail
		if ( !entryToDelete )
			break;
		
		[self.dictImageList removeObjectForKey:oldestItemKey];
	}
}


//------------------------------------------------------
// Purpose: app is starting
//------------------------------------------------------
-(void)awakeFromNib{
	
	updateTimer = nil;
	reloadRSSTimer = nil;
	netStatus = NotReachable;
	bReloadOnNetUp = false;
	bReloadRSSOnNetUp = false;
	reloadRSSDate = nil;
	updateBackgroundDate = nil;
	imageURLCurrent = nil;
	imageURLPrevious = nil;
	
	NSString *errorDesc = nil;
	NSPropertyListFormat format;
	NSString *plistPath;
	NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
															  NSUserDomainMask, YES) objectAtIndex:0];

	// load up the saved list of images
	plistPath = [rootPath stringByAppendingPathComponent:IMAGEURL_PLIST];
	if ( [[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
		NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:plistPath];
		NSData *pUnarch = [NSPropertyListSerialization
												 propertyListFromData:plistXML
												 mutabilityOption:NSPropertyListMutableContainersAndLeaves
												 format:&format
												 errorDescription:&errorDesc];
	
		NSMutableDictionary *pData = [NSKeyedUnarchiver unarchiveObjectWithData:pUnarch];
		self.dictImageList = pData;
	}
	
	if (!self.dictImageList) {
		self.dictImageList = [[NSMutableDictionary alloc] init];
	}
	
	// load up our saves settings for rss feed to load and timer setting
	plistPath = [rootPath stringByAppendingPathComponent:SETTINGS_PLIST];
	if ([[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
		NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:plistPath];
		NSDictionary *temp = (NSDictionary *)[NSPropertyListSerialization
					   propertyListFromData:plistXML
					   mutabilityOption:NSPropertyListMutableContainersAndLeaves
					   format:&format
					   errorDescription:&errorDesc];
	
		[self.ComboConrol selectItemAtIndex: [[temp objectForKey:@"feedtype"] intValue] ];
		[self.RefreshTimeCombo selectItemAtIndex: [[temp objectForKey:@"reloadtime"] intValue] ];
		lastRSSFeedLoadtime  = [temp objectForKey:@"lastrssload"];
	}
	else
	{
		[self.ComboConrol selectItemAtIndex: 0 ];
		[self.RefreshTimeCombo selectItemAtIndex: 1 ];
	}
	
	if ( !lastRSSFeedLoadtime )
		lastRSSFeedLoadtime = [NSDate date];
	
	NSString *dateString = [NSDateFormatter localizedStringFromDate:lastRSSFeedLoadtime
														  dateStyle:NSDateFormatterMediumStyle
														  timeStyle:NSDateFormatterShortStyle];
	
	[self.RSSLastLoadedLabel setStringValue:dateString];
	[self.RunAtLoginCheck setState: [self isLaunchAtStartup] ? NSOnState : NSOffState];
	
	// Now setup the status bar item
	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	[statusItem setMenu:statusMenu];

	NSString *imageString = [[NSBundle mainBundle] pathForResource:@"raeddit64x64" ofType:@"png"];
	NSImage * picture =  [[NSImage alloc] initWithContentsOfFile:imageString ];
	[picture setScalesWhenResized: YES];
	[picture setSize: NSMakeSize(24, 24)];
	[statusItem setImage:picture];
	[statusItem setHighlightMode:YES];
}


//------------------------------------------------------
// Purpose: save ui settings state to our plist
//------------------------------------------------------
- (void) saveSettings
{
	NSString *error;
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [rootPath stringByAppendingPathComponent:SETTINGS_PLIST];

	if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
		[[NSFileManager defaultManager] createDirectoryAtPath:[plistPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
	}

	NSDictionary *plistDict = [NSDictionary dictionaryWithObjects:
							   [NSArray arrayWithObjects: [NSNumber numberWithInteger:[self.ComboConrol indexOfSelectedItem]], [NSNumber numberWithInteger:[self.RefreshTimeCombo indexOfSelectedItem]], lastRSSFeedLoadtime, nil]
														  forKeys:[NSArray arrayWithObjects: @"feedtype", @"reloadtime", @"lastrssload", nil]];
    NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:plistDict
																   format:NSPropertyListXMLFormat_v1_0
														 errorDescription:&error];
    if(plistData) {
        [plistData writeToFile:plistPath atomically:YES];
    }
	else {
		NSLog( @"Error: %@", error );
	}
}


//------------------------------------------------------
// Purpose: show the config dialog
//------------------------------------------------------
- (IBAction)Configure:(id)sender
{
	[self.window makeKeyAndOrderFront:sender];
}


//------------------------------------------------------
// Purpose: mark the currently show desktop image with the favorite tag
//------------------------------------------------------
- (IBAction)MarkAsFavorite:(id)sender
{
	LoadedURLEntry *entry = [self.dictImageList objectForKey: imageURLCurrent];

	if ( entry )
	{
		if ( [entry.bFavorite boolValue] == NO )
		{
			[self.FavoriteMenuItem setState:NSOnState];
			entry.bFavorite = [NSNumber numberWithBool: YES ];
		}
		else
		{
			entry.bFavorite = [NSNumber numberWithBool: NO ];
			[self.FavoriteMenuItem setState:NSOffState];
		}
	}
	[self saveImageDictToPlist];
}


//------------------------------------------------------
// Purpose: mark the currently show desktop image with the favorite tag
//------------------------------------------------------
- (IBAction)previousBackground:(id)sender
{
	if ( imageURLPrevious )
	{
		[self loadImage: imageURLPrevious];
		imageURLPrevious = nil;
		
		LoadedURLEntry *entry = [self.dictImageList objectForKey: imageURLCurrent];
		if ( entry )
		{
			entry.dLastUsed = [NSDate date];
			// don't increment view count

			if ( [entry.bFavorite boolValue ] == YES )
				[self.FavoriteMenuItem setState:NSOnState];
			else
				[self.FavoriteMenuItem setState:NSOffState];
		}
	}
	[self saveImageDictToPlist];

}


//------------------------------------------------------
// Purpose: read combo for reload time on background and set a timer
//------------------------------------------------------
- (IBAction)SetTimerFromCombo:(id)sender
{
	if ( updateTimer != nil )
		[updateTimer invalidate];
	updateTimer = nil;
	
	uint32_t nWaitTime = 0;
	int64_t selitem = [self.RefreshTimeCombo indexOfSelectedItem];
	switch ( selitem )
	{
		case 0:
			nWaitTime = 60*10;
			break;
		case 1:
			nWaitTime = 60*60;
			break;
		case 2:
			nWaitTime = 60*60*24;
			break;
		default:
			return;
	}
	
	updateTimer = [NSTimer scheduledTimerWithTimeInterval: nWaitTime
												   target:self
												 selector:@selector(ChangeBackground:)
												 userInfo:nil
												  repeats:NO];
	
	updateBackgroundDate = [NSDate dateWithTimeIntervalSinceNow:nWaitTime];
}
	

//------------------------------------------------------
// Purpose: combo box changed
//------------------------------------------------------
- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
	NSComboBox *comboBox = (NSComboBox *)[notification object];
	if ( comboBox == self.RefreshTimeCombo )
		[self SetTimerFromCombo: nil];
	else if ( comboBox == self.ComboConrol )
	{
		self.dictImageList = nil; // clear the current dictionary of images and reload from scratch
		self.dictImageList = [[NSMutableDictionary alloc] init];
		[self ReloadRssFeed: self];
	}
	
	[self saveSettings];
}


//------------------------------------------------------
// Purpose: nibble the first bytes of an image file and determine its likely file type
//------------------------------------------------------
- (NSString *)contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
	
    switch (c) {
        case 0xFF:
			return @".jpg";
        case 0x89:
			return @".png";
        case 0x47:
			return @".gif";
        case 0x49:
            break;
        case 0x42:
            return @".bmp";
        case 0x4D:
            return @".tiff";
    }
    return nil;
}


//------------------------------------------------------
// Purpose: given a URL to an image load it as a background image and record it in our loaded plist
//------------------------------------------------------
- (bool)loadImage:(NSString *)urlToLoad
{
	NSURL *imageURL = [NSURL URLWithString:urlToLoad];
	NSMutableDictionary *screenOptions =
	[[[NSWorkspace sharedWorkspace] desktopImageOptionsForScreen:[NSScreen mainScreen]] mutableCopy];
	
	NSNumber *allowClipping = [NSNumber numberWithBool:true];
	
	// replace out the old clip value with the new
	[screenOptions setObject:allowClipping forKey:NSWorkspaceDesktopImageAllowClippingKey];
		
	NSURLRequest *urlRequst = [NSURLRequest requestWithURL:imageURL];
	
	bool __block bLoadSuccessful = false;
	
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
	dispatch_sync(queue, ^{
		NSURLResponse *response = nil;
		NSError *error = nil;
		
		NSData *receivedData = [NSURLConnection sendSynchronousRequest:urlRequst
													 returningResponse:&response
																 error:&error];
		
		(void)[self.SampleImage initImageCell:[[NSImage alloc] initWithData:receivedData] ];
		
		NSString *docsDir;
		NSArray *dirPaths;
		
		dirPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		docsDir = [dirPaths objectAtIndex:0];
		NSString *targetPrefix = [[NSString alloc] initWithString: [docsDir stringByAppendingPathComponent:@"screen"]];
		NSString *imageExt = [self contentTypeForImageData: receivedData];
		if ( imageExt != nil )
		{
			NSString * targetPath = [targetPrefix stringByAppendingString: imageExt ];
			
			if ( [[NSFileManager defaultManager] fileExistsAtPath:targetPath ] )
			{
				[[NSFileManager defaultManager] removeItemAtPath:targetPath error:&error];
				targetPath = [targetPrefix stringByAppendingString: @"1" ];
				targetPath = [targetPath stringByAppendingString: [self contentTypeForImageData: receivedData] ];
			}
			
			[[NSFileManager defaultManager] removeItemAtPath:targetPath error:&error];
			[receivedData writeToFile:targetPath atomically:YES];
			
			NSURL *fileURL = [NSURL fileURLWithPath:targetPath];
			
			[[NSWorkspace sharedWorkspace] setDesktopImageURL:fileURL
													forScreen:[NSScreen mainScreen]
													  options:screenOptions
														error:&error];
			imageURLPrevious = imageURLCurrent;
			imageURLCurrent = urlToLoad;
			bLoadSuccessful = true;
			
		}
	});
	
	return bLoadSuccessful;
}


//------------------------------------------------------
// Purpose: parse an rss feed from loaded xml data
//------------------------------------------------------
- (void)parseRss:(GDataXMLElement *)rootElement {
	NSArray *channels = [rootElement elementsForName:@"channel"];
    for (GDataXMLElement *channel in channels) {
        
//        NSString *blogTitle = [channel valueForChild:@"title"];
        
        NSArray *items = [channel elementsForName:@"item"];
        for (GDataXMLElement *item in items) {
            
           // NSString *articleTitle = [item valueForChild:@"title"];
           // NSString *articleUrl = [item valueForChild:@"link"];
            NSString *articleDateString = [item valueForChild:@"pubDate"];
            NSDate *articleDate = [NSDate dateFromInternetDateTimeString:articleDateString formatHint:DateFormatHintRFC822];
            NSString *description = [item valueForChild:@"description"];
            
			NSError *error;
			HTMLParser *parser = [[HTMLParser alloc] initWithString:description error:&error];
			
			if (error) {
				NSLog(@"Error: %@", error);
				return;
			}
			
			HTMLNode *bodyNode = [parser body];
			NSArray *links = [bodyNode findChildTags:@"a"];
			
			for (HTMLNode *link in links) {
				if ( [[link contents] isEqualToString:@"[link]" ] )
				{
					NSString *pchExt = [link getAttributeNamed:@"href"];
					if ( [pchExt hasSuffix:@".jpg" ] || [pchExt hasSuffix:@".png" ] )
					{
						LoadedURLEntry *entry  = [self.dictImageList valueForKey:[link getAttributeNamed:@"href"] ];
						if ( !entry )
						{
							entry = [LoadedURLEntry alloc];
							entry.dLastUsed = articleDate;
							entry.nViewedCount = [NSNumber numberWithInt:0 ];
							entry.bFavorite = [NSNumber numberWithBool:NO ];
							[self.dictImageList setObject:entry forKey:[link getAttributeNamed:@"href"] ];
						}
					}
				}
			} // for( HTMLNode)
        }
    }
	
	NSString *dateString = [NSDateFormatter localizedStringFromDate:[NSDate date]
														  dateStyle:NSDateFormatterMediumStyle
														  timeStyle:NSDateFormatterShortStyle];

	[self.RSSLastLoadedLabel setStringValue:dateString];
}


//------------------------------------------------------
// Purpose: parse an atom style feed from a loaded xml document
//------------------------------------------------------
- (void)parseAtom:(GDataXMLElement *)rootElement {
}


//------------------------------------------------------
// Purpose: parse a loaded xml document
//------------------------------------------------------
- (void)parseFeed:(GDataXMLElement *)rootElement  {
    if ([rootElement.name compare:@"rss"] == NSOrderedSame) {
        [self parseRss:rootElement];
    } else if ([rootElement.name compare:@"feed"] == NSOrderedSame) {
        [self parseAtom:rootElement];
    } else {
        NSLog(@"Unsupported root element: %@", rootElement.name);
    }
}


//------------------------------------------------------
// Purpose: load a feed from page data we got back from a http call
//------------------------------------------------------
-(void)parseFeedForImages:(NSData *)pageData
{
	NSError *error;
	GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:pageData
														   options:0 error:&error];
	
	if (doc == nil) {
		NSLog(@"Failed to parse feed");
	} else {
		[self parseFeed:doc.rootElement];
		[self ChangeBackground:self]; // now load a new background
	}

}


//------------------------------------------------------
// Purpose: load the configured RSS feed
//------------------------------------------------------
- (void)LoadRSSFeed {
	if ( [self.ComboConrol indexOfSelectedItem] >= 0 )
	{
		NSString *RSSFeedText = [[NSString alloc] initWithFormat:@"http://www.reddit.com/r/%@Porn/.rss", [self.ComboConrol objectValueOfSelectedItem]];
		NSURL *feedURL = [NSURL URLWithString:RSSFeedText];
		NSURLRequest *urlRequst = [NSURLRequest requestWithURL:feedURL];
		
		dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
		dispatch_async(queue, ^{
			NSURLResponse *response = nil;
			NSError *error = nil;
			NSData *receivedData = [NSURLConnection sendSynchronousRequest:urlRequst
														 returningResponse:&response
																	 error:&error];
			
			[self parseFeedForImages: receivedData];
			
		});
	}
}


//------------------------------------------------------
// Purpose: return true if we are set to a login item
//------------------------------------------------------
- (BOOL)isLaunchAtStartup {
    // See if the app is currently in LoginItems.
    LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
    // Store away that boolean.
    BOOL isInList = itemRef != nil;
    // Release the reference if it exists.
    if (itemRef != nil) CFRelease(itemRef);
	
    return isInList;
}


//------------------------------------------------------
// Purpose: turn on or off launching at login
//------------------------------------------------------
- (void)setLaunchAtStartup:(bool)bLaunchAtStartup {
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return;
    if (bLaunchAtStartup && ![self isLaunchAtStartup]) {
        // Add the app to the LoginItems list.
        CFURLRef appUrl = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, appUrl, NULL, NULL);
        if (itemRef) CFRelease(itemRef);
    }
    else if ( !bLaunchAtStartup && [self isLaunchAtStartup] ){
        // Remove the app from the LoginItems list.
        LSSharedFileListItemRef itemRef = [self itemRefInLoginItems];
        LSSharedFileListItemRemove(loginItemsRef,itemRef);
        if (itemRef != nil) CFRelease(itemRef);
    }
    CFRelease(loginItemsRef);
}


//------------------------------------------------------
// Purpose: helper to find us in the login items
//------------------------------------------------------
- (LSSharedFileListItemRef)itemRefInLoginItems {
    LSSharedFileListItemRef res = nil;
	
    // Get the app's URL.
    NSURL *bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    // Get the LoginItems list.
    LSSharedFileListRef loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItemsRef == nil) return nil;
    // Iterate over the LoginItems.
    NSArray *loginItems = (__bridge NSArray *)LSSharedFileListCopySnapshot(loginItemsRef, nil);
    for (id item in loginItems) {
        LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)(item);
        CFURLRef itemURLRef;
        if (LSSharedFileListItemResolve(itemRef, 0, &itemURLRef, NULL) == noErr) {
            // Again, use toll-free bridging.
            NSURL *itemURL = (__bridge NSURL *)itemURLRef;
            if ([itemURL isEqual:bundleURL]) {
                res = itemRef;
                break;
            }
        }
    }
    // Retain the LoginItem reference.
    if (res != nil) CFRetain(res);
    CFRelease(loginItemsRef);
    CFRelease((__bridge CFTypeRef)(loginItems));
	
    return res;
}


//------------------------------------------------------
// Purpose: stay on this image until unpaused
//------------------------------------------------------
- (IBAction)PauseBackground:(id)sender {
	if ( [self.PauseMenuItem state] != NSOnState )
	{
		updateBackgroundDate = nil;
		[updateTimer invalidate];
		updateTimer = nil;
		[self.PauseMenuItem setState: NSOnState];
	}
	else
	{
		[self SetTimerFromCombo: self];
		[self.PauseMenuItem setState: NSOffState];
	}
}

@end
