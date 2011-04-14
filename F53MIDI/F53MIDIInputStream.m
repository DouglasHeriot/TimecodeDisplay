/**

 @author  Kurt Revis
 @file    F53MIDIInputStream.m

 Copyright (c) 2001-2006, Kurt Revis. All rights reserved.
 Copyright (c) 2006-2011, Figure 53.
 
 NOTE: F53MIDI is an appropriation of Kurt Revis's SnoizeMIDI. https://github.com/krevis/MIDIApps
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
**/

#import "F53MIDIInputStream.h"

#import "F53MIDIClient.h"
#import "F53MIDIEndpoint.h"
#import "F53MIDIMessage.h"
#import "F53MIDISystemExclusiveMessage.h"
#import "F53MIDIMessageParser.h"
#import "F53MIDIUtilities.h"
#import "MessageQueue.h"


@interface F53MIDIInputStream (Private)

static void midiReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);
+ (void) runSecondaryMIDIThread: (id) ignoredObject;
static void receivePendingPacketList(CFTypeRef objectFromQueue, void *refCon);

- (id <F53MIDIInputStreamSource>) findInputSourceWithName: (NSString *) desiredName uniqueID: (NSNumber *) desiredUniqueID;

@end


@implementation F53MIDIInputStream

NSString *F53MIDIInputStreamReadingSysExNotification = @"F53MIDIInputStreamReadingSysExNotification";
NSString *F53MIDIInputStreamDoneReadingSysExNotification = @"F53MIDIInputStreamDoneReadingSysExNotification";
NSString *F53MIDIInputStreamSelectedInputSourceDisappearedNotification = @"F53MIDIInputStreamSelectedInputSourceDisappearedNotification";
NSString *F53MIDIInputStreamSourceListChangedNotification = @"F53MIDIInputStreamSourceListChangedNotification";

+ (void) initialize
{
    F53Initialize;

	// MODIFIED BY CA:
	// There appears to be no real reason to put this queue on a second thread, 
    // and Kurt believes it is safer and advisable to just create it here.
	CreateMessageQueue(receivePendingPacketList, NULL);
	
//    [NSThread detachNewThreadSelector:@selector(runSecondaryMIDIThread:) toTarget:self withObject:nil];
}

