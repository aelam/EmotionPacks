/* 
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 * 
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "AIEmoticonController.h"
#import "AIEmoticon.h"
#import "AIEmoticonPack.h"

#define EMOTICON_DEFAULT_PREFS				@"EmoticonDefaults"
#define EMOTICONS_PATH_NAME					@"Emoticons"

//We support loading .AdiumEmoticonset, .emoticonPack, and .emoticons
#define ADIUM_EMOTICON_SET_PATH_EXTENSION   @"AdiumEmoticonset"
#define EMOTICON_PACK_PATH_EXTENSION		@"emoticonPack"
#define PROTEUS_EMOTICON_SET_PATH_EXTENSION @"emoticons"

@interface AIEmoticonController ()
- (NSDictionary *)emoticonIndex;
- (NSCharacterSet *)emoticonHintCharacterSet;
- (NSCharacterSet *)emoticonStartCharacterSet;
- (void)resetActiveEmoticons;
- (void)resetAvailableEmoticons;
//- (NSMutableAttributedString *)_convertEmoticonsInMessage:(NSAttributedString *)inMessage context:(id)context;
- (AIEmoticon *) _bestReplacementFromEmoticons:(NSArray *)candidateEmoticons
							   withEquivalents:(NSArray *)candidateEmoticonTextEquivalents
									   context:(NSString *)serviceClassContext
									equivalent:(NSString **)replacementString
							  equivalentLength:(NSInteger *)textLength;
- (void)_buildCharacterSetsAndIndexEmoticons;
- (void)_saveActiveEmoticonPacks;
- (void)_saveEmoticonPackOrdering;
- (NSString *)_keyForPack:(AIEmoticonPack *)inPack;
//- (void)_sortArrayOfEmoticonPacks:(NSMutableArray *)packArray;
@end

NSInteger packSortFunction(id packA, id packB, void *packOrderingArray);

@implementation AIEmoticonController

#define EMOTICONS_THEMABLE_PREFS      @"Emoticon Themable Prefs"


+ (AIEmoticonController *)sharedController {
    static AIEmoticonController *controller = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [[AIEmoticonController alloc] init];
    });
    return controller;
}

//init
- (id)init
{
	if ((self = [super init])) {
		_availableEmoticonPacks = nil;
		_activeEmoticonPacks = nil;
		_activeEmoticons = nil;
		_emoticonHintCharacterSet = nil;
		_emoticonStartCharacterSet = nil;
		_emoticonIndexDict = nil;
	}
	
	return self;
}

- (NSMutableArray *)defaultPacks {
    return [NSMutableArray arrayWithObjects:[AIEmoticonPack defaultSmallPack],[AIEmoticonPack defaultBigPack], nil];
}

- (NSUInteger)replaceAnEmoticonStartingAtLocation3:(NSUInteger *)currentLocation
                                        fromString:(NSString *)messageString
                                        intoString:(NSMutableString **)newMessage
                                callingRecursively:(BOOL)callingRecursively
                         emoticonStartCharacterSet:(NSCharacterSet *)emoticonStartCharacterSet
                                     emoticonIndex:(NSDictionary *)emoticonIndex {
    
    NSUInteger	originalEmoticonLocation = NSNotFound;
    NSInteger messageStringLength = messageString.length;
    
    if (*currentLocation < messageString.length && *currentLocation != NSNotFound) {
       
        *currentLocation = [messageString rangeOfCharacterFromSet:emoticonStartCharacterSet
                                                          options:NSLiteralSearch
                                                            range:NSMakeRange(*currentLocation, 
                                                                              messageStringLength - *currentLocation)].location;

            //Use paired arrays so multiple emoticons can qualify for the same text equivalent
            NSMutableArray  *candidateEmoticons = nil;
            NSMutableArray  *candidateEmoticonTextEquivalents = nil;		
            unichar         currentCharacter = [messageString characterAtIndex:*currentLocation];
            NSString        *currentCharacterString = [NSString stringWithFormat:@"%C", currentCharacter];
            
            //Check for the presence of all emoticons starting with this character
            for (AIEmoticon *emoticon in [emoticonIndex objectForKey:currentCharacterString]) {	
                for (NSString *text in [emoticon textEquivalents]) {
                    NSInteger     textLength = [text length];
                    
                    if (textLength != 0) { //Invalid emoticon files may let empty text equivalents sneak in
                        //If there is not enough room in the string for this text, we can skip it
                        if (*currentLocation + textLength <= messageStringLength) {
                            if ([messageString compare:text
                                               options:NSLiteralSearch
                                                 range:NSMakeRange(*currentLocation, textLength)] == NSOrderedSame) {
                                NSLog(@"Found : %@",text);
                                //Ignore emoticons within links
                                if (1/*[originalAttributedString attribute:NSLinkAttributeName
                                      atIndex:*currentLocation
                                      effectiveRange:nil] == nil*/) {
                                          if (!candidateEmoticons) {
                                              candidateEmoticons = [[NSMutableArray alloc] init];
                                              candidateEmoticonTextEquivalents = [[NSMutableArray alloc] init];
                                          }
                                          
                                          [candidateEmoticons addObject:emoticon];
                                          [candidateEmoticonTextEquivalents addObject:text];
                                      }
                            }
                        }
                    }
                }
            }
            
            //
            if ([candidateEmoticons count]) {
                NSString					*replacementString;
                NSString                    *replacement;
                NSInteger					textLength;
                NSRange						emoticonRangeInNewMessage;
                //
//                originalEmoticonLocation = *currentLocation;
                //
                //Use the most appropriate, longest string of those which could be used for the emoticon text we found here
                AIEmoticon *emoticon = [self _bestReplacementFromEmoticons:candidateEmoticons
                                                           withEquivalents:candidateEmoticonTextEquivalents
                                                                   context:nil
                                                                equivalent:&replacementString
                                                          equivalentLength:&textLength];
                emoticonRangeInNewMessage = NSMakeRange(*currentLocation , textLength);
                
                
                replacement = [emoticon styleStringWithTextEquivalent:replacementString];
                
                if (!(*newMessage)) {
                    *newMessage = [[[NSMutableString alloc]initWithString:messageString] autorelease];
                }
                
                [(*newMessage) replaceCharactersInRange:emoticonRangeInNewMessage withString:replacement];
                
                *currentLocation += replacement.length - 1;
                
            }
        }
        
        (*currentLocation) += 1;
        
        if (callingRecursively && (*currentLocation) < (*newMessage).length) {
            return [self replaceAnEmoticonStartingAtLocation3:currentLocation fromString:*newMessage intoString:newMessage callingRecursively:callingRecursively emoticonStartCharacterSet:emoticonStartCharacterSet emoticonIndex:emoticonIndex];
        }
        
        
    return *currentLocation;
}


