Protocol Specification -- 1.x
=============================

*This document is for Park Observer 1.x.  If you are using Park Observer 2.0
please see [this version](Protocol_Specification_V2.html).* 

*If you are new to Park Observer, please start with the
[tutorial instructions](../new_survey.html) and [examples](../protocols/).*

This document is a technical reference for the structure and accepted content of the Park Observer protocol file.
A more general reference can be found in the [Protocol Guide](Protocol_Guide_V1.html)

This specification describes version 1 (v1) and 2 (v2) of the protocol file.
Items that were introduced in version 2 are marked (v2).
Since most of the items introduced in v2 are optional and do not conflict with
v1, Park Observer will honor v2 items even if found in a v1 file.
Symbology is a notable exception and will be discussed in detail.
For clarity you are encouraged to use a v2 protocol file (defined below) when using v2 items.

The protocol file is a plain text file in `JSON` (javascript object notation) format.
The file typically contains only `ASCII` characters.
If special characters (accents marks, emoji, etc.) are needed, the file must be encoded in `UTF8`.
The protocol file name must end with `.obsprot`, which is short for observation protocol.

A protocol file contains one JSON object.
An object begins with an opening curly bracket (`{`) and ends with an closing curly bracket (`}`)
An object is a list of properties (name-value pairs) separated by a comma(`,`).
Property names must be enclosed in double quotes (`"`) and are case sensitive.
A colon (`:`) separates the property name from the property value.
A property value can be an object, a text string enclosed in double quotes (`"`),
a number, or one of the special symbols: `true`, `false`, and `null`.
A property value can also be a list of property values.
A list begins with an opening square bracket (`[`), and ends with a closing square bracket (`]`).
Items in the list are separated by a comma (`,`).

