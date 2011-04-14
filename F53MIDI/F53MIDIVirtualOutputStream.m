/**

 @author  Kurt Revis
 @file    F53MIDIVirtualOutputStream.m

 Copyright (c) 2001-2006, Kurt Revis. All rights reserved.
 Copyright (c) 2006-2011, Figure 53.
 
 NOTE: F53MIDI is an appropriation of Kurt Revis's SnoizeMIDI. https://github.com/krevis/MIDIApps
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
**/

#import "F53MIDIVirtualOutputStream.h"

#import "F53MIDIClient.h"
#import "F53MIDIEndpoint.h"
#import "F53MIDISourceEndpoint.h"


@implementation F53MIDIVirtualOutputStream

- (id) initWithName: (NSString *) name uniqueID: (MIDIUniqueID) uniqueID
{
    if (!(self = [super init]))
        return nil;
    
    _endpoint = [[F53MIDISourceEndpoint createVirtualSourceEndpointWithName:name uniqueID:uniqueID] retain];
    if (!_endpoint) {
        [self release];
        return nil;
    }
    
    return self;
}

- (void) dealloc
{
    [_endpoint remove];
    [_endpoint release];
    _endpoint = nil;
    
    [super dealloc];
}

- (F53MIDISourceEndpoint *) endpoint
{
    return _endpoint;
}

- (void) sendMIDIPacketList: (MIDIPacketList *) packetList
{
    MIDIEndpointRef endpointRef;
    
    if (!(endpointRef = [_endpoint endpointRef]))
        return;
    
    MIDIReceived(endpointRef, packetList);
}

@end
