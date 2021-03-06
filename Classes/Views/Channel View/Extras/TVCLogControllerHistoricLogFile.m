/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Textual and/or "Codeux Software, LLC", nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

#import "TextualApplication.h"

#import "HLSHistoricLogProtocol.h"

#import "TVCLogLineXPCPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCLogControllerHistoricLogFile ()
@property (nonatomic, assign, readwrite) BOOL isSaving;
@property (nonatomic, assign, readwrite) BOOL isTerminating;
@property (nonatomic, assign, readwrite) BOOL processLoaded;
@property (nonatomic, assign, readwrite) BOOL processLoading;
@property (nonatomic, strong) NSXPCConnection *serviceConnection;
@property (nonatomic, assign) BOOL connectionInvalidatedVoluntarily;
@property (nonatomic, assign) BOOL connectionInvalidatedErrorDialogDisplayed;
@property (nonatomic, copy, nullable) NSError *lastServiceConnectionError;
@end

@implementation TVCLogControllerHistoricLogFile

+ (TVCLogControllerHistoricLogFile *)sharedInstance
{
	static id sharedSelf = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedSelf = [[self alloc] init];
	});

	return sharedSelf;
}

#pragma mark -
#pragma mark Save Path

- (void)resetDatabaseSavePath
{
	NSString *filename = [NSString stringWithFormat:@"logControllerHistoricLog_%@.sqlite", [NSString stringWithUUID]];

	[RZUserDefaults() setObject:filename forKey:@"TVCLogControllerHistoricLogFileSavePath_v3"];
}

- (NSString *)databaseSavePath
{
	NSString *filename = [RZUserDefaults() objectForKey:@"TVCLogControllerHistoricLogFileSavePath_v3"];

	if (filename == nil) {
		[self resetDatabaseSavePath];

		return [self databaseSavePath];
	}

	NSString *sourcePath = [TPCPathInfo applicationCachesFolderInsideGroupContainerPath];

	return [sourcePath stringByAppendingPathComponent:filename];
}

#pragma mark -
#pragma mark Construction

- (void)warmProcessIfNeeded
{
	if (self.processLoading || self.processLoaded) {
		return;
	}

	LogToConsoleDebug("Warming process...");

	self.processLoading = YES;

	[self connectToService];

	[self openDatabase];

	[self setupTimers];
}

- (void)invalidateProcess
{
	LogToConsoleDebug("Invaliating process...");

	self.connectionInvalidatedVoluntarily = YES;

	[self.serviceConnection invalidate];
}

- (void)openDatabase
{
	[[self remoteObjectProxyWithErrorHandler:^(NSError *error) {
		self.processLoading = NO;
		self.processLoaded = NO;

		LogToConsoleError("Failed to communicate with process to open database");
	}] openDatabaseAtPath:[self databaseSavePath] withCompletionBlock:^(BOOL success) {
		if (success) {
			LogToConsoleDebug("Successfully opened database");
		} else {
			LogToConsoleError("Failed to open database");
		}

		self.processLoading = NO;
		self.processLoaded = success;
	}];
}

- (void)connectToService
{
	NSXPCConnection *serviceConnection = [[NSXPCConnection alloc] initWithServiceName:@"com.codeux.app-utilities.Textual-HistoricLogFileManager"];

	NSXPCInterface *remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HLSHistoricLogProtocol)];

	[remoteObjectInterface setClasses:[NSSet setWithObjects:[NSArray class], [TVCLogLineXPC class], nil]
					  forSelector:@selector(fetchEntriesForChannel:fetchLimit:limitToDate:withCompletionBlock:)
					argumentIndex:0
						  ofReply:YES];

	serviceConnection.remoteObjectInterface = remoteObjectInterface;

	serviceConnection.interruptionHandler = ^{
		[self interuptionHandler];

		LogToConsole("Interuption handler called");
	};

	serviceConnection.invalidationHandler = ^{
		[self invalidationHandler];

		LogToConsole("Invalidation handler called");
	};

	[serviceConnection resume];

	self.serviceConnection = serviceConnection;
}

- (void)interuptionHandler
{
	[self invalidateProcess];
}

