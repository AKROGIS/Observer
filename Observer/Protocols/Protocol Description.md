Protocol Files for Park Observer
================================

A protocol file is required to use the Park Observer.  It provides the standard for a data collection effort,
and defines the schema for the GIS database on the server.
You can create your own protocol file if you follow the specification, however this is the file format is very picky,
and it is easier (and recommended) to get help from the AKR GIS Team.

Basic Definition
----------------
A protocol file is defined by a name and a version.  The name and version are used to sync to the GIS database on the server,
so the name should reflect the scope of the protocol, and the version is used to distinguish changes over time.
More on this to come.

A protocol has a description, which should include some information helpful for someone browsing protocols to select the
appropriate protocol for thier survey.  Contact information for the primary user of the protocol is usually included in the description.

The protocol defines the list of attributes tracked during a mission (called mission properties)

The protocol defines the list of features (and thier attributes) that are observerd during a survey.
Most survey are limited to a single feature (animal).


Mission Properties
------------------


Features
--------


Attributes
----------
Attributes can be text, numbers, or boolean (true/false).
Date/time and locations are captured automatically for all observations.
Forms can use:
  * step controls (+/-) (useful for small integers)
  * switches (used for yes/no values)
  * single line text
  * multiline text
  * number entry (with zero or more digits after the decimal)
  * picklists (see discussion below)


PickLists
---------
  * Text vs. Integer – The underlying database type for a picklist can either be text (i.e. the text displayed in the picklist display),
  or an integer (0 for the first item in the list, 1 for the second item, etc).  The choice of integer vs. text is an important early distinction,
  as this can’t be changed later without creating a new database.  Integers are more convenient/efficient for searching, sorting, and validating;
  however text is more obvious to humans.  If the database is exported to a CSV file, integers are not expanded to the text value.
  This makes the CSV files smaller, but harder to understand.  If Integers are used, then a domain (picklist) is automatically created in the
  protocol’s FGDB to match the picklist values.  Currently, picklists are not created in the FGDB if the data is stored as text (I hope to
  remove this restriction the future).

  * Default/Initial Value – If a default value is specified, then the form will be prepopulated with that item selected from the picklist.
  The appropriate value will be recorded in the database without additional action from the user.  If no default value is specified, then
  that item in the form will be blank.  The database will record a null (empty) value if the data type is text, or -1 if the data type is integer.
  Once a value is selected, it is not possible to clear the selection, and you must pick one of the items in the picklist.

  * Ordering – The Items in the picklist will be ordered (top to bottom) in the order that you provided them


Locations
---------

What types of locations do you want to allow/require? Your choices are:

 * At the GPS location

 * At the map touch

 * At the target on the map

 * At an angle/distance from the current GPS location/course

By default, the first three are allowed, and none is required.
At the GPS is the default unless you touch the map.
If you want angle/distance, you need to specify the distance units, and angle convention.
If Map Touch and at GPS Location are both allowed, you can locate an item with a map touch,
and then correct it by dragging it, or snapping it to the current GPS location.


Symbology
---------

The protocol file specifies symbology:

 * Tracklogs - different colors and/or lineweight while observing and not observing
 
 * features - color and size (they are always circles)
 
 * points where mission properties are set - color and size (they are always circles)