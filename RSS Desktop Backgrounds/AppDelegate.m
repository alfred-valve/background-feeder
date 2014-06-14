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

#define IMAGEURL_PLIST @"Images.plist"

@implementation LoadedURLEntry

@synthesize dLastUsed;
@synthesize nViewedCount;

- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [super init]) {
		self.dLastUsed = [decoder decodeObjectForKey:@"lastused"];
		self.nViewedCount = [decoder decodeObjectForKey:@"viewcount"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:dLastUsed forKey:@"lastused"];
	[encoder encodeObject:nViewedCount forKey:@"viewcount"];
}


@end


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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	updateTimer = nil;
	netStatus = NotReachable;
	bReloadOnNetUp = false;
	
	[self.ComboConrol selectItemAtIndex: 0 ];
	[self.RefreshTimeCombo selectItemAtIndex: 1 ];
	self.RefreshTimeCombo.delegate = self;

	[self SetTimerFromCombo: nil];

	id key = [[self.dictImageList allKeys] objectAtIndex:0]; // Assumes 'message' is not empty
	[self loadImage: key ];

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

	[self.window orderOut:self];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
	
	//These notifications are filed on NSWorkspace's notification center, not the default
    // notification center. You will not receive sleep/wake notifications if you file
    //with the default notification center.
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self
															   name: NSWorkspaceWillSleepNotification object: nil];
	
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver: self
															   name: NSWorkspaceDidWakeNotification object: nil];
	
}



- (void) reachabilityChanged:(NSNotification *)note
{
    Reachability* curReach = [note object];
    [self updateInterfaceWithReachability:curReach];
}


- (void)updateInterfaceWithReachability:(Reachability *)reachability
{
	if ( bReloadOnNetUp )
	{
		if ( netStatus == NotReachable &&
			[reachability currentReachabilityStatus] != NotReachable )
		{
			[self ChangeBackground:nil ];
		}
	}
	netStatus = [reachability currentReachabilityStatus];
}


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
}

- (void) receiveSleepNote: (NSNotification*) note
{
	netStatus = NotReachable;
}



- (IBAction)ChangeBackground:(id)sender
{
	if ( netStatus != NotReachable )
		[self LoadRSSFeed: sender];
	else
		bReloadOnNetUp = true;
}

-(void)awakeFromNib{
	NSString *errorDesc = nil;
	NSPropertyListFormat format;
	NSString *plistPath;
	NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
															  NSUserDomainMask, YES) objectAtIndex:0];
	plistPath = [rootPath stringByAppendingPathComponent:IMAGEURL_PLIST];
	if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
		plistPath = [[NSBundle mainBundle] pathForResource:@"Data" ofType:@"plist"];
	}
	NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:plistPath];
	
	NSData *pUnarch = [NSPropertyListSerialization
												 propertyListFromData:plistXML
												 mutabilityOption:NSPropertyListMutableContainersAndLeaves
												 format:&format
												 errorDescription:&errorDesc];
	
	NSMutableDictionary *pData = [NSKeyedUnarchiver unarchiveObjectWithData:pUnarch];
	self.dictImageList = pData;
	if (!self.dictImageList) {
		self.dictImageList = [[NSMutableDictionary alloc] init];
	}
		
	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	[statusItem setMenu:statusMenu];

	NSString *imageString = [[NSBundle mainBundle] pathForResource:@"raeddit64x64" ofType:@"png"];
	NSImage * picture =  [[NSImage alloc] initWithContentsOfFile:imageString ];
	[picture setScalesWhenResized: YES];
	[picture setSize: NSMakeSize(24, 24)];
	[statusItem setImage:picture];
	[statusItem setHighlightMode:YES];
}


- (void)appendToMyTextView:(NSString*)text
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:text];
		
        [[self.PageText textStorage] appendAttributedString:attr];
        [self.PageText scrollRangeToVisible:NSMakeRange([[self.PageText string] length], 0)];
    });
}


- (IBAction)Configure:(id)sender
{
	[self.window makeKeyAndOrderFront:sender];
}

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
												  repeats:YES];
}
	

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
	[self SetTimerFromCombo: nil];
}

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

- (void)loadImage:(NSString *)urlToLoad
{
	NSURL *imageURL = [NSURL URLWithString:urlToLoad];
	
	
	NSMutableDictionary *screenOptions =
	[[[NSWorkspace sharedWorkspace] desktopImageOptionsForScreen:[NSScreen mainScreen]] mutableCopy];
	
	NSNumber *allowClipping = [NSNumber numberWithBool:true];
	
	// replace out the old clip value with the new
	[screenOptions setObject:allowClipping forKey:NSWorkspaceDesktopImageAllowClippingKey];
	
	
	NSURLRequest *urlRequst = [NSURLRequest requestWithURL:imageURL];
	
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
		
		dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
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
			
			bLoadedImage = true;
		}
		
	});

}

