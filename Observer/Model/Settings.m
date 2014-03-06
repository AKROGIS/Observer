//
//  Settings.m
//  Observer
//
//  Created by Regan Sarwas on 7/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "Settings.h"
#import "NSArray+map.h"

/*
 * Note:
 * if defaults system cannot find a key it returns a zero value,
 * that is nil for objects, NO for BOOL, and 0 for numbers.
 * If you provide a non-zero default, then you cannot persist
 * a zero value, as it will always be replaced with your default
 */

#define DEFAULTS_KEY_URL_FOR_ACTIVE_MAP @"url_for_active_map"
#define DEFAULTS_DEFAULT_URL_FOR_ACTIVE_MAP nil

#define DEFAULTS_KEY_URL_FOR_ACTIVE_SURVEY @"url_for_active_survey"
#define DEFAULTS_DEFAULT_URL_FOR_ACTIVE_SURVEY nil

#define DEFAULTS_KEY_INDEX_OF_CURRENT_MAP @"index_of_current_map"
#define DEFAULTS_DEFAULT_INDEX_OF_CURRENT_MAP 0

#define DEFAULTS_KEY_INDEX_OF_CURRENT_SURVEY @"index_of_current_survey"
#define DEFAULTS_DEFAULT_INDEX_OF_CURRENT_SURVEY 0

#define DEFAULTS_KEY_SORTED_SURVEY_LIST @"sorted_survey_list"
#define DEFAULTS_DEFAULT_SORTED_SURVEY_LIST nil

#define DEFAULTS_KEY_HIDE_REMOTE_MAPS @"hide_remote_maps"
#define DEFAULTS_DEFAULT_HIDE_REMOTE_MAPS NO

#define DEFAULTS_KEY_HIDE_REMOTE_PROTOCOLS @"hide_remote_protocols"
#define DEFAULTS_DEFAULT_HIDE_REMOTE_PROTOCOLS NO

#define DEFAULTS_KEY_URL_FOR_MAPS @"url_for_maps"
#define DEFAULTS_DEFAULT_URL_FOR_MAPS nil

#define DEFAULTS_KEY_URL_FOR_PROTOCOLS @"url_for_protocols"
#define DEFAULTS_DEFAULT_URL_FOR_PROTOCOLS nil

#define DEFAULTS_KEY_AUTOPAN_MODE @"autopan_mode"
#define DEFAULTS_DEFAULT_AUTOPAN_MODE kNoAutoPanNoAutoRotateNorthUp

#define DEFAULTS_KEY_MAX_SPEED_FOR_BEARING @"max_speed_for_bearing"
#define DEFAULTS_DEFAULT_MAX_SPEED_FOR_BEARING 0.0

#define DEFAULTS_KEY_UOM_DISTANCE_SIGHTING @"uom_distance_sighting"
#define DEFAULTS_DEFAULT_UOM_DISTANCE_SIGHTING AGSSRUnitMeter

#define DEFAULTS_KEY_UOM_DISTANCE_MEASURE @"uom_distance_measure"
#define DEFAULTS_DEFAULT_UOM_DISTANCE_MEASURE AGSSRUnitStatuteMile

#define DEFAULTS_KEY_ANGLE_DISTANCE_ANGLE_DIRECTION @"angle_distance_angle_direction"
#define DEFAULTS_DEFAULT_ANGLE_DISTANCE_ANGLE_DIRECTION 0

#define DEFAULTS_KEY_ANGLE_DISTANCE_DEAD_AHEAD @"angle_distance_dead_ahead"
#define DEFAULTS_DEFAULT_ANGLE_DISTANCE_DEAD_AHEAD 0

#define DEFAULTS_KEY_ANGLE_DISTANCE_LAST_DISTANCE @"angle_distance_last_distance"
#define DEFAULTS_DEFAULT_ANGLE_DISTANCE_LAST_DISTANCE nil

#define DEFAULTS_KEY_ANGLE_DISTANCE_LAST_ANGLE @"angle_distance_last_angle"
#define DEFAULTS_DEFAULT_ANGLE_DISTANCE_LAST_ANGLE nil


@implementation Settings


#pragma mark - singleton

