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

#import "TVCLogLineXPCPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* TVCLogLineXPC is a container class for TVCLogLine when stored in a
 Core Data store. -data is the secure coded version of the class which is
 portable and can be stored in an offline database. */
@interface TVCLogLineXPC ()
@property (nonatomic, copy, readwrite) NSData *data;
@property (nonatomic, copy, readwrite) NSString *uniqueIdentifier;
@property (nonatomic, copy, readwrite) NSString *viewIdentifier;
@end

@implementation TVCLogLineXPC

- (instancetype)initWithLogLineData:(NSData *)data uniqueIdentifier:(NSString *)uniqueIdentifier viewIdentifier:(NSString *)viewIdentifier
{
	NSParameterAssert(data != nil);
	NSParameterAssert(uniqueIdentifier != nil);
	NSParameterAssert(viewIdentifier != nil);

	if ((self = [super init])) {
		self.data = data;
		self.uniqueIdentifier = uniqueIdentifier;
		self.viewIdentifier = viewIdentifier;

		return self;
	}

	return nil;
}

- (instancetype)initWithManagedObject:(NSManagedObject *)managedObject
{
	NSParameterAssert(managedObject != nil);

	if ((self = [super init])) {
		self.data = [managedObject valueForKey:@"logLineData"];
		self.uniqueIdentifier = [managedObject valueForKey:@"logLineUniqueIdentifier"];
		self.viewIdentifier = [managedObject valueForKey:@"logLineViewIdentifier"];

		return self;
	}

	return nil;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
	NSParameterAssert(aDecoder != nil);

	if ((self = [super init])) {
		self->_data = [aDecoder decodeObjectOfClass:[NSData class] forKey:@"data"];
		self->_uniqueIdentifier = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"uniqueIdentifier"];
		self->_viewIdentifier = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"viewIdentifier"];

		return self;
	}

	return nil;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:self.data forKey:@"data"];
	[aCoder encodeObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];
	[aCoder encodeObject:self.viewIdentifier forKey:@"viewIdentifier"];
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

@end

NS_ASSUME_NONNULL_END
