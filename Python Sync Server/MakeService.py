import arcpy
import os

# define local variables
workspace = r"D:\MapData\Observer"
protocol = "Test_Protocol_v1"
mxd = os.path.join(workspace, protocol + '.mxd')
mapDoc = arcpy.mapping.MapDocument(mxd)
#conectionfile = 'GIS Servers/arcgis on MyServer_6080 (publisher).ags' 

sddraft = os.path.join(workspace, protocol + '.sddraft')
sd = os.path.join(workspace, protocol + '.sd')

summary = 'Survey Protocol ' + protocol
tags = 'Survey, Protocol, Park Observer, ' + protocol

# create service definition draft
analysis = arcpy.mapping.CreateMapSDDraft(mapDoc, sddraft, protocol, 'ARCGIS_SERVER', 
                                          None, False, 'ParkObserver', summary, tags)

# stage and upload the service if the sddraft analysis did not contain errors
if analysis['errors'] == {}:
    # Execute StageService
    arcpy.StageService_server(sddraft, sd)
    # Execute UploadServiceDefinition
    #arcpy.UploadServiceDefinition_server(sd, conectionfile)
else: 
    # if the sddraft analysis contained errors, display them
    print analysis['errors']