+ (Settings *)manager
{
    static Settings *_manager = nil;
        static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (!_manager) {
            _manager = [[super allocWithZone:NULL] init];
            [_manager populateRegistrationDomain];
        }
    });
    return _manager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self manager];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}



@synthesize activeMapURL = _activeMapURL;

- (NSURL *)activeMapURL
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_KEY_URL_FOR_ACTIVE_MAP];
    if ([value isKindOfClass:[NSString class]]) {
        value = [NSURL URLWithString:value];
    }
    return value ? value : DEFAULTS_DEFAULT_URL_FOR_ACTIVE_MAP;
}

- (void)setactiveMapURL:(NSURL *)activeMapURL
{
    NSString *string = activeMapURL.absoluteString;
    if ([string isEqualToString:DEFAULTS_DEFAULT_URL_FOR_ACTIVE_MAP]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_URL_FOR_ACTIVE_MAP];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:string forKey:DEFAULTS_KEY_URL_FOR_ACTIVE_MAP];
    }
}



@synthesize activeSurveyURL = _activeSurveyURL;

- (NSURL *)activeSurveyURL
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_KEY_URL_FOR_ACTIVE_SURVEY];
    if ([value isKindOfClass:[NSString class]]) {
        value = [NSURL URLWithString:value];
    }
    return value ? value : DEFAULTS_DEFAULT_URL_FOR_ACTIVE_SURVEY;
}

- (void)setactiveSurveyURL:(NSURL *)activeSurveyURL
{
    NSString *string = activeSurveyURL.absoluteString;
    if ([string isEqualToString:DEFAULTS_DEFAULT_URL_FOR_ACTIVE_SURVEY]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_URL_FOR_ACTIVE_SURVEY];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:string forKey:DEFAULTS_KEY_URL_FOR_ACTIVE_SURVEY];
    }
}



@synthesize surveys = _surveys;

- (NSArray *) surveys
{
    NSArray *value = [[NSUserDefaults standardUserDefaults] arrayForKey:DEFAULTS_KEY_SORTED_SURVEY_LIST];
    //NSDefaults returns a NSArray of NSString, convert to a NSArray of NSURL
    value = [value mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        return [NSURL URLWithString:obj];
    }];
    return value ? value : DEFAULTS_DEFAULT_SORTED_SURVEY_LIST;
}

- (void) setSurveys:(NSArray *)surveys
{
    //NSURL is not a property list type (NSDefaults can't persist an array of NSURL
    //I need to convert it to and array of NSString
    NSArray *strings = [surveys mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        return ((NSURL *)obj).absoluteString;
    }];
    if ([strings isEqual:DEFAULTS_DEFAULT_SORTED_SURVEY_LIST]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_SORTED_SURVEY_LIST];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:strings forKey:DEFAULTS_KEY_SORTED_SURVEY_LIST];
    }
}



@synthesize hideRemoteMaps = _hideRemoteMaps;

- (BOOL) hideRemoteMaps
{
    BOOL value = [[NSUserDefaults standardUserDefaults] boolForKey:DEFAULTS_KEY_HIDE_REMOTE_MAPS];
    return value ? value: DEFAULTS_DEFAULT_HIDE_REMOTE_MAPS;
}

- (void) setHideRemoteMaps:(BOOL)hideRemoteMaps
{
    if (hideRemoteMaps == DEFAULTS_DEFAULT_HIDE_REMOTE_MAPS)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_HIDE_REMOTE_MAPS];
    else
        [[NSUserDefaults standardUserDefaults] setBool:hideRemoteMaps forKey:DEFAULTS_KEY_HIDE_REMOTE_MAPS];
}



@synthesize hideRemoteProtocols = _hideRemoteProtocols;

- (BOOL) hideRemoteProtocols
{
    bool value = [[NSUserDefaults standardUserDefaults] boolForKey:DEFAULTS_KEY_HIDE_REMOTE_PROTOCOLS];
    return value ? value : DEFAULTS_DEFAULT_HIDE_REMOTE_PROTOCOLS;
}

- (void) setHideRemoteProtocols:(BOOL)hideRemoteProtocols
{
    if (hideRemoteProtocols == DEFAULTS_DEFAULT_HIDE_REMOTE_PROTOCOLS)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_HIDE_REMOTE_PROTOCOLS];
    else
        [[NSUserDefaults standardUserDefaults] setBool:hideRemoteProtocols forKey:DEFAULTS_KEY_HIDE_REMOTE_PROTOCOLS];
}



