SyncServer
==========

`Server.py` should run on a server accessible to the iPads running Park Observer
The server should be behind the firewall, as it will expose raw Park Service data

`Server.py` has a variable called root_foder which is where the data it manages resides
the user that starts `Server.py` needs to have write permissions on this folder.  If it
does not exist, the `Server.py` task will create it.  The user that runs `Server.py`
also needs to have read/execute access to the python executable, and `Server.py`'s folder.

Dependencies
------------
`Server.py` was written for Python 2.7, and relies on the following modules

  * `arcpy`  (ArcGIS version 10.1 or better)
  * `zipfile` - for decompressing the uploaded data
  * `tempfile` - for creating temp files and directories in root_folder
  * `shutil` - for deleting temp directory in bulk
  * `os` - for path and file system tools
  * `glob` - for finding all files matching a pattern
  * `dateutil.parser` - for parsing ISO dates into python datetime (only needed for date fields)
  * `json` - for parsing the javascript object notation in the protocol files
  * `DatabaseCreator.py` - builds a FGDB database per a protocol specification
  * `CsvLoader.py` - reads CSV files built per the protocol, and loads them into a database,
    it will call `DatabaseCreator.py` if necessary to build the database.

`Server.py` listens on port 8080 for an HTTP Post command to the URI `/sync`
The data must be a zip file with
  * a protocol file in JSON format complying with the Protocol Specification for Park Observer
  * 1 or more csv files as described in the protocol
  * all the files must be in the root level of the zip file (they cannot be in a folder)

`Server.py` will read the protocol file in the zip and look for a file geodatabase with the
name and version of the protocol.  If a FGDB with the correct name does not exist, it is
created.  The CSV files that were included in the zip file are assumed to be formated per
the provided protocol, and are loaded into the database per the protocol's CSV
specifications.  If this is really old protocol file it might not have a CSV
specification, in which case the sibling file `csv.json` is used

When `Server.py` runs it will listen on port 8080 until it crashes, is killed, or the computer
is restarted.  A scheduled task should be created to relaunch `Server.py` shold it be found
to not be running.  `Server.py` will log any error it gets in an `error.log` file, the contents
can be retrieved by sending a GET comment to URI `/error` on port 8080 (i.e. http://akrgis.nps.gov:8080/error)
`Server.py` also recognizes `/help`, `/dir`, and `/load` to get information on the server

Installation
------------
You will need to put `Server.py` in an appropriate location with (`CsvLoader.py`,
`DatabaseCreator.py` and `csv.json`). You will also need to ensure that port 8080
is open for TCP from any computer on the domain (see the Firewall setting in the
  Administrative part of the Control Panel)

You will need to create a scheduled task.  I set it up to

 * Run whether the user is logged in or not.
 * do not store password (runs with lower permissions)
 * Trigger: At system Startup
 * Trigger: When the task is created or modified
 * Action: command `C:\python27\ArcGISx6410.2\python.exe`
 * Action: arguments `E:\inetApps\observer\syncserver\Server.py`
 * Action: Start in `E:\inetApps\observer\syncserver`
 * Conditions: If the task fails, restart every minute for 3 tries
 * Conditions: DO NOT stop the task if it has been running for a long time (this taks should run forever)
 * Conditions: If the task is already running, do not start a new instance.

 There is a scheduled task export file that can be used to recreate the scheduled task.  These files are at `T:\GIS\PROJECTS\AKR\ArcGIS Server\https certificates\{server name}`

I created a special local account on the server called `observer` to run the task.  The password for this account is in the team KeyPass file on the T drive.
This account is made the owner of `E:\MapData\Observer`, where databases will be created and updated.
This account must be added to the backup operators group to be able to run a batch job.
You might also be able to configure the account with permissions to logon as a batch job.
This is done with Start Menu -> Control Panel -> Administrative Tools -> Local Security Policy.
In the Table of contents on the left, select Security Settings -> Local Policies -> User Rights Assignment.
In the main panel, scroll down to Log on as a batch job.
Double click on Log on as a batch job and add the new account to the list of authorized users.

Secure service
--------------
The insecure service on port 8080 is deprecated for a secure service running on
port 8443. This is required since iOS 10.0 defaults to only https
connections.  Currently there are two sevices running.

The secure service is using a DOI certificate issued against the Fully Qualified
Domain Name (FQDN) of the server (i.e. INPXXX.NPS.DOI.NET). The current certificate expires on 2019-06-29.
The certificate and details for creating a new certificate are at
`T:\GIS\PROJECTS\AKR\ArcGIS Server\https certificates`


Testing
-------

You can goto http://servername:8080/load (or https://servername.nps.doi.net:8443/load), and use the simple form to select a properly
formated zip file.  If the zip file can be uploaded, the server will respond with 'processing'
to find out if the zip file was processed without errors, check http://servername:8080/error
to see if there are any new errors, and http://servername:8080/dir to see if a new database was created

Data Access
-----------
You should share (as readonly) the `root_folder` in `Server.py` with all domain users, so they can either copy
the FGDB, or access the data via a layer file.  I hope to automate the creation of a layer file
and MXD, so that a service can automatically be created.  This could be done once when the database
is created.  Links to the service and layer file could be provided on the Park Observer website
so that users could easily check that their data is on the server and add it to thier maps.
