//
//  AKRLog.h
//  Observer
//
//  Created by Regan Sarwas on 4/17/17.
//  Copyright © 2017 GIS Team. All rights reserved.
//

#ifndef AKRLog_h

#ifdef AKR_DEBUG
#define AKRLog( ... ) NSLog(@"%@(%d): %@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:__VA_ARGS__])
#else
#define AKRLog( ... )
#endif

#define AKRLog_h


#endif /* AKRLog_h */