@synthesize urlForMaps = _urlForMaps;

- (NSURL *)urlForMaps
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_KEY_URL_FOR_MAPS];
    if ([value isKindOfClass:[NSString class]]) {
        value = [NSURL URLWithString:value];
    }
    return value ? value : DEFAULTS_DEFAULT_URL_FOR_MAPS;
}

- (void)setUrlForMaps:(NSURL *)urlForMaps
{
    NSString *string = urlForMaps.absoluteString;
    if ([string isEqualToString:DEFAULTS_DEFAULT_URL_FOR_MAPS]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_URL_FOR_MAPS];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:string forKey:DEFAULTS_KEY_URL_FOR_MAPS];
    }
}



@synthesize urlForProtocols = _urlForProtocols;

- (NSURL *)urlForProtocols
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_KEY_URL_FOR_PROTOCOLS];
    if ([value isKindOfClass:[NSString class]]) {
        value = [NSURL URLWithString:value];
    }
    return value ? value : DEFAULTS_DEFAULT_URL_FOR_PROTOCOLS;
}

- (void)setUrlForProtocols:(NSURL *)urlForProtocols
{
    NSString *string = urlForProtocols.absoluteString;
    if ([string isEqualToString:DEFAULTS_DEFAULT_URL_FOR_PROTOCOLS]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_URL_FOR_PROTOCOLS];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:string forKey:DEFAULTS_KEY_URL_FOR_PROTOCOLS];
    }
}



@synthesize autoPanMode = _autoPanMode;

- (MapAutoPanState) autoPanMode
{
    NSInteger archivedInt = [[NSUserDefaults standardUserDefaults] integerForKey:DEFAULTS_KEY_AUTOPAN_MODE];
    MapAutoPanState value = archivedInt <= 0 ? DEFAULTS_DEFAULT_AUTOPAN_MODE : (NSUInteger)archivedInt;
    return value;
}

- (void) setAutoPanMode:(MapAutoPanState)autoPanMode
{
    if (autoPanMode == DEFAULTS_DEFAULT_AUTOPAN_MODE)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_AUTOPAN_MODE];
    else
        [[NSUserDefaults standardUserDefaults] setInteger:autoPanMode forKey:DEFAULTS_KEY_AUTOPAN_MODE];
}



@synthesize maxSpeedForBearing = _maxSpeedForBearing;

- (double)maxSpeedForBearing
{
    double value = [[NSUserDefaults standardUserDefaults] doubleForKey:DEFAULTS_KEY_MAX_SPEED_FOR_BEARING];
    return value ? value : DEFAULTS_DEFAULT_MAX_SPEED_FOR_BEARING;
}

- (void)setMaxSpeedForBearing:(double)maxSpeedForBearing
{
    if (maxSpeedForBearing == DEFAULTS_DEFAULT_MAX_SPEED_FOR_BEARING)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_MAX_SPEED_FOR_BEARING];
    else
        [[NSUserDefaults standardUserDefaults] setDouble:maxSpeedForBearing forKey:DEFAULTS_KEY_MAX_SPEED_FOR_BEARING];
}



@synthesize distanceUnitsForSightings = _distanceUnitsForSightings;

- (AGSSRUnit) distanceUnitsForSightings
{
    NSInteger archivedInt = [[NSUserDefaults standardUserDefaults] integerForKey:DEFAULTS_KEY_UOM_DISTANCE_SIGHTING];
    AGSSRUnit value = archivedInt <= 0 ? DEFAULTS_DEFAULT_UOM_DISTANCE_SIGHTING : (NSUInteger)archivedInt;
    return value;
}

- (void) setDistanceUnitsForSightings:(AGSSRUnit)distanceUnitsForSightings
{
    if (distanceUnitsForSightings == DEFAULTS_DEFAULT_UOM_DISTANCE_SIGHTING)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_UOM_DISTANCE_SIGHTING];
    else
        [[NSUserDefaults standardUserDefaults] setInteger:distanceUnitsForSightings forKey:DEFAULTS_KEY_UOM_DISTANCE_SIGHTING];
}



@synthesize distanceUnitsForMeasuring = _distanceUnitsForMeasuring;

