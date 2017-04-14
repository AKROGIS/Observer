Protocol Specifications, version 2

The protocol file (*.obsprot) is just a text file in JSON (javascript object notation).  The root of the file is a Javascript Object (dictionary) with the following properties (keys)

	*	meta-name
	*	meta-version
	*	name
	*	version
	*	date
	*	description
	*	observing
	*	notobserving
	*	mission
	*	features
	*	csv

Each of these properties is define in the following sections. Complete details on JSON file format the can be found at http://www.json.org/

	*	meta-name
		-	Must be "NPS-Protocol-Specification".  This designates the file as subscribing to this file format.
	*	meta-version
		-	Must be a integer that defines the version of the specification.  This is version 2.
	*	name
		-	A user defined name (string) for this protocol.  Names do not need to be unique, but try to use a unique name to avoid confusion.
		-	Protocols can evolve (see version and date).  The same name can and should be used for different version of the same protocol.
	*	version
		-	The version of this named protocol.  The version number looks like a floating point number but is actually two integers separated by a decimal point.
		-	The first number is the major version number the second number is the minor version number
		-	A change in the major version number represents a change in the database structure of the protocol.
		-	Two protocol files with the same name that differ in the major version number cannot share the same feature class without some data manipulation.
		-	A change in the minor version number can change symbology, location methods, and default or picklist values.
		-	It is assumed that two protocol files with the same name that differ only in the minor version number can and will share the same feature class on the server.
	*	date
		-	The publication date of the protocol file.  The date is a string in iso format, i.e. YYYY-MM-DD
	*	description
		-	A user defined description (string) for this protocol
	*	observing
		-	User defined message to display on screen when observing. The default is nothing.
	*	notobserving
		-	User defined message to display on screen when track logging but not observing.  The default is nothing.
	*	cancel_on_top
		-	Optional boolean property.  `true` will put the `cancel`/`delete` button on the top of the observation attributes form.  The default is false - the button will be on the bottom.
	* gps_interval
	  - Optional numeric property.  Specifies the number of seconds to wait between successive GPS points saved for the tracklog.
		This is helpful when the GPS delivers locations at a very high rate, or if a detailed tracklog is not useful.
		The default is 0 (zero) - all locations provided by the GPS are put in the tracklog.
		Regardless of this setting, a user action creates a GPS point at the most recent location available from the device.
	*	mission
		-	An objects with the similar properties to the features described below.  For now, refer to that section for details
		-	The mission describes the attributes and symbology of the mission.
		-	The mission does not have a locations property (defined for features)
		-	The mission has two additional properties on-symbology and off-symbology that are the same as the symbology property defined for features
		-	These symbology properties define the look of the track log when observing (on or on-transect), and not observing (off).
		-	The mission attributes are often things like the names of the observers, and the weather.
		-	totalizer - An object used to define the parameters for collecting and displaying a Mission Totalizer.   This is used to provide information on how long the user has been observing for a given set of conditions, usually this is just the transect id.  In this case, the totalizer show how long the user has been observing on a current transect.
		-	fields - A required array of field names
		-	when any of the fields change, a different total is displayed.
		-	There must be at least on field (string) in the array which matches the name of one of the attributes in the mission
		-	units - An optional element with a value of "kilometers" or "miles" or "minutes". Default is "kilometers"
		-	includeon - A boolean value (true/false), that indicate is the total while "observing" is true should be displayed.  The default is  true
		-	includeoff - A boolean value (true/false), that indicate if the total while "observing" is false should be displayed.  The default is  false
		-	includetotal - A boolean value (true/false), that indicate if the total regardless of "observing" status should be displayed.  The default is  false
	*	features
		-	An Array of objects with the following properties
		-	name
		-	Each feature must have a unique name.
		-	The name can be any sequence of characters, and must be enclosed in quotes
		-	The name is used in the interface to let the user choose among different feature types
		-	It should be short and descriptive.
		-	attributes
		-	A feature type can have an optional list of attributes to be collected for each feature
		-	A feature with no attributes, only collects a location (and the type of the feature)
		-	Each attribute must have a "name" element
		-	The name element must be unique
		-	It will be used as a database column name, so it should be a simple ASCII name without spaces or special characters
		-	It will be prefixed internally to avoid clashes with reserved words
		-	Each attribute must have a "type" element
		-	The type is an integer code with the following definitions (from NSAttributeType)
		-	100 -> 16bit integer
		-	200 -> 32bit integer
		-	300 -> 64bit integer
		-	400 -> NSDecimal (currently not supported by ESRI)
		-	500 -> double precision floating point number
		-	600 -> single precision floating point number
		-	700 -> string
		-	800 -> boolean (converts to an ESRI integer 0 = NO, 1 = YES)
		-	900 -> datetime
		-	1000 -> binary blob (? no UI support, check on ESRI support)
		-	locations
		-	Each feature must have a "locations" element with a non-empty list of location methods (a technique for locating a feature).
		-	Each location method must have a "type" element
		-	The value must be one of "gps", "mapTarget", "mapTouch", "angleDistance"
		-	Any location type containing the text "Touch" is a touch location, the others are non-touch locations.
		-	Providing multiple methods with the same type is allowed but discouraged as the behavior is undefined.
		-	A location method can have an optional  "allow" element with a value of either true or false.
		-	The value of true is assumed if this element is absent.
		-	If the value is false, this type of location method is not allowed.  This is equivalent to not providing the location method in the list.
		-	A location method can have an optional default element with a value of either true or false.
		-	A value of false is assumed if this element is absent
		-	Only one non-touch locations should have a true value, otherwise the behavior is undefined.
		-	A location method of "type":"angleDistance" has the following requirements
		-	An optional element "deadAhead" with a numeric value between 0.0 and 360.0
		-	The numeric value provided is the angle measurement in degrees that means the feature is dead ahead
		-	The default is 0.0
		-	An optional element "direction" with a value of "cw" or "ccw"
		-	Angles increase in the clockwise ("cw") or counter-clockwise ("ccw") direction
		-	The default is "cw"
		-	An optional element "units" with value of "feet" or "meters" or "yards"
		-	Distance measurements to the feature are reported in these units
		-	The default is "meters"
		-	If a touch location method is allowed
		-	A feature will be created when the user touches the map without selecting an existing feature
		-	If one or more non-touch location methods allowed
		-	Then an Add Feature button is added to the user interface
		-	The Add Feature button has the following behavior if more than one non-touch location method is allowed
		-	Tap:
		-	If there is a location method with "default":true
		-	Use that location method to add a new feature
		-	If there is no location method with "default":true
		-	If the feature's preferred location method (see Long Press) is not set
		-	Set the feature's preferred method to the first of the following types to be allowed
		-	"gps", "adhocTarget", "angleDistance"
		-	Use the user's preferred location method to add a new feature
		-	Long Press:
		-	Provide the user with a selection list of all the allowed non-touch location methods
		-	If the user selects one
		-	A feature is added using the selected location method
		-	Set the feature's preferred location method to the selected location method
		-	dialog
		-	Provides the look and feel of the attribute input form presented to the user
		-	Only  required if the feature has attributes
		-	See the QuickDialog documentation for details
		-	symbology
		-	Defines how the feature will be displayed on the map
		-	The symbology may have an optional "color" element
		-	The color element is a string in the form "#FFFFFF"
		-	where F is a hexadecimal digit
		-	The Hex pairs represent the Red, Green, and Blue respectively.
		-	The default if not provided, or malformed is "#000000" (black)
		-	The symbology may have an optional "size" element
		-	The size is an integer number for the size in points of the simple circle marker symbol
		-	The default is 12 if not provided.
    -	`label`
			-	an optional object that defines how the feature will be labeled on the map
			- The label should have a `field` element
			 	- where `field` is a string which references one of the attributes for this feature
				- If the `field` is not provided, or can't be found in the feature attributes, no label is shown
			-	The label may have an optional `color` element
				-	The color element is a string in the form `#FFFFFF`
				-	where F is a hexadecimal digit
				-	The Hex pairs represent the Red, Green, and Blue respectively.
				-	The default if not provided, or malformed is "#FFFFFF" (white)
			-	The label may have an optional `size` element
				-	The `size` is an integer number for the size in points of the label
				-	The default is 14 if not provided.
			- The `label` may have an optional `symbol` element
				- `symbol` is a JSON object as described in the Text Symbol section of the ArcGIS ReST API (http://resources.arcgis.com/en/help/arcgis-rest-api/#/Symbol_Objects/02r3000000n5000000/)
				- if the JSON object is malformed or unrecognized, then it is ignored
				- if the symbol is valid, then `size` and `color` elements of `label` are ignored in deference to the values in `symbol`.  

Notes on Version 2

Added gps-symbology under mission

The value of the symbology tags are full ESRI Renderer JSON as defined in http://resources.arcgis.com/en/help/rest/apiref/renderer.html

Not all fields in the ESRI rest API need to be provided, when defaults are obvious ; i.e. "label":"" and "angle":0 (I have not tested everything)
the type is required and must be one of simple, uniqueValue, classBreak
TODO test which other fields are required, and document the defaults
