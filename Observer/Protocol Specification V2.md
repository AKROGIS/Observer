Park Observer Protocol Specification, Version 2
===============================================

_If you just want a protocol for a new survey, please start with the_ [tutorial instructions](https://akrgis.nps.gov/Observer/new_survey.html)_ and _[examples](https://akrgis.nps.gov/Observer/protocols/)_.  This document is a detailed reference of all the components of a protocol file._

The protocol file is a [JSON](http://www.json.org) file encoded in [UTF8](http://www.fileformat.info/info/unicode/utf8.htm).  The file name must end with `.obsprot`, which is short for __obs__ervation __prot__ocol.

The file contains one [object](http://www.json.org) with the following members:

* [meta-name](#meta-name)
* [meta-version](#meta-version)
* [name](#name)
* [version](#version)
* [date](#date)
* [description](#description)
* [observing](#observing)
* [notobserving](#notobserving)
* [status_message_fontsize](#status_message_fontsize)
* [cancel_on_top](#cancel_on_top)
* [gps_interval](#gps_interval)
* [mission](#mission)
* [features](#features)
* [csv](#csv)

The members can appear in any order, but usually as shown above.  Member names are case-sensitive. This is also true for all the objects described below.

# meta-name
This member is required, and must be a [string](http://www.json.org) equal to `"NPS-Protocol-Specification"`. This designates that the file subscribes to these specifications.

# meta-version
This member is required, and must be an integral [number](http://www.json.org). This member designates the version of the specification defining the content of the protocol file. At this time, the only valid values are `1` and `2`.  This specification describes `"meta-version":2`.  Version `1` is no longer supported.

# name
This member is required, and must be a string. This is a short moniker used to reference this protocol. It will be used in lists to choose among different protocols.

Names do not need to be unique, but having two protocols with the same name can cause confusion. Protocols can evolve (see [version](#version) and [date](#date)).  The same name should be used for different version of the same protocol.

Technically, a name is not required by the Park Observer application. However, the post processing tools (like the upload server and the POZ to FGDB translator) require a name.
A protocol without a name is very hard to work with.

# version
This member is required, and must be a number. The version number looks like a floating point number (i.e. `2.1`) but is actually two integers separated by a decimal point.
The first integer is the major version number the second integer is the minor version number.
The version number is used to track the evolution of a named protocol.
The version number will be displayed along with the name when presenting a list of protocols.

A change in the major version number represents a change in the database structure of the protocol.
If you add, remove, rename, or change the type of mission or feature attributes (defined below), then you should update the major version number of your protocol.
Databases created with the postprocessing tools will be named with the protocol name and the major version number.
All surveys with the same protocol name and major version number will go into the same database.
Surveys with the same protocol name and a different major version number will go into different databases.
Databases created with different major version numbers of the same protocol will be difficult to merge because the database structure is different.

Any other changes to a protocol should be accompanied by an increase in the minor version number.
For example, changes in symbology, location methods, and default or picklist values.

Technically, a version is not required by the Park Observer application.  However, the post processing tools require a major version number.
A protocol without a version number is easily confused with other protocols with the same name.

# date
This member is optional.  If provided it should be a string that represent the date (but not time) in the ISO format (i.e. `2016-05-24`) that the protocol file was last modified.
If provided, the date will be used in lists to help choose among different protocols. If the date is missing, the wrong type, or an invalid date, then the date will be `null`.

# description
This member is optional, and must be a string.
The description can be used to provide more information about the protocol than is available in the protocol name.

# observing
This member is optional. If provided it should a string.
If a non-empty string is provided it will be displayed on the map when the Park Observer application is recording __and__ observing (i.e. on-transect).

This member is ignored in versions of Park Observer before 0.9.8b.

# notobserving
This member is optional. If provided it should a string.
If a non-empty string is provided it will be displayed on the map when the Park Observer application is recording __but not__ observing (i.e. off-transect).

This member is ignored in versions of Park Observer before 0.9.8b.

# status_message_fontsize
This member is optional. If omitted, or if any value besides a number is provided, it will default to `16.0`.
This member specifies the size (in points) of the [notobserving](#notobserving) text. The [observing](#observing) text will always be 2.0 points larger, bold, and red.
This member is ignored if neither `notobserving` nor `observing` are provided.

This member is ignored in versions of Park Observer before 1.2.0.

# cancel_on_top
This member is optional.  If omitted, or if any value besides `true` is provided, it will default to `false`.
If `true` the attribute editors will put the `cancel` or `delete` button on the top of the attribute editing forms, otherwise the button will be on the bottom of the form.

This member is ignored in versions of Park Observer before 0.9.8b.

# gps_interval
This member is optional.  If provided it should be the number of seconds to wait between adding new GPS points to the tracklog.
When making observations, or starting/stopping recording/observing the most recently available GPS point will be used regardless of this setting.
If omitted, or any non-numeric value is provided, points are added to the tracklog as often as provided by the GPS device being used.  Typically the iPad's builtin GPS provides locations about 1 per second.  Some external GPS devices can provide multiple locations per second.

This member is ignored in versions of Park Observer before 0.9.8b.

# mission
This member is required and must be an object with the following members:

* [attributes](##attributes)
* [dialog](##dialog)
* [symbology](##symbology)
* [on-symbology](##on-symbology)
* [off-symbology](##off-symbology)
* [gps-symbology](##gps-symbology)
* [totalizer](##totalizer)
* [edit_at_start_recording](##edit_at_start_recording)
* [edit_at_start_first_observing](##edit_at_start_first_observing)
* [edit_at_start_reobserving](##edit_at_start_reobserving)
* [edit_prior_at_stop_observing](##edit_prior_at_stop_observing)
* [edit_at_stop_observing](##edit_at_stop_observing)

The mission describes the attributes and symbology of the mission.

## attributes

The mission attributes are often things like the names of the observers, and the weather.

A mission does need to have any attributes.  In this case, only the status of observing (yes/no)
is recorded for each tracklog segment.

Each attribute must have a "name" element

The name element must be unique within a feature.  Different features can have attributes with the same name, but if they do they must have the same type.  Mission property and feature attributes are unrelated -- they can have the same name with different types.

It will be used as a database column name, so it should be a simple ASCII name without spaces or special characters

It will be prefixed internally to avoid clashes with reserved words

Each attribute must have a "type" element
The type is an integer code with the following definitions (from NSAttributeType)
- 100 -> 16bit integer
- 200 -> 32bit integer
- 300 -> 64bit integer
- 400 -> NSDecimal (currently not supported by ESRI)
- 500 -> double precision floating point number
- 600 -> single precision floating point number
- 700 -> string
- 800 -> boolean (converts to an ESRI integer 0 = NO, 1 = YES)
- 900 -> datetime
- 1000 -> binary blob (? no UI support, check on ESRI support)

## dialog
Provides the look and feel of the attribute input form presented to the user.
Only required if the mission has attributes.
See the QuickDialog documentation for details.

## symbology
Defines how the track log start and stop points will be displayed on the map.
  - The symbology may have an optional "color" element
    - The color element is a string in the form "#FFFFFF", where F is a hexadecimal digit.
    - The Hex pairs represent the Red, Green, and Blue respectively.
    - The default if not provided, or malformed is "#000000" (black)
  - The symbology may have an optional "size" element
    - The size is an integer number for the size in points of the simple circle marker symbol
    - The default is 12 if not provided.
  - Alternatively, advanced symbology can be created by
  providing the symbology JSON for an ESRI Renderer as defined in http://resources.arcgis.com/en/help/rest/apiref/renderer.html

## on-symbology
Defines the symbology of the track log lines while observing (or on-transect).
The defaults is a one point wide solid black line.  If valid `size` or `color`
members are provided as discussed above they will change the width and color of
the line respectively.  Alternatively, advanced symbology can be created by
providing the symbology JSON for an ESRI Renderer as defined in http://resources.arcgis.com/en/help/rest/apiref/renderer.html

## off-symbology
Same as on-symbology above, but for the track log lines while recording,
but not observing.

## gps-symbology
Same as the symbology above, but for the gps points.

Are GPS points shown when a survey/map is closed and re-opened?

This member is ignored in versions of Park Observer before 0.9.8.  In that case,
all gps points are rendered as blue 6 point circles.

**Note** The track log start and stop points will be drawn on top of the
gps points, which are drawn on top of the track log lines. This will affect
the display of the symbols, and therefore how you might choose your symbology.

## totalizer
This member is optional, but if provided it should be an object with the following members:

* [fields](###fields)
* [units](###units)
* [fontsize](###fontsize)
* [includeon](###includeon)
* [includeoff](###includeoff)
* [includetotal](###includetotal)

The totalizer is used to define the parameters for collecting and displaying a mission  totalizer.   This is used to provide information on how long the user has been observing for a given set of conditions, usually this is just the transect id.  In this case, the totalizer show how long the user has been observing on a current transect.

This member is ignored in versions of Park Observer before 0.9.8b.

### fields
A required array of field names (strings). When any of the fields change, a different total is displayed. There must be at least on field (string) in the array which matches the name of one of the attributes in the mission.
### units
An optional element with a value of "kilometers" or "miles" or "minutes". Default is "kilometers"

### fontsize
An optional floating point value that indicate the size (in points) of the totalizer text.  The default is 14.0

This member is ignored in versions of Park Observer before 1.2.0.

### includeon
A boolean value (true/false), that indicate is the total while "observing" is true should be displayed.  The default is  true

### includeoff
A boolean value (true/false), that indicate if the total while "observing" is false should be displayed.  The default is  false

### includetotal
A boolean value (true/false), that indicate if the total regardless of "observing" status should be displayed.  The default is  false

## edit_at_start_recording
An optional boolean value that defaults to true.  If true, then editor will be displayed when start recording button is pushed.

## edit_at_start_first_observing
An optional boolean value that defaults to false.  If true, then editor will be displayed when start observing button is pushed after start recording.

## edit_at_start_reobserving
An optional boolean value that defaults to true.  If true, then editor will be displayed when start observing button is pushed after stop observing.

## edit_prior_at_stop_observing
An optional boolean value that defaults to false.  If true, then editor will be displayed for prior track log when done observing (stop observing or stop recording button).

## edit_at_stop_observing
An optional boolean value that defaults to false.  If true, then editor will be displayed when when done observing (stop observing or stop recording button).

**Note:** Due to a bug, only one of `edit_prior_at_stop_observing` and `edit_at_stop_observing` should be set to true.  If both are set to true, `edit_prior_at_stop_observing` is ignored  (you can edit the prior mission property by taping the marker on the map).



# features
This member is required and must be an [array](http://www.json.org) of objects with the following members:

* [name](##name)
* [allow_off_transect_observations](##allow_off_transect_observations)
* [attributes](##attributes (feature))
* [locations](##locations)
* [dialog](##dialog)
* [label](##label)
* [symbology](##symbology)

A feature is a kind of thing that will be observed during your survey. Often it is an animal species. It is defined by a list of attributes that you will collect every time you observe the feature. You can have multiple features in your protocol, however many surveys only observe one feature.  The number of features in a protocol file should be kept as small as possible to keep the survey focused and easier.

## name
Each feature must have a unique name. The name can be any sequence of characters, and must be enclosed in quotes.

The name is used in the interface to let the user choose among different feature types
It should be short and descriptive.

## allow_off_transect_observations
An optional boolean value that defaults to false.  If true, then this feature can be observed while off transect (not observing)

## attributes
The attributes (i.e. fields or columns) that describe this feature.  This member is specified exactly the same as the mission [attributes](##attributes2).  See that section for details.

A feature with no attributes, only collects a location (and the type of the feature).

## locations
This member is required and must be an array of objects with the following members:

* [type](###type)
* [default](###default)
* [allow](###allow)
* [deadAhead](###deadAhead)
* [direction](###direction)
* [units](###units)

This member is a list of methods for locating an feature that will be considered by the application. Providing multiple location methods with the same [type](###type) is allowed but discouraged as the behavior is undefined.

If the locations array is empty, then the types [gps, mapTarget, and mapTouch] are allowed,
and gps is the default non-touch location method.

For other behavior, only the location methods that are allowed need to
be provided, however other methods can be listed as not allowed for completeness.

### type
This member is required. It must be one of the following strings:

* [gps](####gps)
* [mapTarget](####mapTarget)
* [mapTouch](####mapTouch)
* [angleDistance](####angleDistance)

Any location type containing the text `Touch` is a touch location, the others are non-touch locations.

#### gps
The feature is located at the current GPS position.  These observations cannot be moved.

#### mapTarget
The feature is located at the point on the map under the target (cross-hairs) at the center
of the device screen.  These observations can be moved.

#### mapTouch
The feature is located at the point on the map where the user taps.  These observations can be moved.

#### angleDistance
The feature is located a certain angle (relative to the forward motion of the GPS, or the north if not moving) and distance from the current GPS position.  These observations cannot be moved.

### default
This member is optional.  If not provided or not `true`, it is assumed to be `false`.
If `true` then this will be the default location method used when the feature button is tapped in
the app. Only one non-touch locations should have a `true` value, otherwise the behavior is undefined.  This member is ignored for the touch location.

### allow
This member is optional.  If not provided or not `false`, it is assumed to be `true`.
If the value is `false`, this type of location method is not allowed.  This is equivalent to not providing this location type in the list of locations.

### deadAhead
This member is optional and is ignored for all location [type](###type)s except [angleDistance](####angleDistance).
If provided it should be a number between `0.0` and `360.0`.
If not provided, or not a valid number, it will default to `0.0`

The numeric value provided is the angle measurement in degrees that means the feature is dead ahead if the GPS is moving, or north if the GPS is stationary.

### direction
This member is optional and is ignored for all location [type](###type)s except [angleDistance](####angleDistance).
If not provided, or not a valid string, the default is "cw".
A value of `cw` indicates that angles increase in a clockwise direction.
A value of `ccw` indicates that angles increase in a counter-clockwise direction.

### units
This member is optional and is ignored for all location [type](###type)s except [angleDistance](####angleDistance).
This is the length units that qualify the distance from the GPS to the feature.
If not provided, or not a valid string, the default is "meters". Options are:

  - meters or meter, metre, metres
  - feet or foot
  - yards or yard

## dialog
The attributes (i.e. fields or columns) that describe this feature.  This member is specified exactly the same as the mission [attributes](##attributes2).  See that section fro details.

## label
This member is optional.  If provided, it defines how the feature will be labeled on the map
  - The label should have a `field` element
    - where `field` is a string which references one of the attributes for this feature
    - If the `field` is not provided, or can't be found in the feature attributes, no label is shown
  - The label may have an optional `color` element
    - The color element is a string in the form `#FFFFFF`
    - where F is a hexadecimal digit
    - The Hex pairs represent the Red, Green, and Blue respectively.
    - The default if not provided, or malformed is "#FFFFFF" (white)
  - The label may have an optional `size` element
    - The `size` is an integer number for the size in points of the label
    - The default is 14 if not provided.
  - The `label` may have an optional `symbol` element
    - `symbol` is a JSON object as described in the Text Symbol section of the ArcGIS ReST API (http://resources.arcgis.com/en/help/arcgis-rest-api/#/Symbol_Objects/02r3000000n5000000/)
    - if the JSON object is malformed or unrecognized, then it is ignored
    - if the symbol is valid, then `size` and `color` elements of `label` are ignored in deference to the values in `symbol`.
    - Not all fields in the ESRI rest API need to be provided, when defaults are obvious; i.e. `"label":""` and `"angle":0` (I have not tested everything).
    `type` is required and must be one of simple, uniqueValue, classBreak
    TODO test which other fields are required, and document the defaults

## symbology (feature)
This determines how the features are rendered on the map.  This member is
specified exactly the same as the mission [symbology](##symbology).  See that
section for details.

# csv
This member is optional.  At this time, this member is not used by the Park Observer application.  It serves to define the format of the CSV export files created by the application for your protocol.  The format of the CSV files created by the application is currently not configurable, so this member must the CSV format hard coded into the Park Observer application. A future version of Park Observer may use this member to allow users to configure the format of the exported CSV files.

If provided it must be a object identical to [csv.json](https://akrgis.nps.gov/observer/syncserver/csv.json).  If provided, it will be used by post processing tools like the upload server and the POZ to FGDB translator to understand how the CSV export files are formatted. If it is not provided, the upload server, and the POZ to FGDB translator will use [csv.json](https://akrgis.nps.gov/observer/syncserver/csv.json).