- (AGSSRUnit) distanceUnitsForMeasuring
{
    NSInteger archivedInt = [[NSUserDefaults standardUserDefaults] integerForKey:DEFAULTS_KEY_UOM_DISTANCE_MEASURE];
    AGSSRUnit value = archivedInt <= 0 ? DEFAULTS_DEFAULT_UOM_DISTANCE_MEASURE : (NSUInteger)archivedInt;
    return value;
}

- (void) setDistanceUnitsForMeasuring:(AGSSRUnit)distanceUnitsForMeasuring
{
    if (distanceUnitsForMeasuring == DEFAULTS_DEFAULT_UOM_DISTANCE_MEASURE)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_UOM_DISTANCE_MEASURE];
    else
        [[NSUserDefaults standardUserDefaults] setInteger:distanceUnitsForMeasuring forKey:DEFAULTS_KEY_UOM_DISTANCE_MEASURE];
}



@synthesize angleDistanceAngleDirection = _angleDistanceAngleDirection;

- (AngleDirection) angleDistanceAngleDirection
{
    NSInteger archivedInt = [[NSUserDefaults standardUserDefaults] integerForKey:DEFAULTS_KEY_ANGLE_DISTANCE_ANGLE_DIRECTION];
    AngleDirection value = archivedInt <= 0 ? DEFAULTS_DEFAULT_ANGLE_DISTANCE_ANGLE_DIRECTION : (NSUInteger)archivedInt;
    return value;
}

- (void) setAngleDistanceAngleDirection:(AngleDirection)angleDistanceAngleDirection
{
    if (angleDistanceAngleDirection == DEFAULTS_DEFAULT_ANGLE_DISTANCE_ANGLE_DIRECTION)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_ANGLE_DISTANCE_ANGLE_DIRECTION];
    else
        [[NSUserDefaults standardUserDefaults] setInteger:angleDistanceAngleDirection forKey:DEFAULTS_KEY_ANGLE_DISTANCE_ANGLE_DIRECTION];
}



@synthesize angleDistanceDeadAhead = _angleDistanceDeadAhead;

- (double) angleDistanceDeadAhead
{
    double value = [[NSUserDefaults standardUserDefaults] doubleForKey:DEFAULTS_KEY_ANGLE_DISTANCE_DEAD_AHEAD];
    return value ? value : DEFAULTS_DEFAULT_ANGLE_DISTANCE_DEAD_AHEAD;
}

- (void) setAngleDistanceDeadAhead:(double)angleDistanceDeadAhead
{
    if (angleDistanceDeadAhead == DEFAULTS_DEFAULT_ANGLE_DISTANCE_DEAD_AHEAD)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_ANGLE_DISTANCE_DEAD_AHEAD];
    else
        [[NSUserDefaults standardUserDefaults] setDouble:angleDistanceDeadAhead forKey:DEFAULTS_KEY_ANGLE_DISTANCE_DEAD_AHEAD];
}



@synthesize angleDistanceLastDistance = _angleDistanceLastDistance;

- (NSNumber *) angleDistanceLastDistance
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_KEY_ANGLE_DISTANCE_LAST_DISTANCE];
    return [value isKindOfClass:[NSNumber class]] ? (NSNumber *)value: DEFAULTS_DEFAULT_ANGLE_DISTANCE_LAST_DISTANCE;
}

- (void) setAngleDistanceLastDistance:(NSNumber *)angleDistanceLastDistance
{
    if (angleDistanceLastDistance == DEFAULTS_DEFAULT_ANGLE_DISTANCE_LAST_DISTANCE)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_ANGLE_DISTANCE_LAST_DISTANCE];
    else
        [[NSUserDefaults standardUserDefaults] setObject:angleDistanceLastDistance forKey:DEFAULTS_KEY_ANGLE_DISTANCE_LAST_DISTANCE];
}



@synthesize angleDistanceLastAngle = _angleDistanceLastAngle;

- (NSNumber *) angleDistanceLastAngle
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_KEY_ANGLE_DISTANCE_LAST_ANGLE];
    return [value isKindOfClass:[NSNumber class]] ? (NSNumber *)value: DEFAULTS_DEFAULT_ANGLE_DISTANCE_LAST_ANGLE;
}