The official specifications of the JSON file format can be found at http://www.json.org/.
The JSON file format is very specific and it is easy to introduce errors when editing by
hand.  There are a number of online JSON linters (e.g. https://jsonlint.com) that will
check your protocol file to ensure it is valid JSON.  Most linters will also provide suggestions
for how to fix invalid JSON.

A JSON linter will only check for valid JSON, it will not check for compliance with
this document. For that you will need to use a Schema Validator.
This specification is also defined in a machine readable form in
[`protocol.v1.schema.json`](protocol.v1.schema.json)
and [`protocol.v2.schema.json`](protocol.v2.schema.json).
These schemas are also JSON files in the
[JSON Schema](http://json-schema.org/) format.
These schema files can be used to validate a protocol file to ensure that it is not just valid
JSON, but meets the requirements of this specification.
One example of an online validator is https://www.jsonschemavalidator.net.

**IMPORTANT:**
This specification and the related schema documents, define the proper format of the
`obsprot` file.  It is possible that the implementation in Park Observer is more relaxed.
For example Park Observer might provide default values when a required value is missing,
or accept different spellings, but that behavior is subject to change without notice.

The JSON object in the protocol file understands properties with the following names.
Properties can appear in any order, but usually in the order shown.
Properties marked with an (o) are optional; the others are required.

* [`meta-name`](#-meta-name-)
* [`meta-version`](#-meta-version-)
* [`name`](#-name-)
* [`version`](#-version-)
* [`date`](#-date-) (o)
* [`description`](#-description-) (o)
* [`observing`](#-observing-) (o)(v2)
* [`notobserving`](-notobserving-) (o)(v2)
* [`status_message_fontsize`](#-status_message_fontsize-) (o)(v2)
* [`cancel_on_top`](#-cancel_on_top-) (o)(v2)
* [`gps_interval`](#-gps_interval-) (o)(v2)
* [`mission`](#-mission-) (o)
* [`features`](#-features-)
* [`csv`](#-csv-) (o)

Each of these properties are defined in the following sections.

# `meta-name`
This property is required and must be a string equal to `"NPS-Protocol-Specification"`.
This property designates the file as subscribing to these specifications.

# `meta-version`
This property is required and must be an integer.
This property designates the version of the specification defining the content of the protocol file.
At this time, the only valid values are `1` and `2`.
Version `1` has been deprecated.

# `name`
This property is required and must be a string.
This is a short moniker used to reference this protocol.
It will be used in lists to choose among different protocols.

Names do not need to be unique, but having two protocols with the same name can cause confusion.
Protocols can evolve (see [`version`](#-version-) and [`date`](#-date-)).
The same name should be used for different version of the same protocol.

Technically, a name is not required by the Park Observer application.
However, the post processing tools (like the POZ to FGDB translator) require a name.
A protocol without a name is very hard to work with.

# `version`
This property is required and must be a number.
The version number looks like a floating point number (i.e. `2.1`)
but is actually two integers separated by a decimal point.
The first integer is the major version number the second integer is the minor version number.
The version number is used to track the evolution of a named protocol.
The version number will be displayed along with the name when presenting a list of protocols.

A change in the major version number represents a change in the database structure of the protocol.
If you add, remove, rename, or change the type of mission or feature attributes (defined below),
then you should update the major version number of your protocol.
Databases created with the post-processing tools will be named with the protocol name and the major version number.
All surveys with the same protocol name and major version number can go into the same database.
Surveys with the same protocol name and a different major version number will go into different databases.
Databases created with different major version numbers of the same protocol will be difficult
to merge because the database structure is different.

Any other changes to a protocol should be accompanied by an increase in the minor version number.
For example, changes in symbology, location methods, and default or pick list values.

Technically, a version is not required by the Park Observer application.
However, the post processing tools require a major version number.
A protocol without a version number is easily confused with other protocols with the same name.

Because the major/minor version is a single number in the JSON file, the minor version number is
limited to the range 0..9.  This is due to the fact that 1.20 is the same number as 1.2, so the
minor number in both cases will be 2.  There is no limit to the major version.

# `date`
This property is optional. There is no default value.
If provided it must be a string that represent the date (but not time)
in the ISO format `YYYY-MM-DD` (e.g. `"2016-05-24"`).
This should be the date that the protocol file was last modified.
If provided, the date will be used in lists to help choose among different protocols.
If the date is missing, the wrong type, or an invalid date,
then the Park Observer will consider the date unknown.

# `description`
This property is optional. If provided it must be a string. There is no default value.
The description can be used to provide more information about the protocol than is available
in the protocol name.nIt typically describes who wrote the protocol and which surveys or
organizations it supports. Contact information can also be included.

# `observing`
This property is optional. If provided it must be a string. There is no default value.
If a non-empty string is provided it will be displayed on the map when the Park Observer
application is recording __and__ observing (i.e. on-transect).

This property is ignored in versions of Park Observer before 0.9.8b.

# `notobserving`
This property is optional. If provided it must be a string. There is no default value.
If a non-empty string is provided it will be displayed on the map when the Park Observer
application is recording __but not__ observing (i.e. off-transect).

This property is ignored in versions of Park Observer before 0.9.8b.

# `status_message_fontsize`
This property is optional. If provided it must be a number. If omitted or invalid it will default to `16.0`.
This property specifies the size (in points, i.e. 1/72 of an inch) of the `notobserving` text.
The `observing` text will always be 2.0 points larger, bold, and red.
This property is ignored if `notobserving` and `observing` are not provided.

This property is ignored in versions of Park Observer before 1.2.0.

# `cancel_on_top`
This property is optional.  If provided it must be `true` or `false`. The default is `false`.
If `true` the attribute editors will put the **Cancel/Delete** button on the top of
the attribute editing forms, otherwise the button will be on the bottom of the form.

This property is ignored in versions of Park Observer before 0.9.8b.

# `gps_interval`
This property is optional.  If provided it must be a positive number.  There is no default.
The property is the number of seconds to wait between adding new GPS points to the track log.
When making observations, or starting/stopping recording/observing the most recently available
GPS point will be used regardless of this setting.
If omitted, or not a positive number, GPS points are added to the track log as often as provided
by the GPS device being used.  Typically the iPad's builtin GPS provides locations about 1 per second.
Some external GPS devices can provide multiple locations per second.
A number lower than the device can support will effectively be ignored.
Using an interval greater than the GPS can support may reduce battery consumption by allowing the GPS to rest.

This property is ignored in versions of Park Observer before 0.9.8b.



# `mission`

This property is optional.  If provided it must be an object.  There is no default.
This object describes the attributes and symbology of the survey mission.
The attributes are things that may be constant for the entire survey, i.e. observer name, as
well as dynamic attributes like the weather that may apply to many observations.
It also describes the look and feel of the editing form and when the attributes should be edited.

A `mission` object has the following properties:

* [`attributes`](#-attributes-) (o)
* [`dialog`](#-dialog-) (o)
* [`edit_at_start_recording`](#-edit_at_start_recording-) (o)(v2)
* [`edit_at_start_first_observing`](#-edit_at_start_first_observing-) (o)(v2)
* [`edit_at_start_reobserving`](#-edit_at_start_reobserving-)(o)(v2)
* [`edit_prior_at_stop_observing`](#-edit_prior_at_stop_observing-) (o)(v2)
* [`edit_at_stop_observing`](#-edit_at_stop_observing-) (o)(v2)
* [`symbology`](#-symbology-)
* [`on-symbology`](#-on-symbology`-) (o)
* [`off-symbology`](#-off-symbology-) (o)
* [`gps-symbology`](#-gps-symbology-) (o)(v2)
* [`totalizer`](#-totalizer-) (o)(v2)

Each of these properties are defined in the following sections.

## `attributes`
An optional list of attribute objects.
The attributes are descriptive characteristics for each segment of the survey.
A mission with no attributes only collects the location where the the user
stopped and started observing (i.e. went on/off transect). The mission
attributes are often things like the names of the observers, and the weather.

All the attributes default to a value of `null` until they are edited.
The exceptions are boolean attributes which defaults to `false`, and `id` attributes which default to `1`.
All attributes, except the `id` will never change unless you also have a `dialog` property.
An Attribute of type `id` only applies to features, and is incremented for each observation.
This can provide each feature with an automatic, unique, and sequential identifier.

If there is an attribute list then there must be at least one valid attribute object in it.
Each `attribute` has the following properties:

* `name`
* `type`

### `name`
A required string identifying the attribute.  This will be the name of the column in an exported
CSV file, or a field in an ArcGIS geo-database.
The name must start with a letter or underscore (`_`), and be followed by zero or more letters, numbers,
or underscores. It must be no longer than 30 characters.
Spaces and special characters are prohibited.
Each name must be unique within the mission or feature.
Different features can have attributes with the same name, but if they do they must have the same type.
Mission attributes and feature attributes are unrelated -- they can have the same name with different types.
**Important** Do not rely on upper/lowercase to distinguish two attributes;
`Species`, `species`, and `SPECIES` are the same attribute name.
However, the names in this protocol must
match in capitalization.  If you use `Species` in a `mission.totalizer` or a `feature.label`,
it must also be referred to as `Species` in the dialog element and `Species` in the attributes list.

### `type`
A required number that identifies the type (kind) of data the attribute stores.
The type must be an integer code with the following definitions.
These numbers (with the exception of 0) correspond with NSAttributeType in the iOS SDK.

-   0 -> sequential integer id (not editable, only available in v2)
-	100 -> 16bit integer
-	200 -> 32bit integer
-	300 -> 64bit integer
-	400 -> NSDecimal (currently not supported by ESRI)
-	500 -> double precision floating point number
-	600 -> single precision floating point number
-	700 -> string
-	800 -> boolean (converts to an ESRI integer 0 = NO, 1 = YES)
-	900 -> DateTime
-	1000 -> binary blob (? no UI support, check on ESRI support)

The type 0 is ignored in versions of Park Observer before 0.9.8.

## `dialog`
This property is optional.  If provided it must be an object.  There is no default.
The dialog property describes the format of the editing form for the mission's attributes.
A dialog is not required, but the mission attributes cannot be edited without one.
If the dialog property is provided then the `attributes` property is required.
If a dialog is provided, there must be at least one section in the dialog and one element in that section.
All elements in the dialog except labels must refer to an attribute in the list of mission attributes.
It is an error if a dialog element refers to an attribute that is not in the list.

A dialog is not required because it is possible that the only attribute is a sequential Id which is
not editable and requires no dialog, or that the database schema is defined
by other drivers, and some attributes are not collected in the survey.

The dialog properties are based on the [QuickDialog](https://github.com/escoz/QuickDialog) as
the form editor. While QuickDialog may have supported more properties than defined
below, the following are the only ones typically used by Park Observer and the only
ones that will be supported in the future.

 * `title`
 * `grouped` (o)
 * `sections`

### `title`
This property is required and must be a text string.  It can be empty (`""`)
This text is placed as a title at the top of the editing form.
It is typically either `"Mission Properties"`or the name of the feature.

### `grouped`
This property is optional.  If provided it must be a boolean.  The default is `false`.
This property determines if the sections in this form are grouped
(i.e. There is visual separation between sections).

### `sections`
This property is requires and must be a list of one or section objects.
A dialog form is made up of one or more sections which group the editing controls
into logical collections. Each section object has the following properties.

* `title` (o)
* `elements`

#### `title`
This property is optional.  If provided it must be a string.  There is no default.
This text is placed as a title at the top of the section.

#### `elements`
This property is requires and must be a list of one or element objects.
Elements make up the interesting parts of the form.  They are usually tied to an attribute
and determine how the attribute can be edited.  Examples of form elements are text boxes,
on/off switches, and pick lists. Each element has the following properties.  Some
properties are only relevant for certain types of elements.
Each element object has the following properties.

 * `title` (o)
 * `type`
 * `bind` (o)
 * `items` (o)
 * `selected` (o)
 * `boolValue` (o)
 * `minimumValue` (o)
 * `maximumValue` (o)
 * `numberValue` (o)
 * `placeholder` (o)
 * `fractionDigits` (o)
 * `keyboardType` (o)
 * `autocorrectionType` (o)
 * `autocapitalizationType` (o)
 * `key` (o)

##### `title`
This property is optional.  If provided it must be a string.  There is no default.
This is a name/prompt that describes the data in this form element.  This usually appears to
the left of the attribute value in a different font. This is often the
only property used by a `QLabelElement`.

##### `type`
This property is requires and must be one of the following text strings.
It describes the display and editing properties for the form element.  Park Observer
only supports the following types.  These are case sensitive.

* `QBooleanElement` - an on/off switch, defaults to off.
* `QDecimalElement` - a "real" number editor with a limited number of digits after the decimal.
* `QEntryElement` - a single line text box.
* `QIntegerElement` - an integer input box with stepper (+1/-1) buttons.
* `QLabelElement` - non-editable text on its own line in the form.
* `QMultilineElement` - a multi-line text box.
* `QRadioElement` - A single selection pick list (as a vertical list of titles)
* `QSegmentedElement` - A single selection pick list (as a horizontal row of buttons)


##### `bind`
This property is required for all types except `QLabelElement` when it is optional.
If provided it must be a specially formatted string.  There is no default.
This string encodes the type and attribute name of the data for this element.
`QLabelElement` only uses the `value:` type when
displaying a unique feature id).  The bind value must start with one of the following:

 * `boolValue:` - a boolean (true or false) value
 * `numberValue:`
 * `selected:` - the zero based index of the selected item in `items`
 * `selectedItem:`  - the text of the selected item in `items`
 * `textValue:`
 * `value:` - used for Unique ID Attributes (Attribute Type = 0)

and be followed by an attribute name from the list of Attributes.
This will determine the type of value extracted from the form element,
and which attribute it is tied to (i.e. read from and saved to).
It is important that the type above matches the type of the attribute in
the Attributes section.  Note that the will always be a colon (:) in the
bind string separating the type from the name.
The attribute name in the bind property must be in the list of attributes.

##### `items`
This property is optional.  If provided it must be a list of one or more strings.  There is no default.
This property provides a list of choices for pick list type elements.
It is required for `QRadioElement` and `QSegmentedElement`, and ignored for all other types.

##### `selected`
This property is optional.  If provided it must be an integer.  There is no default.
It is the zero based index of the initially selected item from the list of items.
If not provided, nothing is selected initially.

##### `boolValue`
This property is optional.  If provided it must be an integer value of 0 or 1.  The default is 0 (false).
This property is the initial value for the `QBooleanElement`. It is ignored by all other types.

##### `minimumValue`
This property is optional.  If provided it must be number.  The default is 0.
This is the minimum value allowed in `QIntegerElement`.

##### `maximumValue`
This property is optional.  If provided it must be number.  The default is 100.
This is the maximum value allowed in `QIntegerElement`.

##### `numberValue`
This property is optional.  If provided it must be number.   There is no default.
This is the initial value for `QIntegerElement` or `QDecimalElement`.
There is no default; that is the initial value is null. Protocol authors are discouraged
from using an initial value, as it causes confusion regarding whether there was an
observation of the default value, or there was no observation.  Leaving as null removes
the ambiguity.  If a default value is desired when there was no observation this can be
done in post processing without losing the fact that no observation was actually made.

##### `placeholder`
This property is optional.  If provided it must be a text string.  There is no default.
This is the background text to put in a text box to suggest to the user what to enter.

##### fractionDigits
This property is optional.  If provided it must be an integer.   There is no default.
This is a limit on the number of digits to be shown after the decimal point. Only
used by `QDecimalElement`.

##### `keyboardType`
This property is optional.  If provided it must be one of the text strings below (**It must match in capitalization**).  The default is `"Default"`.
This determines what kind of keyboard will appear when text editing is required.

 * `Default`
 * `ASCIICapable`
 * `NumbersAndPunctuation`
 * `URL`
 * `NumberPad`
 * `PhonePad`
 * `NamePhonePad`
 * `EmailAddress`
 * `DecimalPad`
 * `Twitter`
 * `Alphabet`

##### `autocorrectionType`
This property is optional.  If provided it must be one of the text strings below (**It must match in capitalization**).  The default is `"Default"`.
This determines if a text box will auto correct (fix spelling) the user's typing.
`Default` allows iOS to decide when to apply autocorrection.  If you have a preference, choose
one of the other options.

 * `Default`
 * `No`
 * `Yes`

##### `autocapitalizationType`
This property is optional.  If provided it must be one of the text strings below (**It must match in capitalization**).  The default is `"None"`.
This determines if and how a text box will auto capitalize the user's typing.

 * `None`
 * `Words`
 * `Sentences`
 * `AllCharacters`

##### `key`
This property is optional.  If provided it must be a string. There is no default.
A unique identifier for this element in the form. It is an alternative to bind for
referencing the data in the form. `bind`, but not `key` is used in Park Observer.
This was not well understood initially and most protocols have a key property
defined even though it is not used.

This property is ignored in all versions of Park Observer.

## `edit_at_start_recording`
This property is optional.  If provided it must be a boolean. The default is true.
If true, the mission attributes editor will be displayed when the start recording button is pushed.

This property is ignored in versions of Park Observer before 1.2.0.

## `edit_at_start_first_observing`
This property is optional.  If provided it must be a boolean. The default is false.
If true, then editor will be displayed when start observing button is pushed after start recording.

This property is ignored in versions of Park Observer before 1.2.0.

## `edit_at_start_reobserving`
This property is optional.  If provided it must be a boolean. The default is true.
If true, then editor will be displayed when start observing button is pushed after stop observing.

This property is ignored in versions of Park Observer before 1.2.0.

## `edit_prior_at_stop_observing`
This property is optional.  If provided it must be a boolean. The default is false.
If true, then editor will be displayed for the prior track log segment when done observing
(stop observing or stop recording button press).
See the note for `edit_at_stop_observing` for an additional constraint.

This property is ignored in versions of Park Observer before 1.2.0.

## `edit_at_stop_observing`
This property is optional.  If provided it must be a boolean. The default is false.
An optional boolean (true/false) value that defaults to false.
If true, then editor will be displayed when when done observing (stop observing or stop recording button press)

**Note:** Only one of `edit_prior_at_stop_observing` and `edit_at_stop_observing` should be set to true.
If both are set to true, `edit_prior_at_stop_observing` is ignored.
(In this case, you can edit the prior mission property by taping the marker on the map)

This property is ignored in versions of Park Observer before 1.2.0.

## `symbology`
A required object as defined in the [symbology](#symbology) section at the end of this document.
This object defines how a mission properties point is drawn on the map.  This point occurs
when starting recording, starting/stoping recording, and when editing the mission attributes.

## `on-symbology`
An optional object as defined in the [symbology](#symbology) section at the end of this document.
This object defines the look of the track log line when observing (i.e. on-transect).
The default in version 1 was a 1 point wide solid black line.
The default in version 2 was a 3 point wide solid red line.

## `off-symbology`
An optional object as defined in the [symbology](#symbology) section at the end of this document.
This object defines the look of the track log line when not observing (i.e. off-transect).
The default in version 1 was a 1 point wide solid black line.
The default in version 2 was a 1.5 point wide solid gray line.

## `gps-symbology`
An optional object as defined in the [symbology](#symbology) section at the end of this document.
This object defines the look of the GPS points along the track log.
The default is a 6 point blue circle.

This property is ignored in versions of Park Observer before 0.9.8.  In that case,
all GPS points are rendered as a blue 6 point circle.

## `totalizer`
This property is optional. If provided it must be an object as defined below. There is no default.
The totalizer object is used to define the parameters displaying a totalizer which shows 
information on how long the user has been track logging (recording) and/or observing (on-transect).
If the property is not provided, no totalizer will be shown on the map.
The totalizer shows the total time/distance recording/observing for the current set of values 
in `fields`.  When one or more of the fields changes, a different set of totals will be displayed.
The fields must be in the mission attributes. `fields` is typically set to the transect id and the
totalizer show the total time or distance recording/observing on the current transect.
No totalizer was shown unless `fields` had a valid value, and one of the _include*_ properties is true.

This property is ignored in versions of Park Observer before 0.9.8b.

The `totalizer` has the following properties

* `fields` (o)
* `fontsize` (o)
* `includeon` (o)
* `includeoff` (o)
* `includetotal` (o)
* `units` (o)

### `fields`
This property is optional. If provided it must be a list of one or more strings. There is no default.
The list contains attribute names. When any of the attribute in this list change, a different total is displayed.
The attributes in the list must be in referenced in the
mission dialog (so that it can be changed -- monitoring a unchanging field is pointless).
No totalizer will be shown unless this property contains at least one valid value.

### `fontsize`
This property is optional. If provided it must be a number. The default is 14.0.
This property indicates the size (in points) of the totalizer text.

### `includeon`
This property is optional. If provided it must be a boolean. The default is true.
This property indicates if the total while "observing" should be displayed.

### `includeoff`
This property is optional. If provided it must be a boolean. The default is false.
This property indicates if the total while "recording" but not "observing"
should be displayed.

### `includetotal`
This property is optional. If provided it must be a boolean. The default is false.
This property indicates if the total regardless of "observing" status should be displayed.

### `units`
This property is optional. If provided it must be a string. The default is "kilometers".
The property indicates the kind of total to display.
It must be one of "kilometers", "miles" or "minutes".



# `features`

This property is required and must be a list of one or more feature objects.
A feature is a kind of thing that will be observed during your survey.
Often it is an animal species.
It is defined by a list of attributes that you will collect every time you observe the feature.
You can have multiple features in your protocol, however many surveys only observe one feature.
The number of features in a protocol file should be kept as small as possible to keep the survey
focused and easier to manage.

Each feature is an object with the following properties

* `name`
* `attributes` (o)
* `dialog` (o)
* `allow_off_transect_observations` (o)
* `locations`
* `symbology`

## `name`
This property is required and must be a non-empty text string.
Each feature name must be unique name. The name is used in the interface to let the
user choose among different feature types. All the observation in one feature will
be exported in a CSV file with this name, and a geo-database table with this name.
It should be short and descriptive.

## `attributes`
An optional list of attributes to collect for this feature.
A Feature with no attributes only collects a location and the name of the feature.

See the [`mission.attributes`](#-attributes-) section for details.

## `dialog`
An optional property that describes the format of the editing form for this feature's attributes.

See the [`mission.dialog`](#-dialog-) section for details.

## `allow_off_transect_observations`
This property is optional. If provided it must be a boolean. The default is false.
If true, then this feature can be observed while off transect (not observing)

This property is ignored in versions of Park Observer before 1.2.0.

## `locations`
This property is required and must be an array of one or more location objects.
A location is an object that describes the permitted techniques for specifying the location of an observation. A location is defined by the following properties:

* `type`
* `allow` (o)
* `default` (o)
* `deadAhead` (o)
* `baseline` (deprecated)
* `direction` (o)
* `units` (o)

### `type`
This property is required and must be one of the following strings:

 * `gps` - locates the observation at the devices GPS location
 * `mapTarget` - locates the observation where the target is on the map
 * `mapTouch` - locates the observation where the user touches the map
 * `angleDistance` - locates the observation at an angle and distance from the GPS location and course.

`adhocTarget` is a deprecated synonym for `mapTarget`, and
`adhocTouch` is a deprecated synonym for `mapTouch`.  These types should not be
used in new protocol files, but may still exist in older files.

**Important:** Providing multiple locations with the same type is not prohibited,
 but it is discouraged as the behavior is undefined.

See the [Protocol Guide](Protocol_Guide_V1.html) for details on how the user interface behaves with
different location types.

### `allow`
This property is optional. If provided it must be a boolean. The default is true.
If the value is false, this type of location method is not allowed.
This is equivalent to not providing the location method in the list.

### `default`
This property is optional. If provided it must be a boolean. The default is false.
This is used to determine which "allowed" non-touch location method should be used
by default (until the user specifies their preference).
Only one non-touch locations should have a true value, otherwise the behavior is undefined.

### `deadAhead`
This property is optional. If provided it must be a number between 0.0 and 360.0. The default is 0.0.
The numeric value provided is the angle measurement in degrees that means the feature is dead ahead
(i.e. on course or trajectory of the device per the GPS)

### `baseline` (deprecated)
This property is a deprecated synonym for `deadAhead`.
Its use is discouraged, but it may be found in older protocol files.

### `direction`
This property is optional. If provided it must be one of `cw` or `ccw`. The default is `cw`.
With `cw`, angles for the `angleDistance` location type will increase in the clockwise direction,
otherwise they increase in the counter-clockwise direction.

### `units`
This property is optional. If provided it must be one of "feet" or "meters" or "yards". The default is "meters".
With "meters", distances for the `angleDistance` location type will be assumed to be in meters.
Otherwise they will be in feet or yards.

## `symbology`
A required object as defined in the [symbology](#symbology) section at the end of this document.
This object defines how an observation of this feature is drawn on the map.

## `label`
This property is optional. If provided it must be an object.  There is no default.
The label object defines how the feature will be labeled on the map.

This `label` object has the following properties:

* `field`
* `color` (o)
* `size` (o)
* `symbol` (o)

### `field`
This property is required and must be a non-empty text string.
The string must match one of the attribute names for this feature.
If the `field` is not provided, or can't be found in the feature attributes, no label is shown.

### `color`
This property is optional. If provided it must be an string.  The default is "#FFFFFF" (white)
The color property is discussed in more detail in the [symbology](#symbology) section at the end of this document.

### `size`
This property is optional. If provided it must be an number.  The default is 14.0
It specifies the size in points of the label text.
The size property is discussed in more detail in the [symbology](#symbology) section at the end of this document.

### `symbol`
This property is optional. If provided it must be an object.  There is no default
The symbol is a JSON object as described in the Text Symbol section of the ArcGIS ReST API (http://resources.arcgis.com/en/help/arcgis-rest-api/#/Symbol_Objects/02r3000000n5000000/)
If the JSON object is malformed or unrecognized, then it is ignored in deference to the color and size properties.
If the symbol is valid, then the `size` and `color` properties  of `label` are ignored.



# `csv`

This property is optional. If provided it must be an object.  There is no default

This object describes the format of the CSV exported survey data.
Currently the format of the CSV files output by Park Observer is hard coded.
This part of the protocol file is ignored by Park Observer, and only used
by tools that convert the CSV data to an ESRI file geo-databases.

If provided it must be a object identical to [`csv.json`](csv.json).  If provided, it will be used by post processing tools like the POZ to FGDB translator to understand how the CSV export files are formatted. If it is not provided, the upload server, and the POZ to FGDB translator will use [`csv.json`](csv.json).

A future version of Park Observer may use this property to allow users to configure the format of the exported CSV files.

The CSV object has the following properties.  All are required.

* `features`
* `gps_points`
* `track_logs`

## `features`
An object that describes how to build the observer and feature point feature classes from the CSV
file containing the observed features. The features object has the following properties.
All are required.

 * `feature_field_map`
 * `feature_field_names`
 * `feature_field_types`
 * `feature_key_indexes`
 * `header`
 * `obs_field_map`
 * `obs_field_names`
 * `obs_field_types`
 * `obs_key_indexes`
 * `obs_name`

### `feature_field_map`
A list of integer column indices from the CSV header, starting with zero, for the columns containing the data for the observed feature tables.

### `feature_field_names`
A list of the string field names from the CSV header that will create the observed feature tables.

### `feature_field_types`
A list of the string field types for each column listed in the 'feature_field_names' property.

### `feature_key_indexes`
A list of 3 integer column indices, starting with zero, for the columns containing the time, x and y coordinates of the feature.

### `header`
The header of the CSV file; a list of the column names in order.

### `obs_field_map`
A list of integer column indices from the CSV header, starting with zero, for the columns containing the data for the observer table.

### `obs_field_names`
A list of the field names from the CSV header that will create the observed feature table.

### `obs_field_types`
A list of the field types for each column listed in the `obs_field_names` property.

### `obs_key_indexes`
A list of 3 integer column indices, starting with zero, for the columns containing the time, x and y coordinates of the observer.

### `obs_name`
The name of the table in the ESRI geo-database that will contain the data for the observer of the features.

## `gps_points`
An object that describes how to build the GPS point feature class from the CSV file containing the GPS points. The `gps_points` object has the following properties.
All are required.

 * `field_names`
 * `field_types`
 * `key_indexes`
 * `name`

### `field_names`
A list of the field names in the header of the CSV file in order.

### `field_types`
A list of the field types in the columns of the CSV file in order.

### `key_indexes`
A list of 3 integer column indices, starting with zero, for the columns containing the time, x and y coordinates of the point.

### `name`
The name of the CSV file, and the table in the ESIR geo-database.

## `track_logs`
An object that describes how to build the GPS point feature class from the CSV file containing the track logs and mission properties. The track_logs object has the following properties.
All are required.

 * `end_key_indexes`
 * `field_names`
 * `field_types`
 * `name`
 * `start_key_indexes`

### `end_key_indexes`
A list of 3 integer column indices, starting with zero, for the columns containing the time, x and y coordinates of the first point in the track log.

### `field_names`
A list of the field names in the header of the CSV file in order.

### `field_types`
A list of the field types in the columns of the CSV file in order.

### `name`
The name of the CSV file, and the table in the ESRI geo-database.

### `start_key_indexes`
A list of 3 integer column indices, starting with zero, for the columns containing the time, x and y coordinates of the last point in the track log.



# Symbology
The symbology that Park Observer understands changed at 0.9.8.  Before that, only version 1
symbology was understood.  After that it depended on which `meta-version` the document
specified.

## `"meta-version": 1`
In version 1, the symbology object had only two optional properties.  If the symbology
property was missing in versions of Park Observer before 2.0, then there would be no
symbology for that item and it would not be drawn on the map.  However if an empty object
was provided, then Park Observer would use the default values specified in the individual
symbology properties.  The default values would also be provided if any of the following
properties were missing or invalid.  The version 1 symbology object has the following
properties

* `color`
* `size`

### `color`
This property is optional. If provided it must be a text string. There is no default.
The color element is a string in the form "#FFFFFF"
where F is a hexadecimal digit (0-9,A-F).
The Hex pairs represent the Red, Green, and Blue respectively.
If the string is missing, or malformed, then the ESRI mapping framework was free to choose
a default value.  Typically this was black.

### `size`
This property is optional. If provided it must be a number. There is no default.
The size is a number for the diameter in points of the simple circle marker symbol,
or the width of a simple solid line.
If the number is missing, or invalid, then the ESRI mapping framework was free to choose
a default value at one point this was 6 points for diameter, and 1 point for width.

## `"meta-version": 2`
With version 2, the symbology object was specified by the JSON format for ESRI Renderers
as defined in the [renderer object in the ArcGIS ReST API](https://developers.arcgis.com/documentation/common-data-types/renderer-objects.htm).
This is the format that ESRI uses when building web maps for AGOL.
Depending on which version of the ESRI mapping SDK that Park Observer is using,
some of the properties may be optional (the `type` property is always required).
However the default value provided may vary with different versions. To be
safest, do not rely on default values, and always test your symbology before
distributing your protocol file.

When using version2 symbology, it is on you to verify you are using the right type
of symbol (marker symbols like `esriSMS` for points and `esriSLM` for lines).

If the symbol object was invalid, a 12 point green circle was provided for points.
The default line symbol by property in the mission property.

If you wish to not draw the track logs or GPS points, then you need to provide valid symbology
with either 0 size, or a fully transparent color.