- (id) init
{
    if (!(self = [super init]))
        return nil;

    _sysExTimeOut = 1.0;
    
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

- (id <F53MIDIMessageDestination>) messageDestination
{
    return _nonretainedMessageDestination;
}

- (void) setMessageDestination:(id <F53MIDIMessageDestination>) messageDestination
{
    _nonretainedMessageDestination = messageDestination;
}

- (void) setSysExTimeOut: (NSTimeInterval) value
{
    NSArray *parsers;
    unsigned int parserIndex;

    if (_sysExTimeOut == value)
        return;

    _sysExTimeOut = value;

    parsers = [self parsers];
    parserIndex = [parsers count];
    while (parserIndex--)
        [[parsers objectAtIndex:parserIndex] setSysExTimeOut:_sysExTimeOut];
}

- (NSTimeInterval) sysExTimeOut
{
    return _sysExTimeOut;
}

- (void) cancelReceivingSysExMessage
{
    [[self parsers] makeObjectsPerformSelector:@selector(cancelReceivingSysExMessage)];
}

- (id) persistentSettings
{
    NSSet *selectedInputSources;
    unsigned int sourcesCount;
    NSEnumerator *sourceEnumerator;
    id <F53MIDIInputStreamSource> source;
    NSMutableArray *persistentSettings;

    selectedInputSources = [self selectedInputSources];
    sourcesCount = [selectedInputSources count];
    if (sourcesCount == 0)
        return nil;
    persistentSettings = [NSMutableArray arrayWithCapacity:sourcesCount];

    sourceEnumerator = [selectedInputSources objectEnumerator];
    while ((source = [sourceEnumerator nextObject])) {
        NSMutableDictionary *dict;
        id object;

        dict = [NSMutableDictionary dictionary];
        if ((object = [source inputStreamSourceUniqueID]))
            [dict setObject:object forKey:@"uniqueID"];
        if ((object = [source inputStreamSourceName]))
            [dict setObject:object forKey:@"name"];

        if ([dict count] > 0)
            [persistentSettings addObject:dict];
    }
    
    return persistentSettings;
}

- (NSArray *) takePersistentSettings: (id) settings
{
    // If any endpoints couldn't be found, their names are returned
    NSArray *settingsArray = (NSArray *)settings;
    unsigned int settingsCount, settingsIndex;
    NSMutableSet *newInputSources;
    NSMutableArray *missingNames = nil;

    settingsCount = [settingsArray count];
    newInputSources = [NSMutableSet setWithCapacity:settingsCount];
    for (settingsIndex = 0; settingsIndex < settingsCount; settingsIndex++) {
        NSDictionary *dict;
        NSString *name;
        NSNumber *uniqueID;
        id <F53MIDIInputStreamSource> source;

        dict = [settingsArray objectAtIndex:settingsIndex];
        name = [dict objectForKey:@"name"];
        uniqueID = [dict objectForKey:@"uniqueID"];
        if ((source = [self findInputSourceWithName:name uniqueID:uniqueID])) {
            [newInputSources addObject:source];
        } else {
            if (!name)
                name = NSLocalizedStringFromTableInBundle(@"Unknown", @"F53MIDI", F53BundleForObject(self), "name of missing endpoint if not specified in document");
            if (!missingNames)
                missingNames = [NSMutableArray array];
            [missingNames addObject:name];
        }
    }

    [self setSelectedInputSources:newInputSources];

    return missingNames;
}

//
// For use by subclasses only
//

- (MIDIReadProc) midiReadProc
{
    return midiReadProc;
}

- (F53MIDIMessageParser *) newParserWithOriginatingEndpoint: (F53MIDIEndpoint *) originatingEndpoint
{
    F53MIDIMessageParser *parser;

    parser = [[[F53MIDIMessageParser alloc] init] autorelease];
    [parser setDelegate:self];
    [parser setSysExTimeOut:_sysExTimeOut];
    [parser setOriginatingEndpoint:originatingEndpoint];

    return parser;
}

- (void) postSelectedInputStreamSourceDisappearedNotification:(id <F53MIDIInputStreamSource>) source
{
    [[NSNotificationCenter defaultCenter] postNotificationName:F53MIDIInputStreamSelectedInputSourceDisappearedNotification object:self userInfo:[NSDictionary dictionaryWithObject:source forKey:@"source"]];
}

- (void) postSourceListChangedNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:F53MIDIInputStreamSourceListChangedNotification object:self];
}

//
// For subclasses to implement
//

- (NSArray *) parsers
{
    F53RequestConcreteImplementation(self, _cmd);
    return nil;
}

- (F53MIDIMessageParser *) parserForSourceConnectionRefCon: (void *) refCon
{
    F53RequestConcreteImplementation(self, _cmd);
    return nil;
}

- (id <F53MIDIInputStreamSource>) streamSourceForParser: (F53MIDIMessageParser *) parser
{
    F53RequestConcreteImplementation(self, _cmd);
    return nil;
}

- (NSArray *) inputSources
{
    F53RequestConcreteImplementation(self, _cmd);
    return nil;
}

- (void) setSelectedInputSources: (NSSet *) sources
{
    F53RequestConcreteImplementation(self, _cmd);
    return;
}

- (NSSet *) selectedInputSources
{
    F53RequestConcreteImplementation(self, _cmd);
    return nil;
}

//
// Parser delegate
//

- (void) parser: (F53MIDIMessageParser *) parser didReadMessages: (NSArray *) messages
{
    [_nonretainedMessageDestination takeMIDIMessages:messages];
}

- (void) parser: (F53MIDIMessageParser *) parser isReadingSysExWithLength: (unsigned int) length
{
    NSDictionary *userInfo;

    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:	[NSNumber numberWithUnsignedInt:length], @"length",
															[self streamSourceForParser:parser], @"source", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:F53MIDIInputStreamReadingSysExNotification object:self userInfo:userInfo];
}

- (void) parser: (F53MIDIMessageParser *) parser finishedReadingSysExMessage: (F53MIDISystemExclusiveMessage *) message
{
    NSDictionary *userInfo;
    
    userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInt:1 + [[message receivedData] length]], @"length",
        [NSNumber numberWithBool:[message wasReceivedWithEOX]], @"valid",
        [self streamSourceForParser:parser], @"source", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:F53MIDIInputStreamDoneReadingSysExNotification object:self userInfo:userInfo];
}