- (void)parseRss:(GDataXMLElement *)rootElement {
    
	bLoadedImage = false;
    NSArray *channels = [rootElement elementsForName:@"channel"];
    for (GDataXMLElement *channel in channels) {
        
//        NSString *blogTitle = [channel valueForChild:@"title"];
        
        NSArray *items = [channel elementsForName:@"item"];
        for (GDataXMLElement *item in items) {
            
           // NSString *articleTitle = [item valueForChild:@"title"];
           // NSString *articleUrl = [item valueForChild:@"link"];
           // NSString *articleDateString = [item valueForChild:@"pubDate"];
           // NSDate *articleDate = [NSDate dateFromInternetDateTimeString:articleDateString formatHint:DateFormatHintRFC822];
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
					[self appendToMyTextView:[link getAttributeNamed:@"href"]];
					NSString *pchExt = [link getAttributeNamed:@"href"];
					if ( [pchExt hasSuffix:@".jpg" ] || [pchExt hasSuffix:@".png" ] )
					{
						if ( !bLoadedImage )
						{
							[self loadImage: [link getAttributeNamed:@"href"] ];
						}
						
						LoadedURLEntry *entry  = [self.dictImageList valueForKey:[link getAttributeNamed:@"href"] ];
						if ( !entry )
						{
							entry = [LoadedURLEntry alloc];
							entry.dLastUsed = [NSDate date];
							entry.nViewedCount = 0;
							[self.dictImageList setObject:entry forKey:[link getAttributeNamed:@"href"] ];
						}
						else
						{
							entry.dLastUsed = [NSDate date];
							entry.nViewedCount =  [NSNumber numberWithInt:[entry.nViewedCount intValue] +1];
						}
						
					}
				}
			} // for( HTMLNode)
			
        }
		
    }
	
	if ( self.dictImageList.count > 0 )
	{
		// now save off the plist
		NSError *saveError;
		NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString *plistPath = [rootPath stringByAppendingPathComponent:IMAGEURL_PLIST];
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

    
}

- (void)parseAtom:(GDataXMLElement *)rootElement {
    
   /* NSString *blogTitle = [rootElement valueForChild:@"title"];
    
    NSArray *items = [rootElement elementsForName:@"entry"];
    for (GDataXMLElement *item in items) {
        
        NSString *articleTitle = [item valueForChild:@"title"];
        NSString *articleUrl = nil;
        NSArray *links = [item elementsForName:@"link"];
        for(GDataXMLElement *link in links) {
            NSString *rel = [[link attributeForName:@"rel"] stringValue];
            NSString *type = [[link attributeForName:@"type"] stringValue];
            if ([rel compare:@"alternate"] == NSOrderedSame &&
                [type compare:@"text/html"] == NSOrderedSame) {
                articleUrl = [[link attributeForName:@"href"] stringValue];
            }
        }
        
        NSString *articleDateString = [item valueForChild:@"updated"];
        NSDate *articleDate = [NSDate dateFromInternetDateTimeString:articleDateString formatHint:DateFormatHintRFC3339];
        
        RSSEntry *entry = [[[RSSEntry alloc] initWithBlogTitle:blogTitle
                                                  articleTitle:articleTitle
                                                    articleUrl:articleUrl
                                                   articleDate:articleDate] autorelease];
        [entries addObject:entry];
        
    }*/
    
}



- (void)parseFeed:(GDataXMLElement *)rootElement  {
    if ([rootElement.name compare:@"rss"] == NSOrderedSame) {
        [self parseRss:rootElement];
    } else if ([rootElement.name compare:@"feed"] == NSOrderedSame) {
        [self parseAtom:rootElement];
    } else {
        NSLog(@"Unsupported root element: %@", rootElement.name);
    }
}


-(void)parseFeedForImages:(NSData *)pageData
{
//	NSString *someString = [[NSString alloc] initWithData:pageData encoding:NSASCIIStringEncoding];
//	[self.PageText setString:someString];
	
	NSError *error;
	GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:pageData
														   options:0 error:&error];
	
	if (doc == nil) {
		NSLog(@"Failed to parse feed");
	} else {
		
		[self parseFeed:doc.rootElement];
	}

}

- (IBAction)LoadRSSFeed:(id)sender {
	//NSString *RSSFeedText = [self.RSSTextEdit stringValue];
	NSString *RSSFeedText = [[NSString alloc] initWithFormat:@"http://www.reddit.com/r/%@Porn/.rss", [self.ComboBoxCell stringValue]];
/*	NSAlert *alert = [NSAlert alertWithMessageText: @"Feed"
									 defaultButton:@"OK"
									alternateButton:nil
									   otherButton:nil
						 informativeTextWithFormat:@"%@", RSSFeedText ];
	[alert runModal];*/
	
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


@end
