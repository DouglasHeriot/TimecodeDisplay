/**

 @author  Kurt Revis
 @file    NSData-F53MIDIExtensions.m

 Copyright (c) 2001-2006, Kurt Revis. All rights reserved.
 Copyright (c) 2006-2011, Figure 53.
 
 NOTE: F53MIDI is an appropriation of Kurt Revis's SnoizeMIDI. https://github.com/krevis/MIDIApps
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
**/

#import "NSData-F53MIDIExtensions.h"


@implementation NSData (F53MIDIExtensions)

- (NSString *) F53_lowercaseHexString
{
    unsigned int dataLength;
    const unsigned char *p;
    const unsigned char *end;
    char *resultBuffer;
    char *resultChar;
    NSString *resultString;
    static const char hexchars[] = "0123456789abcdef";
    
    dataLength = [self length];
    if (dataLength == 0)
        return @"";
    
    p = [self bytes];
    end = p + dataLength;
    resultBuffer = malloc(2 * dataLength + 1);
    resultChar = resultBuffer;
    
    while (p < end) {
        unsigned char byte = *p++;
        *resultChar++ = hexchars[(byte & 0xF0) >> 4];
        *resultChar++ = hexchars[byte & 0x0F];
    }
    
    *resultChar++ = '\0';
    resultString = [NSString stringWithUTF8String:resultBuffer];
    free(resultBuffer);
    
    return resultString;
}

@end
