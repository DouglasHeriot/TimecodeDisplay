/**

 @author  Kurt Revis
 @file    F53MIDIExternalDevice.m

 Copyright (c) 2002-2006, Kurt Revis. All rights reserved.
 Copyright (c) 2006-2011, Figure 53.
 
 NOTE: F53MIDI is an appropriation of Kurt Revis's SnoizeMIDI. https://github.com/krevis/MIDIApps
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
**/

#import "F53MIDIExternalDevice.h"
#import "F53MIDIClient.h"


@implementation F53MIDIExternalDevice

//
// F53MIDIObject requires that we subclass these methods:
//

+ (MIDIObjectType) midiObjectType
{
    return kMIDIObjectType_ExternalDevice;
}

+ (ItemCount) midiObjectCount
{
    return MIDIGetNumberOfExternalDevices();
}

+ (MIDIObjectRef) midiObjectAtIndex: (ItemCount) index
{
    return (MIDIObjectRef)MIDIGetExternalDevice(index);
}

#pragma mark -
#pragma mark New methods

+ (NSArray *) externalDevices
{
    return [self allObjectsInOrder];
}

+ (F53MIDIExternalDevice *) externalDeviceWithUniqueID: (MIDIUniqueID) aUniqueID
{
    return (F53MIDIExternalDevice *)[self objectWithUniqueID:aUniqueID];
}

+ (F53MIDIExternalDevice *) externalDeviceWithDeviceRef: (MIDIDeviceRef) aDeviceRef
{
    return (F53MIDIExternalDevice *)[self objectWithObjectRef:(MIDIObjectRef)aDeviceRef];
}

- (MIDIDeviceRef) deviceRef
{
    return (MIDIDeviceRef)_objectRef;
}

- (NSString *) manufacturerName
{
    return [self stringForProperty:kMIDIPropertyManufacturer];
}

- (NSString *) modelName
{
    return [self stringForProperty:kMIDIPropertyModel];
}

- (NSString *) pathToImageFile
{
    return [self stringForProperty:kMIDIPropertyImage];
}

///
///  Maximum SysEx speed in bytes/second.
///
- (int) maxSysExSpeed
{
    int speed = 3125;    // Default speed for standard MIDI: 3125 bytes/second
    
    NS_DURING {
        speed = [self integerForProperty:kMIDIPropertyMaxSysExSpeed];
    } NS_HANDLER {
        // Ignore the exception, just return the default value
    } NS_ENDHANDLER;
    
    return speed;
}

- (void) setMaxSysExSpeed: (int) value
{
    NS_DURING {
        [self setInteger:value forProperty:kMIDIPropertyMaxSysExSpeed];
    } NS_HANDLER {
        // Ignore the exception
    } NS_ENDHANDLER;
}

@end