- (NSUInteger)replaceAnEmoticonStartingAtLocation2:(NSUInteger *)currentLocation
                                       fromString:(NSString *)messageString
                              messageStringLength:(NSUInteger)messageStringLength
                                    originMessage:(NSString *)originMessage
                                       intoString:(NSMutableString **)newMessage
                                 replacementCount:(NSUInteger *)replacementCount
                               callingRecursively:(BOOL)callingRecursively
                        emoticonStartCharacterSet:(NSCharacterSet *)emoticonStartCharacterSet
                                    emoticonIndex:(NSDictionary *)emoticonIndex
{
    NSUInteger	originalEmoticonLocation = NSNotFound;
    //
	//Find the next occurence of a suspected emoticon
	*currentLocation = [messageString rangeOfCharacterFromSet:emoticonStartCharacterSet
													  options:NSLiteralSearch
														range:NSMakeRange(*currentLocation, 
																		  messageStringLength - *currentLocation)].location;
	if (*currentLocation != NSNotFound) {
		//Use paired arrays so multiple emoticons can qualify for the same text equivalent
		NSMutableArray  *candidateEmoticons = nil;
		NSMutableArray  *candidateEmoticonTextEquivalents = nil;		
		unichar         currentCharacter = [messageString characterAtIndex:*currentLocation];
		NSString        *currentCharacterString = [NSString stringWithFormat:@"%C", currentCharacter];
        
		//Check for the presence of all emoticons starting with this character
		for (AIEmoticon *emoticon in [emoticonIndex objectForKey:currentCharacterString]) {	
			for (NSString *text in [emoticon textEquivalents]) {
				NSInteger     textLength = [text length];
				
				if (textLength != 0) { //Invalid emoticon files may let empty text equivalents sneak in
                    //If there is not enough room in the string for this text, we can skip it
					if (*currentLocation + textLength <= messageStringLength) {
						if ([messageString compare:text
										   options:NSLiteralSearch
											 range:NSMakeRange(*currentLocation, textLength)] == NSOrderedSame) {
							NSLog(@"Found : %@",text);
                            //Ignore emoticons within links
							if (1/*[originalAttributedString attribute:NSLinkAttributeName
                                  atIndex:*currentLocation
                                  effectiveRange:nil] == nil*/) {
                                      if (!candidateEmoticons) {
                                          candidateEmoticons = [[[NSMutableArray alloc] init] autorelease];
                                          candidateEmoticonTextEquivalents = [[[NSMutableArray alloc] init] autorelease];
                                      }
                                      
                                      [candidateEmoticons addObject:emoticon];
                                      [candidateEmoticonTextEquivalents addObject:text];
                                  }
						}
					}
				}
			}
		}
        
        //
		if ([candidateEmoticons count]) {
			NSString					*replacementString;
			NSString                    *replacement;
			NSInteger					textLength;
			NSRange						emoticonRangeInNewMessage;
            //
			originalEmoticonLocation = *currentLocation;
            //
			//Use the most appropriate, longest string of those which could be used for the emoticon text we found here
			AIEmoticon *emoticon = [self _bestReplacementFromEmoticons:candidateEmoticons
                                                       withEquivalents:candidateEmoticonTextEquivalents
                                                               context:nil
                                                            equivalent:&replacementString
                                                      equivalentLength:&textLength];
			emoticonRangeInNewMessage = NSMakeRange(*currentLocation - *replacementCount, textLength);
			
            
            replacement = [emoticon styleStringWithTextEquivalent:replacementString];
            
            if (!(*newMessage)) {
                *newMessage = [[[NSMutableString alloc]initWithString:originMessage] autorelease];
            }
            
            [(*newMessage) replaceCharactersInRange:emoticonRangeInNewMessage withString:replacement];
            
            NSLog(@"%@",*newMessage);
            
            *currentLocation += replacement.length - 1;
                        
        }
    }
    
    *currentLocation += 1;
    
    if (callingRecursively && (*currentLocation) < (*newMessage).length) {
        //                *currentLocation += 1;
        return [self replaceAnEmoticonStartingAtLocation2:currentLocation fromString:*newMessage messageStringLength:[*newMessage length] originMessage:originMessage intoString:newMessage replacementCount:replacementCount callingRecursively:YES emoticonStartCharacterSet:emoticonStartCharacterSet emoticonIndex:emoticonIndex];
    }

    
    return originalEmoticonLocation;
}

        
- (NSUInteger)replaceAnEmoticonStartingAtLocation:(NSUInteger *)currentLocation
										 fromString:(NSString *)messageString
								messageStringLength:(NSUInteger)messageStringLength
                                     originMessage:(NSString *)originMessage
										 intoString:(NSMutableString **)newMessage
								   replacementCount:(NSUInteger *)replacementCount
								 callingRecursively:(BOOL)callingRecursively
						  emoticonStartCharacterSet:(NSCharacterSet *)emoticonStartCharacterSet
									  emoticonIndex:(NSDictionary *)emoticonIndex
