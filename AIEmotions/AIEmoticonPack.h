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

@interface AIEmoticonPack : NSObject<NSCopying> {
	NSBundle			*bundle;
    NSString			*path;
    NSString			*name;
	NSString			*serviceClass;
	NSString			*emoticonLocation;
    NSMutableArray		*emoticonArray;
	NSMutableArray		*enabledEmoticonArray;
    BOOL				enabled;
    NSNumber            *isBigEmoticon;
}

@property (nonatomic,assign,getter = isEnabled) BOOL enabled;

+ (id)defaultSmallPack;
+ (id)defaultBigPack;
+ (id)emoticonPackFromBundlePath:(NSString *)name;

+ (id)emoticonPackFromPath:(NSString *)inPath;
- (void)setDisabledEmoticons:(NSArray *)inArray;
- (NSString *)version;
- (BOOL)isBigEmoticon;
- (NSArray *)emoticons;
- (NSArray *)enabledEmoticons;
- (UIImage *)menuPreviewImage;
- (NSString *)name;
- (NSString *)path;
- (NSString *)serviceClass;
- (void)flushEmoticonImageCache;

@end