- (void)invalidationHandler
{
	self.serviceConnection = nil;

	[self resetContext];

	if (self.connectionInvalidatedVoluntarily) {
		self.connectionInvalidatedVoluntarily = NO;

		return;
	}

	/* Error dialog is purposely only ever shown once */
	if (self.connectionInvalidatedErrorDialogDisplayed == NO) {
		self.connectionInvalidatedErrorDialogDisplayed = YES;
	} else {
		return;
	}

	NSString *lastErrorMessage = self.lastServiceConnectionError.localizedDescription;

	if (lastErrorMessage == nil) {
		lastErrorMessage = NSStringEmptyPlaceholder;
	} else {
		lastErrorMessage = TXTLS(@"Prompts[1137][2]", lastErrorMessage);
	}

	(void)[TLOPopupPrompts dialogWindowWithMessage:lastErrorMessage
											 title:TXTLS(@"Prompts[1137][1]")
									 defaultButton:TXTLS(@"Prompts[0005]")
								   alternateButton:nil];
}

- (void)resetContext
{
	self.isSaving = NO;

	self.processLoading = NO;
	self.processLoaded = NO;
}

- (void)setupTimers
{
	NSUInteger maximumLineCount = MIN([TPCPreferences scrollbackLimit], [TPCPreferences scrollbackHistoryLimit]);

	[[self remoteObjectProxy] setMaximumLineCount:maximumLineCount];
}

- (void)prepareForApplicationTermination
{
	self.isTerminating = YES;

	[self saveData];
}

#pragma mark -
#pragma mark Private API

- (id <HLSHistoricLogProtocol>)remoteObjectProxy
{
	return [self remoteObjectProxyWithErrorHandler:nil];
}

- (id <HLSHistoricLogProtocol>)remoteObjectProxyWithErrorHandler:(void (^ _Nullable)(NSError *error))handler
{
	return [self.serviceConnection remoteObjectProxyWithErrorHandler:^(NSError *error) {
		self.lastServiceConnectionError = error;

		LogToConsoleError("Error occurred while communicating with service: %@",
			error.localizedDescription);

		if (handler) {
			handler(error);
		}
	}];
}

#pragma mark -
#pragma mark Public API 

- (void)fetchEntriesForChannel:(IRCChannel *)channel
					fetchLimit:(NSUInteger)fetchLimit
				   limitToDate:(nullable NSDate *)limitToDate
		   withCompletionBlock:(void (^)(NSArray<TVCLogLine *> *entries))completionBlock
{
	void (^privateCompletionBlock)(NSArray *) = ^(NSArray<TVCLogLineXPC *> *entries) {
		@autoreleasepool {
			NSMutableArray *logLines = [NSMutableArray arrayWithCapacity:entries.count];

			for (TVCLogLineXPC *entry in entries) {
				TVCLogLine *logLine = [[TVCLogLine alloc] initWithXPCObject:entry];

				if (logLine == nil) {
					LogToConsoleError("Failed to initalize object %@. Corrupt data?",
						  entry.description);

					continue;
				}

				[logLines addObject:logLine];
			}

			completionBlock([logLines copy]);
		}
	};

	[self warmProcessIfNeeded];

	[[self remoteObjectProxy] fetchEntriesForChannel:channel.uniqueIdentifier
										  fetchLimit:fetchLimit
										 limitToDate:limitToDate
								 withCompletionBlock:privateCompletionBlock];
}

- (void)saveData
{
	if (self.isTerminating) {
		if (self.processLoaded == NO && self.processLoading == NO) {
			return;
		}
	}

	if (self.isSaving == NO) {
		self.isSaving = YES;
	} else {
		LogToConsoleDebug("Cancelled save because a save is already saving");

		return;
	}

	[self warmProcessIfNeeded];

	[[self remoteObjectProxy] saveDataWithCompletionBlock:^{
		self.isSaving = NO;

		if (self.isTerminating) {
			[self invalidateProcess];
		}
	}];
}

- (void)forgetChannel:(IRCChannel *)channel
{
	[self warmProcessIfNeeded];
	
	[[self remoteObjectProxy] forgetChannel:channel.uniqueIdentifier];
}

- (void)resetDataForChannel:(IRCChannel *)channel
{
	[self warmProcessIfNeeded];

	[[self remoteObjectProxy] resetDataForChannel:channel.uniqueIdentifier];
}

- (void)writeNewEntryWithLogLine:(TVCLogLine *)logLine inChannel:(IRCChannel *)channel
{
	[self warmProcessIfNeeded];

	TVCLogLineXPC *newEntry = [logLine xpcObjectForChannel:channel];

	[[self remoteObjectProxy] writeLogLine:newEntry];
}

@end

NS_ASSUME_NONNULL_END