//{
//    return 0;
//}
{
	NSUInteger	originalEmoticonLocation = NSNotFound;
//
	//Find the next occurence of a suspected emoticon
	*currentLocation = [messageString rangeOfCharacterFromSet:emoticonStartCharacterSet
													  options:NSLiteralSearch
														range:NSMakeRange(*currentLocation, 
																		  messageStringLength - *currentLocation)].location;
	if (*currentLocation != NSNotFound) {
		//Use paired arrays so multiple emoticons can qualify for the same text equivalent
		NSMutableArray  *candidateEmoticons = nil;
		NSMutableArray  *candidateEmoticonTextEquivalents = nil;		
		unichar         currentCharacter = [messageString characterAtIndex:*currentLocation];
		NSString        *currentCharacterString = [NSString stringWithFormat:@"%C", currentCharacter];

		//Check for the presence of all emoticons starting with this character
		for (AIEmoticon *emoticon in [emoticonIndex objectForKey:currentCharacterString]) {	
			for (NSString *text in [emoticon textEquivalents]) {
				NSInteger     textLength = [text length];
				
				if (textLength != 0) { //Invalid emoticon files may let empty text equivalents sneak in
									   //If there is not enough room in the string for this text, we can skip it
					if (*currentLocation + textLength <= messageStringLength) {
						if ([messageString compare:text
										   options:NSLiteralSearch
											 range:NSMakeRange(*currentLocation, textLength)] == NSOrderedSame) {
							NSLog(@"Found : %@",text);
                            //Ignore emoticons within links
							if (1/*[originalAttributedString attribute:NSLinkAttributeName
															atIndex:*currentLocation
													 effectiveRange:nil] == nil*/) {
								if (!candidateEmoticons) {
									candidateEmoticons = [[NSMutableArray alloc] init];
									candidateEmoticonTextEquivalents = [[NSMutableArray alloc] init];
								}
								
								[candidateEmoticons addObject:emoticon];
								[candidateEmoticonTextEquivalents addObject:text];
							}
						}
					}
				}
			}
		}
        
        NSLog(@"candidateEmoticons = %@",candidateEmoticons);
        NSLog(@"candidateEmoticonTextEquivalents = %@",candidateEmoticonTextEquivalents);
        
//
		BOOL currentLocationNeedsUpdate = YES;
//
		if ([candidateEmoticons count]) {
			NSString					*replacementString;
			NSString                    *replacement;
			NSInteger					textLength;
			NSRange						emoticonRangeInNewMessage;
//
			originalEmoticonLocation = *currentLocation;
//
			//Use the most appropriate, longest string of those which could be used for the emoticon text we found here
			AIEmoticon *emoticon = [self _bestReplacementFromEmoticons:candidateEmoticons
										   withEquivalents:candidateEmoticonTextEquivalents
												   context:nil
												equivalent:&replacementString
										  equivalentLength:&textLength];
			emoticonRangeInNewMessage = NSMakeRange(*currentLocation - *replacementCount, textLength);
			
            NSLog(@"textLength : %d %@",textLength,replacementString);
            
//            replacement = [emoticon styleStringWithTextEquivalent:replacementString];
            
			/* We want to show this emoticon if there is:
			 *		It begins or ends the string
			 *		It is bordered by spaces or line breaks or quotes on both sides
			 *		It is bordered by a period on the left and a space or line break or quote the right
			 *		It is bordered by emoticons on both sides or by an emoticon on the left and a period, space, or line break on the right
			 */
			BOOL	acceptable = NO;
			if ((messageStringLength == ((originalEmoticonLocation + textLength))) || //Ends the string
				(originalEmoticonLocation == 0)) { //Begins the string
				acceptable = YES;
			}
			if (!acceptable) {
				/* Bordered by spaces or line breaks or quotes, or by a period on the left and a space or a line break or quote on the right
				 * If we're being called recursively, we have a potential emoticon to our left;  we only need to check the right.
				 * This is also true if we're not being called recursively but there's an NSAttachmentAttribute to our left.
				 *		That will happen if, for example, the string is ":):) ". The first emoticon is at the start of the line and
				 *		so is immediately acceptable. The second should be acceptable because it is to the right of an emoticon and
				 *		the left of a space.
				 */
				char	previousCharacter = [messageString characterAtIndex:(originalEmoticonLocation - 1)] ;
				char	nextCharacter = [messageString characterAtIndex:(originalEmoticonLocation + textLength)] ;

				if ((callingRecursively || (previousCharacter == ' ') || (previousCharacter == '\t') ||
					 (previousCharacter == '\n') || (previousCharacter == '\r') || (previousCharacter == '.') || (previousCharacter == '?') || (previousCharacter == '!') ||
					 (previousCharacter == '\"') || (previousCharacter == '\'') ||
					 (previousCharacter == '(') || (previousCharacter == '*')/* ||
					 (*newMessage && [*newMessage attribute:NSAttachmentAttributeName
													atIndex:(emoticonRangeInNewMessage.location - 1) 
											 effectiveRange:NULL])*/) &&

					((nextCharacter == ' ') || (nextCharacter == '\t') || (nextCharacter == '\n') || (nextCharacter == '\r') ||
					 (nextCharacter == '.') || (nextCharacter == ',') || (nextCharacter == '?') || (nextCharacter == '!') ||
					 (nextCharacter == ')') || (nextCharacter == '*') ||
					 (nextCharacter == '\"') || (nextCharacter == '\''))) {
					acceptable = YES;
				}
			}
			if (!acceptable) {
				/* If the emoticon would end the string except for whitespace, newlines, or punctionation at the end, or it begins the string after removing
				 * whitespace, newlines, or punctuation at the beginning, it is acceptable even if the previous conditions weren't met.
				 */
				NSCharacterSet *endingTrimSet = nil;
				static NSMutableDictionary *endingSetDict = nil;
				if(!endingSetDict) {
					endingSetDict = [[NSMutableDictionary alloc] initWithCapacity:10];
				}
				if (!(endingTrimSet = [endingSetDict objectForKey:replacementString])) {
					NSMutableCharacterSet *tempSet = [[NSCharacterSet punctuationCharacterSet] mutableCopy];
					[tempSet formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					[tempSet formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
					//remove any characters *in* the replacement string from the trimming set
					[tempSet removeCharactersInString:replacementString];
					[endingSetDict setObject:tempSet forKey:replacementString];
					[tempSet release];
					endingTrimSet = [endingSetDict objectForKey:replacementString];
				}
//
				NSString	*trimmedString = [messageString stringByTrimmingCharactersInSet:endingTrimSet];
				NSUInteger trimmedLength = [trimmedString length];
				if (trimmedLength == (originalEmoticonLocation + textLength)) {
					// Replace at end of string
					acceptable = YES;
				} else if ([trimmedString characterAtIndex:0] == [replacementString characterAtIndex:0]) {
					// Replace at start of string
					acceptable = YES;					
				}
			}
			if (!acceptable) {
				/* If we still haven't determined it to be acceptable, look ahead.
				 * If we do a replacement adjacent to this emoticon, we can do this one, too.
				 */
				NSUInteger newCurrentLocation = *currentLocation;
				NSUInteger nextEmoticonLocation;
						
				/* Call ourself recursively, starting just after the end of the current emoticon candidate
				 * If the return value is not NSNotFound, an emoticon was found and replaced ahead of us. Discontinuous searching for the win.
				 */
				newCurrentLocation += textLength;
                nextEmoticonLocation = [self replaceAnEmoticonStartingAtLocation:&newCurrentLocation fromString:messageString messageStringLength:messageStringLength originMessage:originMessage intoString:newMessage replacementCount:replacementCount callingRecursively:YES emoticonStartCharacterSet:emoticonStartCharacterSet emoticonIndex:emoticonIndex];
                
				if (nextEmoticonLocation != NSNotFound) {
					if (nextEmoticonLocation == (*currentLocation + textLength)) {
						/* The next emoticon is immediately after the candidate we're looking at right now. That means
                         * our current candidate is in fact an emoticon (since it borders another emoticon).
                         */
						acceptable = YES;
					}
					
					currentLocationNeedsUpdate = NO;
					*currentLocation = newCurrentLocation;
				} else {
					/* If there isn't a next emoticon, we can skip ahead to the end of the string. */			
					*currentLocation = messageStringLength;
					currentLocationNeedsUpdate = NO;
				}
			}
            if (acceptable) {
                replacement = [emoticon styleStringWithTextEquivalent:replacementString];
                if (!(*newMessage)) {
                    *newMessage = [[NSMutableString alloc]initWithString:originMessage];
                }
                
                NSLog(@"origin : %@",*newMessage);
                [(*newMessage) replaceCharactersInRange:emoticonRangeInNewMessage withString:replacement];
                
                
                NSLog(@"new %@",*newMessage);

                NSLog(@"currentLocation : %d",*currentLocation);
                NSLog(@"emoticonRangeInNewMessage:%@",NSStringFromRange(emoticonRangeInNewMessage));
                NSLog(@"%@ --> %@ \n\n\n",replacementString,replacement);


                *replacementCount += textLength-1;
                
                if (currentLocationNeedsUpdate)
                    *currentLocation += replacement.length-1;
            } else {
                //Didn't find an acceptable emoticon, so we should return NSNotFound
				originalEmoticonLocation = NSNotFound;

            }
        }
                //				replacement = [emoticon attributedStringWithTextEquivalent:replacementString attachImages:!isMessage];
                //				
                //				NSDictionary *originalAttributes = [originalAttributedString attributesAtIndex:originalEmoticonLocation
                //																				effectiveRange:nil];
                //				
                //				originalAttributes = [originalAttributes dictionaryWithDifferenceWithSetOfKeys:[NSSet setWithObject:NSAttachmentAttributeName]];
                //				
                //				//grab the original attributes, to ensure that the background is not lost in a message consisting only of an emoticon
                //				[replacement addAttributes:originalAttributes
                //									 range:NSMakeRange(0,1)];
                //				
                //				//insert the emoticon
                //				if (!(*newMessage)) *newMessage = [originalAttributedString mutableCopy];
                //				[*newMessage replaceCharactersInRange:emoticonRangeInNewMessage
                //								 withAttributedString:replacement];
                //				
                //				//Update where we are in the original and replacement messages
                //				*replacementCount += textLength-1;
                //				
                //				if (currentLocationNeedsUpdate)
                //					*currentLocation += textLength-1;
                //			} else {
                //				//Didn't find an acceptable emoticon, so we should return NSNotFound
                //				originalEmoticonLocation = NSNotFound;
                //			}			
                //		}
                //
                //		//Always increment the loop
//                if (currentLocationNeedsUpdate) {
//                    *currentLocation += 1;
////                }
//                //		
//                [candidateEmoticons release];
//                [candidateEmoticonTextEquivalents release];
//            }
//            //
//        }

		//Always increment the loop
		if (currentLocationNeedsUpdate) {
			*currentLocation += 1;
		}
		
		[candidateEmoticons release];
		[candidateEmoticonTextEquivalents release];
	}

    NSLog(@"currentLocation : %d",*currentLocation);
        
    return originalEmoticonLocation;
}

- (NSString *)styleStringWithString:(NSString *)messageString {
//    return sourceString;
    NSMutableString *newMessage = nil;
    NSUInteger currentLocation = 0;//, messageStringLength;
    NSCharacterSet				*emoticonStartCharacterSet = self.emoticonStartCharacterSet;
    NSDictionary				*emoticonIndex = self.emoticonIndex;
    
//    messageStringLength = [messageString length];

    
    [self replaceAnEmoticonStartingAtLocation3:&currentLocation fromString:messageString intoString:&newMessage callingRecursively:YES emoticonStartCharacterSet:emoticonStartCharacterSet emoticonIndex:emoticonIndex];
        
    return (newMessage ?newMessage : messageString);
}

- (AIEmoticon *) _bestReplacementFromEmoticons:(NSArray *)candidateEmoticons
							   withEquivalents:(NSArray *)candidateEmoticonTextEquivalents
									   context:(NSString *)serviceClassContext
									equivalent:(NSString **)replacementString
							  equivalentLength:(NSInteger *)textLength
{
	NSUInteger	i = 0;
	NSUInteger	bestIndex = 0, bestLength = 0;
	NSUInteger	bestServiceAppropriateIndex = 0, bestServiceAppropriateLength = 0;
	NSString	*serviceAppropriateReplacementString = nil;
	NSUInteger	count;
	
	count = [candidateEmoticonTextEquivalents count];
	while (i < count) {
		NSString	*thisString = [candidateEmoticonTextEquivalents objectAtIndex:i];
		NSUInteger thisLength = [thisString length];
		if (thisLength > bestLength) {
			bestLength = thisLength;
			bestIndex = i;
			*replacementString = thisString;
		}

		//If we are using service appropriate emoticons, check if this is on the right service and, if so, compare.
		if (thisLength > bestServiceAppropriateLength) {
			AIEmoticon	*thisEmoticon = [candidateEmoticons objectAtIndex:i];
			if ([thisEmoticon isAppropriateForServiceClass:serviceClassContext]) {
				bestServiceAppropriateLength = thisLength;
				bestServiceAppropriateIndex = i;
				serviceAppropriateReplacementString = thisString;
			}
		}
		
		i++;
	}

	/* Did we get a service appropriate replacement? If so, use that rather than the current replacementString if it
	 * differs. */
	if (serviceAppropriateReplacementString && (serviceAppropriateReplacementString != *replacementString)) {
		bestLength = bestServiceAppropriateLength;
		bestIndex = bestServiceAppropriateIndex;
		*replacementString = serviceAppropriateReplacementString;
	}

	//Return the length by reference
	*textLength = bestLength;

	//Return the AIEmoticon we found to be best
    return [candidateEmoticons objectAtIndex:bestIndex];
}

//Active emoticons -----------------------------------------------------------------------------------------------------
#pragma mark Active emoticons
//Returns an array of the currently active emoticons
- (NSArray *)activeEmoticons
{
    if (!_activeEmoticons) {
        _activeEmoticons = [[NSMutableArray alloc] init];
		
        //Grap the emoticons from each active pack
        for (AIEmoticonPack *emoticonPack in [self activeEmoticonPacks]) {
            [_activeEmoticons addObjectsFromArray:[emoticonPack emoticons]];
        }
    }
	
    //
    return _activeEmoticons;
}

//Returns all active emoticons, categoriezed by starting character, using a dictionary, with each value containing an array of characters
- (NSDictionary *)emoticonIndex
{
    if (!_emoticonIndexDict) [self _buildCharacterSetsAndIndexEmoticons];
    return _emoticonIndexDict;
}

//Active emoticon packs ------------------------------------------------------------------------------------------------
#pragma mark Active emoticon packs
//Returns an array of the currently active emoticon packs
- (NSArray *)activeEmoticonPacks
{
    if (!_activeEmoticonPacks) {
		_activeEmoticonPacks = [[self defaultPacks] retain];        
    }

    return _activeEmoticonPacks;
}

- (void)setEmoticonPack:(AIEmoticonPack *)inPack enabled:(BOOL)enabled
{
	if (enabled) {
		[_activeEmoticonPacks addObject:inPack];	
		[inPack setEnabled:YES];
		
		//Sort the active emoticon packs as per the saved ordering
//		[self _sortArrayOfEmoticonPacks:_activeEmoticonPacks];
	} else {
		[_activeEmoticonPacks removeObject:inPack];
		[inPack setEnabled:NO];
	}
	
	//Save
	[self _saveActiveEmoticonPacks];
}

//Save the active emoticon packs to preferences
- (void)_saveActiveEmoticonPacks
{
    NSMutableArray  *nameArray = [NSMutableArray array];
    
	for (AIEmoticonPack *emoticonPack in [self activeEmoticonPacks]) {
        [nameArray addObject:emoticonPack.name];
    }    
}


//Available emoticon packs ---------------------------------------------------------------------------------------------
#pragma mark Available emoticon packs
//Returns an array of the available emoticon packs
- (NSArray *)availableEmoticonPacks
{
    if (!_availableEmoticonPacks) {
        _availableEmoticonPacks = [[NSMutableArray alloc] init];
        
		}
		
		//Sort as per the saved ordering
//		[self _sortArrayOfEmoticonPacks:_availableEmoticonPacks];

		//Build the list of active packs
		[self activeEmoticonPacks];
//    }
    
    return _availableEmoticonPacks;
}

//Returns the emoticon pack by name
- (AIEmoticonPack *)emoticonPackWithName:(NSString *)inName
{
    for (AIEmoticonPack *emoticonPack in self.availableEmoticonPacks) {
        if ([emoticonPack.name isEqualToString:inName]) return emoticonPack;
    }
	
    return nil;
}

//Pack ordering --------------------------------------------------------------------------------------------------------
#pragma mark Pack ordering
//Re-arrange an emoticon pack
- (void)moveEmoticonPacks:(NSArray *)inPacks toIndex:(NSUInteger)idx
{        
    //Remove each pack
    for (AIEmoticonPack *pack in inPacks) {
        if ([_availableEmoticonPacks indexOfObject:pack] < idx) idx--;
        [_availableEmoticonPacks removeObject:pack];
    }
	
    //Add back the packs in their new location
    for (AIEmoticonPack *pack in inPacks) {
        [_availableEmoticonPacks insertObject:pack atIndex:idx];
        idx++;
    }
	
    //Save our new ordering
    [self _saveEmoticonPackOrdering];
}

- (void)_saveEmoticonPackOrdering
{
    NSMutableArray		*nameArray = [NSMutableArray array];
    
    for (AIEmoticonPack *pack in self.availableEmoticonPacks) {
        [nameArray addObject:pack.name];
    }
    
	//Changing a preference will clear out our premade _activeEmoticonPacks array
//    [adium.preferenceController setPreference:nameArray forKey:KEY_EMOTICON_PACK_ORDERING group:PREF_GROUP_EMOTICONS];	
}

//- (void)_sortArrayOfEmoticonPacks:(NSMutableArray *)packArray
//{
//	//Load the saved ordering and sort the active array based on it
//	NSArray *packOrderingArray = [adium.preferenceController preferenceForKey:KEY_EMOTICON_PACK_ORDERING 
//																		  group:PREF_GROUP_EMOTICONS];
//	//It's most likely quicker to create an empty array here than to do nil checks each time through the sort function
//	if (!packOrderingArray)
//		packOrderingArray = [NSArray array];
//	[packArray sortUsingFunction:packSortFunction context:packOrderingArray];
//}

NSInteger packSortFunction(id packA, id packB, void *packOrderingArray)
{
	NSInteger packAIndex = [(NSArray *)packOrderingArray indexOfObject:[packA name]];
	NSInteger packBIndex = [(NSArray *)packOrderingArray indexOfObject:[packB name]];
	
	BOOL notFoundA = (packAIndex == NSNotFound);
	BOOL notFoundB = (packBIndex == NSNotFound);
	
	//Packs which aren't in the ordering index sort to the bottom
	if (notFoundA && notFoundB) {
		return ([[packA name] compare:[packB name]]);
		
	} else if (notFoundA) {
		return (NSOrderedDescending);
		
	} else if (notFoundB) {
		return (NSOrderedAscending);
		
	} else if (packAIndex > packBIndex) {
		return NSOrderedDescending;
		
	} else {
		return NSOrderedAscending;
		
	}
}


//Character hints for efficiency ---------------------------------------------------------------------------------------
#pragma mark Character hints for efficiency
//Returns a characterset containing characters that hint at the presence of an emoticon
- (NSCharacterSet *)emoticonHintCharacterSet
{
    if (!_emoticonHintCharacterSet) [self _buildCharacterSetsAndIndexEmoticons];
    return _emoticonHintCharacterSet;
}

//Returns a characterset containing all the characters that may start an emoticon
- (NSCharacterSet *)emoticonStartCharacterSet
{
    if (!_emoticonStartCharacterSet) [self _buildCharacterSetsAndIndexEmoticons];
    return _emoticonStartCharacterSet;
}

//For optimization, we build a list of characters that could possibly be an emoticon and will require additional scanning.
//We also build a dictionary categorizing the emoticons by their first character to quicken lookups.
- (void)_buildCharacterSetsAndIndexEmoticons
{    
    //Start with a fresh character set, and a fresh index
	NSMutableCharacterSet	*tmpEmoticonHintCharacterSet = [[NSMutableCharacterSet alloc] init];
	NSMutableCharacterSet	*tmpEmoticonStartCharacterSet = [[NSMutableCharacterSet alloc] init];

	[_emoticonIndexDict release]; _emoticonIndexDict = [[NSMutableDictionary alloc] init];
    
    //Process all the text equivalents of each active emoticon
    for (AIEmoticon *emoticon in self.activeEmoticons) {
        if (emoticon.isEnabled) {			
            for (NSString *text in emoticon.textEquivalents) {
                NSMutableArray  *subIndex;
                unichar         firstCharacter;
                NSString        *firstCharacterString;
                
                if ([text length] != 0) { //Invalid emoticon files may let empty text equivalents sneak in
                    firstCharacter = [text characterAtIndex:0];
                    firstCharacterString = [NSString stringWithFormat:@"%C",firstCharacter];
                    
                    // -- Emoticon Hint Character Set --
                    //If any letter in this text equivalent already exists in the quick scan character set, we can skip it
                    if ([text rangeOfCharacterFromSet:tmpEmoticonHintCharacterSet].location == NSNotFound) {
                        //Potential for optimization!: Favor punctuation characters ( :();- ) over letters (especially vowels).                
                        [tmpEmoticonHintCharacterSet addCharactersInString:firstCharacterString];
                    }
                    
                    // -- Emoticon Start Character Set --
                    //First letter of this emoticon goes in the start set
                    if (![tmpEmoticonStartCharacterSet characterIsMember:firstCharacter]) {
                        [tmpEmoticonStartCharacterSet addCharactersInString:firstCharacterString];
                    }
                    
                    // -- Index --
                    //Get the index according to this emoticon's first character
                    if (!(subIndex = [_emoticonIndexDict objectForKey:firstCharacterString])) {
                        subIndex = [[NSMutableArray alloc] init];
                        [_emoticonIndexDict setObject:subIndex forKey:firstCharacterString];
                        [subIndex release];
                    }
                    
                    //Place the emoticon into that index (If it isn't already in there)
                    if (![subIndex containsObject:emoticon]) {
						//Keep emoticons in order from largest to smallest.  This prevents icons that contain other
						//icons from being masked by the smaller icons they contain.
						//This cannot work unless the emoticon equivelents are broken down.
						/*
						for (int i = 0;i < [subIndex count]; i++) {
							if ([subIndex objectAtIndex:i] equivelentLength] < ourLength]) break;
						}*/
                        
						//Instead of adding the emoticon, add all of its equivalents... ?
						
						[subIndex addObject:emoticon];
                    }
                }
            }
            
        }
    }

	[_emoticonHintCharacterSet release]; _emoticonHintCharacterSet = [tmpEmoticonHintCharacterSet copy];
	[tmpEmoticonHintCharacterSet release];

    [_emoticonStartCharacterSet release]; _emoticonStartCharacterSet = [tmpEmoticonStartCharacterSet copy];
	[tmpEmoticonStartCharacterSet release];

	//After building all the subIndexes, sort them by length here
}


//Cache flushing -------------------------------------------------------------------------------------------------------
#pragma mark Cache flushing
//Flush any cached emoticon images (and image attachment strings)
- (void)flushEmoticonImageCache
{    
	for (AIEmoticonPack *pack in self.availableEmoticonPacks) {
        [pack flushEmoticonImageCache];
    }
}

//Reset the active emoticons cache
- (void)resetActiveEmoticons
{
    [_activeEmoticonPacks release]; _activeEmoticonPacks = nil;
    
    [_activeEmoticons release]; _activeEmoticons = nil;
    
    [_emoticonHintCharacterSet release]; _emoticonHintCharacterSet = nil;
    [_emoticonStartCharacterSet release]; _emoticonStartCharacterSet = nil;
    [_emoticonIndexDict release]; _emoticonIndexDict = nil;
}

//Reset the available emoticons cache
- (void)resetAvailableEmoticons
{
    [_availableEmoticonPacks release]; _availableEmoticonPacks = nil;
    [self resetActiveEmoticons];
}


//Private --------------------------------------------------------------------------------------------------------------
#pragma mark Private
- (NSString *)_keyForPack:(AIEmoticonPack *)inPack
{
	return [NSString stringWithFormat:@"Pack:%@",[inPack name]];
}

@end