@end


@implementation F53MIDIInputStream (Private)

typedef struct PendingPacketList {
    void *readProcRefCon;
    void *srcConnRefCon;
    MIDIPacketList packetList;
} PendingPacketList;

static void midiReadProc(const MIDIPacketList *packetList, void *readProcRefCon, void *srcConnRefCon)
{
    // NOTE: This function is called in a high-priority, time-constraint thread,
    // created for us by CoreMIDI.
    //
    // TODO Because we're in a time-constraint thread, we should avoid allocating memory,
    // since the allocator uses a single app-wide lock. (If another low-priority thread holds
    // that lock, we'll have to wait for that thread to release it, which is priority inversion.)
    // We're not even attempting to do that yet; roll back to an earlier version to see some preliminary code.

    UInt32 packetListSize;
    const MIDIPacket *packet;
    UInt32 i;
    NSData *data;
    PendingPacketList *pendingPacketList;

    // Find the size of the whole packet list
    packetListSize = sizeof(UInt32);	// numPackets
    packet = &packetList->packet[0];
    for (i = 0; i < packetList->numPackets; i++) {
        packetListSize += offsetof(MIDIPacket, data) + packet->length;
        packet = MIDIPacketNext(packet);
    }

    // Copy the packet list and other arguments into a new PendingPacketList (in an NSData)
    data = [[NSMutableData alloc] initWithLength:(offsetof(PendingPacketList, packetList) + packetListSize)];
    pendingPacketList = (PendingPacketList *)[data bytes];
    pendingPacketList->readProcRefCon = readProcRefCon;
    pendingPacketList->srcConnRefCon = srcConnRefCon;
    memcpy(&pendingPacketList->packetList, packetList, packetListSize);

    // Queue the data; receiveFromMessageQueue() will be called in the secondary MIDI thread.
    AddToMessageQueue((CFDataRef)data);

    [data release];
}

+ (void) runSecondaryMIDIThread: (id) ignoredObject
{
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];

    CreateMessageQueue(receivePendingPacketList, NULL);

    [[NSRunLoop currentRunLoop] run];
    // Runs until DestroyMessageQueue() is called

    [pool release];
}

static void receivePendingPacketList(CFTypeRef objectFromQueue, void *refCon)
{
    // NOTE: This function is called in the secondary MIDI thread that we create
	// MODIFIED BY CA:  Nope, now it's called on the main thread.

    NSAutoreleasePool *pool;
    NSData *data = (NSData *)objectFromQueue;
    PendingPacketList *pendingPacketList;
    F53MIDIInputStream *inputStream;

    pool = [[NSAutoreleasePool alloc] init];

    pendingPacketList = (PendingPacketList *)[data bytes];
    inputStream = (F53MIDIInputStream *)pendingPacketList->readProcRefCon;
    NS_DURING {
        [[inputStream parserForSourceConnectionRefCon:pendingPacketList->srcConnRefCon] takePacketList:&pendingPacketList->packetList];
    } NS_HANDLER {
        // Ignore any exceptions raised
#if DEBUG
        NSLog(@"Exception raised during MIDI parsing in secondary thread: %@", localException);
#endif
    } NS_ENDHANDLER;

    [pool release];
}

- (id <F53MIDIInputStreamSource>) findInputSourceWithName: (NSString *) desiredName uniqueID: (NSNumber *) desiredUniqueID
{
    // Find the input source with the desired unique ID. If there are no matches by uniqueID, return the first source whose name matches.
    // Otherwise, return nil.

    NSArray *inputSources;
    unsigned int inputSourceCount, inputSourceIndex;
    id <F53MIDIInputStreamSource> sourceWithMatchingName = nil;

    inputSources = [self inputSources];
    inputSourceCount = [inputSources count];
    for (inputSourceIndex = 0; inputSourceIndex < inputSourceCount; inputSourceIndex++) {
        id <F53MIDIInputStreamSource> source;

        source = [inputSources objectAtIndex:inputSourceIndex];
        if ([[source inputStreamSourceUniqueID] isEqual:desiredUniqueID])
            return source;
        else if (!sourceWithMatchingName && [[source inputStreamSourceName] isEqualToString:desiredName])
            sourceWithMatchingName = source;
    }

    return sourceWithMatchingName;
}

@end
