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

#define DEFAULTS_KEY_NAME_OF_ACTIVE_MAP_PROPERTIES @"url_for_active_map_properties"
#define DEFAULTS_DEFAULT_NAME_OF_ACTIVE_MAP_PROPERTIES nil

#define DEFAULTS_KEY_NAME_OF_ACTIVE_SURVEY @"url_for_active_survey"
#define DEFAULTS_DEFAULT_NAME_OF_ACTIVE_SURVEY nil

#define DEFAULTS_KEY_SORTED_MAP_LIST @"sorted_map_list"
#define DEFAULTS_DEFAULT_SORTED_MAP_LIST nil

#define DEFAULTS_KEY_SORTED_SURVEY_LIST @"sorted_survey_list"
#define DEFAULTS_DEFAULT_SORTED_SURVEY_LIST nil

#define DEFAULTS_KEY_MAP_REFRESH_DATE @"map_refresh_date"
#define DEFAULTS_DEFAULT_MAP_REFRESH_DATE nil

#define DEFAULTS_KEY_HIDE_REMOTE_MAPS @"hide_remote_maps"
#define DEFAULTS_DEFAULT_HIDE_REMOTE_MAPS NO

#define DEFAULTS_KEY_HIDE_REMOTE_PROTOCOLS @"hide_remote_protocols"
#define DEFAULTS_DEFAULT_HIDE_REMOTE_PROTOCOLS NO

#define DEFAULTS_KEY_URL_FOR_MAPS @"url_for_maps"
#define DEFAULTS_DEFAULT_URL_FOR_MAPS nil

#define DEFAULTS_KEY_URL_FOR_PROTOCOLS @"url_for_protocols"
#define DEFAULTS_DEFAULT_URL_FOR_PROTOCOLS nil

#define DEFAULTS_KEY_URL_FOR_SURVEY_UPLOAD @"url_for_survey_upload"
#define DEFAULTS_DEFAULT_URL_FOR_SURVEY_UPLOAD nil

#define DEFAULTS_KEY_AUTOPAN_MODE @"autopan_mode"
#define DEFAULTS_DEFAULT_AUTOPAN_MODE kNoAutoPanNoAutoRotateNorthUp

#define DEFAULTS_KEY_UOM_DISTANCE_MEASURE @"uom_distance_measure"
#define DEFAULTS_DEFAULT_UOM_DISTANCE_MEASURE AGSSRUnitStatuteMile


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



- (NSString *)activeMapPropertiesName
{
    NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_KEY_NAME_OF_ACTIVE_MAP_PROPERTIES];
    return value ? value : DEFAULTS_DEFAULT_NAME_OF_ACTIVE_MAP_PROPERTIES;
}

- (void)setActiveMapPropertiesName:(NSString *)activeMapPropertiesName
{
    if ([activeMapPropertiesName isEqual:DEFAULTS_DEFAULT_NAME_OF_ACTIVE_MAP_PROPERTIES]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_NAME_OF_ACTIVE_MAP_PROPERTIES];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:activeMapPropertiesName forKey:DEFAULTS_KEY_NAME_OF_ACTIVE_MAP_PROPERTIES];
    }
}



- (NSString *)activeSurveyName
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_KEY_NAME_OF_ACTIVE_SURVEY];
    return value ? value : DEFAULTS_DEFAULT_NAME_OF_ACTIVE_SURVEY;
}

- (void)setActiveSurveyName:(NSString *)activeSurveyName
{
    if ([activeSurveyName isEqual:DEFAULTS_DEFAULT_NAME_OF_ACTIVE_SURVEY]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_NAME_OF_ACTIVE_SURVEY];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:activeSurveyName forKey:DEFAULTS_KEY_NAME_OF_ACTIVE_SURVEY];
    }
}



- (NSArray *) maps
{
    NSArray *value = [[NSUserDefaults standardUserDefaults] arrayForKey:DEFAULTS_KEY_SORTED_MAP_LIST];
    //NSDefaults returns a NSArray of NSString
    return value ? value : DEFAULTS_DEFAULT_SORTED_MAP_LIST;
}

- (void) setMaps:(NSArray *)maps
{
    if ([maps isEqual:DEFAULTS_DEFAULT_SORTED_MAP_LIST]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_SORTED_MAP_LIST];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:maps forKey:DEFAULTS_KEY_SORTED_MAP_LIST];
    }
}



- (NSArray *) surveys
{
    NSArray *value = [[NSUserDefaults standardUserDefaults] arrayForKey:DEFAULTS_KEY_SORTED_SURVEY_LIST];
    //NSDefaults returns a NSArray of NSString
    return value ? value : DEFAULTS_DEFAULT_SORTED_SURVEY_LIST;
}

- (void) setSurveys:(NSArray *)surveys
{
    if ([surveys isEqual:DEFAULTS_DEFAULT_SORTED_SURVEY_LIST]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_SORTED_SURVEY_LIST];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:surveys forKey:DEFAULTS_KEY_SORTED_SURVEY_LIST];
    }
}



- (NSDate *)mapRefreshDate
{
    NSDate *value = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_KEY_MAP_REFRESH_DATE];
    return value ? value : DEFAULTS_DEFAULT_MAP_REFRESH_DATE;
}

- (void)setMapRefreshDate:(NSDate *)mapRefreshDate
{
    if (mapRefreshDate == DEFAULTS_DEFAULT_MAP_REFRESH_DATE)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_MAP_REFRESH_DATE];
    else
        [[NSUserDefaults standardUserDefaults] setObject:mapRefreshDate forKey:DEFAULTS_KEY_MAP_REFRESH_DATE];
}



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
    if ([string isEqual:DEFAULTS_DEFAULT_URL_FOR_MAPS]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_URL_FOR_MAPS];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:string forKey:DEFAULTS_KEY_URL_FOR_MAPS];
    }
}



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
    if ([string isEqual:DEFAULTS_DEFAULT_URL_FOR_PROTOCOLS]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_URL_FOR_PROTOCOLS];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:string forKey:DEFAULTS_KEY_URL_FOR_PROTOCOLS];
    }
}


- (NSURL *)urlForSurveyUpload
{
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:DEFAULTS_KEY_URL_FOR_SURVEY_UPLOAD];
    if ([value isKindOfClass:[NSString class]]) {
        value = [NSURL URLWithString:value];
    }
    return value ? value : DEFAULTS_DEFAULT_URL_FOR_SURVEY_UPLOAD;
}

- (void)setUrlForSurveyUpload:(NSURL *)urlForSurveyUpload
{
    NSString *string = urlForSurveyUpload.absoluteString;
    if ([string isEqual:DEFAULTS_DEFAULT_URL_FOR_SURVEY_UPLOAD]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:DEFAULTS_KEY_URL_FOR_SURVEY_UPLOAD];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:string forKey:DEFAULTS_KEY_URL_FOR_SURVEY_UPLOAD];
    }
}


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
    NSURL *url = [settingsBundleURL URLByAppendingPathComponent:plistName];
    NSDictionary *settingsDict = (url == nil) ? nil : [NSDictionary dictionaryWithContentsOfURL:url];
    
    // The elements defined in a settings page are contained within an array
    // that is associated with the root-level PreferenceSpecifiers key.
    NSArray *prefSpecifierArray = settingsDict[@"PreferenceSpecifiers"];
    
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
            appDefaults[prefItemKey] = prefItemDefaultValue;
        }
    }
}

@end
