Server.py should run on a server accessible to the iPads running Park Observer
The server should be behind the firewall, as it will expose raw Park Service data

Server.py has a variable called root_foder which is where it data it manages resides
the user that starts Server.py needs to have read permissions on this folder.  If it
does not create, the Server.py will create it.

Dependencies
------------
Server.py was written for Python 2.7, and relies on the following modules

  * arcpy  (ArcGIS version 10.1 or better)
  * zipfile - for decompressing the uploaded data
  * tempfile - for creating temp files and directories in root_folder
  * shutil - for deleting temp directory in bulk
  * os - for path and file system tools
  * glob - for finding all files matching a pattern
  * dateutil.parser - for parsing ISO dates into python datetime (only needed for date fields
  * json - for parsing the javascript object notation in the protocol files
  * DatabaseCreator.py - builds a FGDB database per a protocol specification
  * CsvLoader.py - reads CSV files built per the protocol, and loads them into a database,
    it will call DatabaseCreator.py if necessary to build the database.
  
Server.py listens on port 8080 for an HTTP Post command to the URI /sync
The data must be a zip file with
  * a protocol file in JSON format complying with the Protocol Specification for Park Observer
  * 1 or more csv files as described in the protocol
  * all the files must be in the root level of the zip file (they cannot be in a folder)

Server.py will read the protocol file in the zip and look for a file geodatabase with the
name and version of the protocol.  If a FGDB with the correct name does not exist, it is
created.  And CSV files that were included in the zip file are assumed to be formated per
the provided protocol, and are loaded into the database per the protocol's CSV
specifications.

When Server.py run it will listen on port 8080 until it crashes, is killed, or the computer
is restarted.  A scheduled task should be created to relaunch the Server.py shold it be found
to not be running.  Server.py will log any error it gets in an error.log file, the contents
can be retrieved by sending a GET comment to URI /error on port 8080 (i.e. http://akrgis.nps.gov:8080/error)
Server.py also recognizes '/help', '/dir', and '/load' to get information on the server

Installation
------------
You will need to put Server.py in an appropriate location with (CsvLoader.py and DatabaseCreator.py)
You will also need to ensure that port 8080 is open for TCP from any computer on the
domain (see the Firewall setting in the Administrative part of the Control Panel)

Testing
-------

You can goto http://akrgis.nps.gov:8080/load, and use the simple form to select a properly
formated zip file.  If the zip file can be uploaded, the server will respond with 'processing'
to find out if the zip file was processed without errors, check http://akrgis.nps.gov:8080/error
to see if there are any new errors, and http://akrgis.nps.gov:8080/dir to see if a new database was created

Data Access
-----------
You should make the root_folder readable and shared to all domain users, so they can either copy
the FGDB, or access the data via a layer file.  I hope to automate the creation of a layer file
and MXD, so that a service can automatically be created.  This could be done once when the database
is created.  Links to the service and layer file could be provided on the Park Observer website
so that users could easily check that their data is on the server and add it to thier maps.