- (void) setAngleDistanceLastAngle:(NSNumber *)angleDistanceLastAngle
{
    if (angleDistanceLastAngle == DEFAULTS_DEFAULT_ANGLE_DISTANCE_LAST_ANGLE)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_ANGLE_DISTANCE_LAST_ANGLE];
    else
        [[NSUserDefaults standardUserDefaults] setObject:angleDistanceLastAngle forKey:DEFAULTS_KEY_ANGLE_DISTANCE_LAST_ANGLE];
}


#pragma mark - Seed NSDefaults from Settings.Bundle

//The following two methods were borrowed from the AppPrefs Sample

// -------------------------------------------------------------------------------
//  populateRegistrationDomain
//  Locates the file representing the root page of the settings for this app,
//  invokes loadDefaults:fromSettingsPage:inSettingsBundleAtURL: on it,
//  and registers the loaded values as the app's defaults.
// -------------------------------------------------------------------------------
- (void)populateRegistrationDomain
{
    NSURL *settingsBundleURL = [[NSBundle mainBundle] URLForResource:@"Settings" withExtension:@"bundle"];
    
    // loadDefaults:fromSettingsPage:inSettingsBundleAtURL: expects its caller
    // to pass it an initialized NSMutableDictionary.
    NSMutableDictionary *appDefaults = [NSMutableDictionary dictionary];
    
    // Invoke loadDefaults:fromSettingsPage:inSettingsBundleAtURL: on the property
    // list file for the root settings page (always named Root.plist).
    [self loadDefaults:appDefaults fromSettingsPage:@"Root.plist" inSettingsBundleAtURL:settingsBundleURL];
    
    // appDefaults is now populated with the preferences and their default values.
    // Add these to the registration domain.
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// -------------------------------------------------------------------------------
//  loadDefaults:fromSettingsPage:inSettingsBundleAtURL:
//  Helper function that parses a Settings page file, extracts each preference
//  defined within along with its default value, and adds it to a mutable
//  dictionary.  If the page contains a 'Child Pane Element', this method will
//  recurs on the referenced page file.
// -------------------------------------------------------------------------------
- (void)loadDefaults:(NSMutableDictionary*)appDefaults fromSettingsPage:(NSString*)plistName inSettingsBundleAtURL:(NSURL*)settingsBundleURL
{
    // Each page of settings is represented by a property-list file that follows
    // the Settings Application Schema:
    // <https://developer.apple.com/library/ios/#documentation/PreferenceSettings/Conceptual/SettingsApplicationSchemaReference/Introduction/Introduction.html>.
    
    // Create an NSDictionary from the plist file.
    NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfURL:[settingsBundleURL URLByAppendingPathComponent:plistName]];
    
    // The elements defined in a settings page are contained within an array
    // that is associated with the root-level PreferenceSpecifiers key.
    NSArray *prefSpecifierArray = [settingsDict objectForKey:@"PreferenceSpecifiers"];
    
    for (NSDictionary *prefItem in prefSpecifierArray)
        // Each element is itself a dictionary.
    {
        // What kind of control is used to represent the preference element in the
        // Settings app.
        NSString *prefItemType = prefItem[@"Type"];
        // How this preference element maps to the defaults database for the app.
        NSString *prefItemKey = prefItem[@"Key"];
        // The default value for the preference key.
        NSString *prefItemDefaultValue = prefItem[@"DefaultValue"];
        
        if ([prefItemType isEqualToString:@"PSChildPaneSpecifier"])
            // If this is a 'Child Pane Element'.  That is, a reference to another
            // page.
        {
            // There must be a value associated with the 'File' key in this preference
            // element's dictionary.  Its value is the name of the plist file in the
            // Settings bundle for the referenced page.
            NSString *prefItemFile = prefItem[@"File"];
            
            // Recurs on the referenced page.
            [self loadDefaults:appDefaults fromSettingsPage:prefItemFile inSettingsBundleAtURL:settingsBundleURL];
        }
        else if (prefItemKey != nil && prefItemDefaultValue != nil)
            // Some elements, such as 'Group' or 'Text Field' elements do not contain
            // a key and default value.  Skip those.
        {
            [appDefaults setObject:prefItemDefaultValue forKey:prefItemKey];
        }
    }
}

@end
