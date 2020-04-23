Protocol Files for Park Observer
================================

A protocol file is required to use the Park Observer.  It provides the standard for a data collection effort,
and defines the schema for the GIS database on the server.
You can create your own protocol file if you follow the specification, however this is the file format is very picky,
and it is easier (and recommended) to get help from the AKR GIS Team.

This document discusses some of the considerations in making a protocol file suitable for your survey needs.
It is not the definitive guide to exactly what is allowed in the content and
format of a protocol file.  For that, see the [Protocol Specifications](ProtocolSpecificationV2.html).

Basic Definition
----------------
A protocol file is defined by a name and a version.  The name and version are used to sync to the GIS database on the server,
so the name should reflect the scope of the protocol, and the version is used to distinguish changes over time.

A protocol has a description, which should include some information helpful for someone browsing protocols to select the
appropriate protocol for their survey.  Contact information for the primary user of the protocol is usually included in the description.

The protocol defines the list of attributes tracked during a mission (called mission properties)

The protocol defines the list of features (and their attributes) that are observered during a survey.
Most survey are limited to a single feature (animal).

Name and Version
----------------

A Protocol should have a unique name and version.  To avoid confusion, the file name should match the name attribute
inside the file, but this is not required.
Protocols have a major and minor version number.  Both are integers separated by a decimal point.
A change in the major version number indicates a change in the database schema.  Use the minor version number for all other changes.

When a survey is upload to the server, or the POZ2FGDB toolbox is used, the protocol used to create the survey
determines then name of the database that is created (or appended).
The name of the database is determined by the protocol name and the major version number.  If the database exists
then the survey is added to the tables in the database. Therefore it is important to increase the major version
number of your protocol if you add, remove, rename, or change the type of any of your attributes (i.e. change the
database schema). The world may end if you try to sync two different surveys with different schemas, but the same
protocol name and major version number.
Please don't do that.

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

  * Default/Initial Value – If a default value is specified, then the form will be pre-populated with that item selected from the picklist.
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
GPS is the default unless you touch the map.
If you want angle/distance, you can specify the distance units, and angle convention.

features located with Map touch or map target can both be moved by dragging the marker
on the map, or by snapping it to the current GPS location.
features located by GPS or Angle/Distance cannot be moved.

If a touch location method is allowed, a feature will be created where the user touches the map.
If multiple features allow touch location, then a picklist will be displayed to select the feature to create.

If a feature allows one or more non-touch location methods, then a button with the name of the feature is added to the user interface. If there is only one allowed non-touch location method, then tapping the button adds the feature with that location method. If more than one non-touch location method is allowed, then button has the following behavior:

  * Tap:
    - If there is a default non-touch location method, then:
      + use that location method to add a new feature.
    - If there is no default non-touch location method, then:
      + If the feature's preferred location method (see Long Press) is not set, then:
        * set the feature's preferred method to the first of [GPS, Target, Angle/Distance] to be allowed.
      + Use the feature's preferred location method to add the new feature.
  * Long Press:
    - Provide the user with a selection list of all the allowed non-touch location methods.
    - If the user selects one, then:
      + A feature is added using the selected location method.
      + Set the feature's preferred location method to the selected location method.


Symbology
---------

The protocol file specifies symbology:

 * Tracklogs - different colors and/or lineweight while observing and not observing

 * features - color and size (they are always circles)

 * points where mission properties are set - color and size (they are always circles)
