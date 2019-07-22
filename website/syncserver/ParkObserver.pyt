import os
import zipfile
import tempfile
import shutil
import glob
import dateutil.parser
import json
import csv

import arcpy

# Version: 2019-07-22
#   Catch parsing errors on feature tables and issue a warning
#   Ensure that table name that I use match table names created by ArcGIS (i.e. space to '_')

class Toolbox(object):
    """Define the toolbox (the name of the toolbox is the name of the
        .pyt file)."""
    def __init__(self):
        self.label = "Places Toolbox"
        self.alias = "Places"
        self.description = ("A collection of GIS tools for populating and "
                            "syncing Places with ArcGIS data (primarily data"
                            "in an EGIS data schema).")
        self.tools = [PozToFgdb]


# noinspection PyPep8Naming,PyMethodMayBeStatic,PyUnusedLocal
class PozToFgdb(object):
    def __init__(self):
        self.label = "Survey To FGDB"
        self.description = ("Creates a File Geodatabase from a Park Observer "
                            "Survey (*.poz).")

    def getParameterInfo(self):
        survey = arcpy.Parameter(
            name="survey",
            displayName="Observer Survey",
            direction="Input",
            datatype="DEFile",
            parameterType="Required")
        survey.filter.list = ["poz"]

        parameters = [survey]
        return parameters

    def updateParameters(self, parameters):
        pass

    def updateMessages(self, parameters):
        pass

    def execute(self, parameters, messages):
        survey = parameters[0].valueAsText
        process(survey)


# The remainder of this file is stolen from poz2fgdb.py for process()
# All function and "macro" definitions in CSVLoader.py
# All function from DatabaseCreator.py

#####################
# poz2fgdb.py
#####################

def process(archive):
    extraction_folder = tempfile.mkdtemp()
    try:
        # unzip file
        with zipfile.ZipFile(archive) as myzip:
            for name in myzip.namelist():
                myzip.extract(name, extraction_folder)
        # get the protocol file
        protocol_path = os.path.join(extraction_folder, "protocol.obsprot")
        fgdb_folder = os.path.dirname(archive)
        database, protocol_json = database_for_protocol_file(protocol_path, fgdb_folder)
        # CSVLoad file
        process_csv_folder(extraction_folder, protocol_json, database)
    finally:
        shutil.rmtree(extraction_folder)


#####################
# CsvLoader.py
#####################

# MACROS: Key indexes for GPS data in CSV data (T=Timestamp, X=Longitude, Y=Latitude)
T, X, Y = 0, 1, 2


def process_csv_folder(csv_path, protocol, database_path):
    version = protocol['meta-version']
    if version <= 2:
        process_csv_folder_v1(csv_path, protocol, database_path)
    else:
        print("Unable to process protocol specification version {0}.".format(version))


def process_csv_folder_v1(csv_path, protocol, database_path):
    csv_files = glob.glob(csv_path + r'\*.csv')
    csv_filenames = [os.path.splitext(os.path.basename(csv_file))[0] for csv_file in csv_files]
    gps_points_csv_name = protocol['csv']['gps_points']['name']
    track_logs_csv_name = protocol['csv']['track_logs']['name']
    gps_points_list = None
    track_log_oids = None
    # An edit session is needed to add items in a relationship, and to have multiple open insert cursors
    # the edit variable is not used because the with statement handles saving and aborting the edit session
    # noinspection PyUnusedLocal
    with arcpy.da.Editor(database_path) as edit:
        if track_logs_csv_name in csv_filenames and gps_points_csv_name in csv_filenames:
            track_log_oids = process_tracklog_path_v1(csv_path, gps_points_csv_name, track_logs_csv_name,
                                                      protocol, database_path)
            csv_filenames.remove(track_logs_csv_name)
        if gps_points_csv_name in csv_filenames:
            gps_points_list = process_gpspoints_path_v1(csv_path, gps_points_csv_name, protocol,
                                                        database_path, track_log_oids)
            csv_filenames.remove(gps_points_csv_name)
        for feature_name in csv_filenames:
            process_feature_path_v1(csv_path, feature_name, gps_points_list, protocol, database_path)


def process_tracklog_path_v1(csv_path, gps_point_filename, track_log_filename, protocol, database_path):
    point_path = os.path.join(csv_path, gps_point_filename + '.csv')
    track_path = os.path.join(csv_path, track_log_filename + '.csv')
    gps_points_header = ",".join(protocol['csv']['gps_points']['field_names'])
    track_log_header = ",".join(protocol['csv']['track_logs']['field_names'])
    with open(point_path) as point_f, open(track_path) as track_f:
        point_header = point_f.readline().rstrip()
        track_header = track_f.readline().rstrip()
        if point_header == gps_points_header and track_header.endswith(track_log_header):
            return process_tracklog_file_v1(point_f, track_f, protocol, database_path)
        else:
            return {}


def process_tracklog_file_v1(point_file, track_file, protocol, database_path):
    print ("building track logs")
    track_log_oids = {}
    mission_field_names, mission_field_types = extract_mission_attributes_from_protocol(protocol)
    mission_fields_count = len(mission_field_names)
    columns = ["SHAPE@"] + mission_field_names + protocol['csv']['track_logs']['field_names']
    types = protocol['csv']['track_logs']['field_types']
    table_name = protocol['csv']['track_logs']['name']
    table = os.path.join(database_path, table_name)
    s_key = protocol['csv']['track_logs']['start_key_indexes']
    e_key = protocol['csv']['track_logs']['end_key_indexes']
    gps_keys = protocol['csv']['gps_points']['key_indexes']
    last_point = None
# Need a schema lock to drop/create the index
#    arcpy.RemoveSpatialIndex_management(table)
    with arcpy.da.InsertCursor(table, columns) as cursor:
        for line in csv.reader(track_file):
            items = line  # line is a list of utf8 enocde strings (bytes)
            protocol_items, other_items = items[:mission_fields_count], items[mission_fields_count:]
            start_time, end_time = other_items[s_key[T]], other_items[e_key[T]]
            track, last_point = build_track_geometry(point_file, last_point, start_time, end_time, gps_keys)
            row = [track] + [cast(protocol_items[i], mission_field_types[i]) for i in range(len(protocol_items))] + \
                  [cast(other_items[i], types[i]) for i in range(len(other_items))]
            track_log_oids[start_time] = cursor.insertRow(row)
#    arcpy.AddSpatialIndex_management(table)
    return track_log_oids


def process_gpspoints_path_v1(csv_path, gps_point_filename, protocol, database_path, track_log_oids=None):
    path = os.path.join(csv_path, gps_point_filename + '.csv')
    gps_points_header = ",".join(protocol['csv']['gps_points']['field_names'])
    with open(path) as f:
        header = f.readline().rstrip()
        if header == gps_points_header:
            return process_gpspoints_file_v1(f, track_log_oids, protocol, database_path)
        else:
            return {}


def process_gpspoints_file_v1(file_without_header, tracklog_oids, protocol, database_path):
    print ("building gps points")
    results = {}
    columns = ["SHAPE@XY"] + protocol['csv']['gps_points']['field_names']
    if tracklog_oids:
        columns.append("TrackLog_ID")
    table_name = protocol['csv']['gps_points']['name']
    table = os.path.join(database_path, table_name)
    types = protocol['csv']['gps_points']['field_types']
    key = protocol['csv']['gps_points']['key_indexes']
    current_track_oid = None
# Need a schema lock to drop/create the index
#    arcpy.RemoveSpatialIndex_management(table)
    with arcpy.da.InsertCursor(table, columns) as cursor:
        for line in file_without_header:
            items = line.split(',')
            shape = (float(items[key[X]]), float(items[key[Y]]))
            row = [shape] + [cast(items[i], types[i]) for i in range(len(items))]
            if tracklog_oids:
                try:
                    current_track_oid = tracklog_oids[items[key[T]]]
                except KeyError:
                    pass
                row.append(current_track_oid)
            results[items[key[T]]] = cursor.insertRow(row)
#    arcpy.AddSpatialIndex_management(table)
    return results


def process_feature_path_v1(csv_path, feature_name, gps_points_list, protocol, database_path):
    feature_path = os.path.join(csv_path, feature_name + '.csv')
    feature_header = protocol['csv']['features']['header']
    with open(feature_path) as feature_f:
        file_header = feature_f.readline().rstrip()
        if file_header.endswith(feature_header):
            return process_feature_file_v1(feature_f, protocol, gps_points_list, feature_name, database_path)
        else:
            return {}


def process_feature_file_v1(feature_f, protocol, gps_points_list, feature_name, database_path):
    print ("building {0} features and observations".format(feature_name))

    feature_field_names, feature_field_types = extract_feature_attributes_from_protocol(protocol, feature_name)
    feature_fields_count = len(feature_field_names)

    feature_table_name = arcpy.ValidateTableName(feature_name, database_path)
    feature_table = os.path.join(database_path, feature_table_name)
    feature_columns = ["SHAPE@XY"] + feature_field_names + protocol['csv']['features']['feature_field_names'] + \
                      ["GpsPoint_ID", "Observation_ID"]
    feature_types = protocol['csv']['features']['feature_field_types']
    feature_field_map = protocol['csv']['features']['feature_field_map']
    f_key = protocol['csv']['features']['feature_key_indexes']

    observation_table_name = protocol['csv']['features']['obs_name']
    observation_table = os.path.join(database_path, observation_table_name)
    observation_columns = ["SHAPE@XY"] + protocol['csv']['features']['obs_field_names'] + \
                          ["GpsPoint_ID"]
    observation_types = protocol['csv']['features']['obs_field_types']
    observation_field_map = protocol['csv']['features']['obs_field_map']
    o_key = protocol['csv']['features']['obs_key_indexes']

# Need a schema lock to drop/create the index
#    arcpy.RemoveSpatialIndex_management(feature_table)
#    arcpy.RemoveSpatialIndex_management(observation_table)
    with arcpy.da.InsertCursor(feature_table, feature_columns) as feature_cursor, \
            arcpy.da.InsertCursor(observation_table, observation_columns) as observation_cursor:
        for line in csv.reader(feature_f):
            items = line  # line is a list of utf8 enocde strings (bytes)
            protocol_items, other_items = items[:feature_fields_count], items[feature_fields_count:]
            feature_items = filter_items_by_index(other_items, feature_field_map)
            observe_items = filter_items_by_index(other_items, observation_field_map)

            feature_timestamp = feature_items[f_key[T]]
            feature_shape = (float(feature_items[f_key[X]]), float(feature_items[f_key[Y]]))
            observation_timestamp = observe_items[o_key[T]]
            observation_shape = (float(observe_items[o_key[X]]), float(observe_items[o_key[Y]]))
            try:
                feature_gps_oid = gps_points_list[feature_timestamp]
            except KeyError:
                feature_gps_oid = None
            try:
                observation_gps_oid = gps_points_list[observation_timestamp]
            except KeyError:
                observation_gps_oid = None
            try:
                feature = [feature_shape] + \
                        [cast(protocol_items[i], feature_field_types[i]) for i in range(feature_fields_count)] + \
                        [cast(feature_items[i], feature_types[i]) for i in range(len(feature_items))] + \
                        [feature_gps_oid]
                observation = [observation_shape] + \
                            [cast(observe_items[i], observation_types[i]) for i in range(len(observe_items))] + \
                            [observation_gps_oid]
            except:
                arcpy.AddWarning("Skipping Bad Record.  Table: {0}; Record: {1}".format(feature_table,line))
                continue
            observation_oid = observation_cursor.insertRow(observation)
            feature.append(observation_oid)
            feature_cursor.insertRow(feature)
#    arcpy.AddSpatialIndex_management(feature_table)
#    arcpy.AddSpatialIndex_management(observation_table)


# Support functions

def cast(string, esri_type):
    esri_type = esri_type.upper()
    if esri_type == "DOUBLE" or esri_type == "FLOAT":
        return maybe_float(string)
    elif esri_type == "SHORT" or esri_type == "LONG":
        return maybe_int(string)
    elif esri_type == "DATE":
        return dateutil.parser.parse(string)
    elif esri_type == "TEXT" or esri_type == "BLOB":
        return string
    else:
        return None


def build_track_geometry(point_file, prior_last_point, start_time, end_time, keys):
    if prior_last_point:
        path = [prior_last_point]
    else:
        path = []
    point = None
    for line in point_file:
        items = line.split(',')
        timestamp = items[keys[T]]
        if timestamp <= start_time:
            path = []
        if timestamp < start_time:
            continue
        point = [float(items[keys[X]]), float(items[keys[Y]])]
        path.append(point)
        if timestamp == end_time:
            break
    esri_json = {
        "paths": [path],
        "spatialReference": {"wkid": 4326}}
    polyline = arcpy.AsShape(esri_json, True)
    return polyline, point


def extract_mission_attributes_from_protocol(protocol):
    field_names = []
    field_types = []
    attributes = get_attributes(protocol['mission'])
    for attribute in attributes:
        field_names.append(attribute['name'])
        field_types.append(attribute['type'])
    return field_names, field_types


def extract_feature_attributes_from_protocol(protocol, feature_name):
    field_names = []
    field_types = []
    attributes = None
    for feature in protocol['features']:
        if feature['name'] == feature_name:
            attributes = get_attributes(feature)
    for attribute in attributes:
        field_names.append(attribute['name'])
        field_types.append(attribute['type'])
    return field_names, field_types


def filter_items_by_index(items, indexes):
    """
    Gets a re-ordered subset of items
    :param items: A list of values
    :param indexes: a list of index in items
    :return: the subset of values in items at just indexes
    """
    results = []
    for i in indexes:
        results.append(items[i])
    return results


def maybe_float(string):
    try:
        return float(string)
    except ValueError:
        return None


def maybe_int(string):
    try:
        return int(string)
    except ValueError:
        return None


#####################
# DatabaseCreator.py
#####################


def database_for_protocol_file(protocol_path, fgdb_folder):
    with open(protocol_path, 'r') as f:
        protocol = json.load(f)
    # I either crashed or I have a good protocol
    if protocol['meta-name'] == 'NPS-Protocol-Specification':
        version = protocol['meta-version']
        if version <= 2:
            if 'csv' not in protocol:
                add_missing_csv_section(protocol)
            database = database_for_version1(protocol, fgdb_folder)
            return database, protocol
        else:
            print("Unable to process protocol specification version {1} (in file {0})."
                  .format(protocol_path, version))
    else:
        print("File {0} is not a valid protocol file".format(protocol_path))
    return None, None


def add_missing_csv_section(protocol):
    script_dir = os.path.dirname(os.path.realpath(__file__))
    csv_path = os.path.join(script_dir, 'csv.json')
    with open(csv_path, 'r') as f:
        csv = json.load(f)
        protocol['csv'] = csv
    return protocol


def database_for_version1(protocol, workspace):
    version = int(protocol['version'])  # get just the major number of the protocol
    raw_database_name = protocol['name'] + "_v" + str(version)
    valid_database_name = arcpy.ValidateTableName(raw_database_name, workspace) + ".gdb"
    database = os.path.join(workspace, valid_database_name)
    if not arcpy.Exists(database):
        database = build_database_version1(protocol, workspace, valid_database_name)
    return database


def build_database_version1(protocol, folder, database):
    print "Building {0} in {1}".format(database, folder)
    arcpy.CreateFileGDB_management(folder, database)
    fgdb = os.path.join(folder, database)
    sr = arcpy.SpatialReference(4326)
    domains = get_domains_from_protocol_v1(protocol)
    aliases = get_aliases_from_protocol_v1(protocol)
    build_domains(fgdb, domains)
    build_gpspoints_table_version1(fgdb, sr, protocol)
    build_tracklog_table_version1(fgdb, sr, get_attributes(protocol['mission'], domains, aliases), protocol)
    build_observations_table_version1(fgdb, sr, protocol)
    for feature in protocol['features']:
        build_feature_table_version1(fgdb, sr, feature['name'], get_attributes(feature, domains, aliases), protocol)
    build_relationships(fgdb, protocol)
    return fgdb


def get_attributes(feature, domains=None, aliases=None):
    attribute_list = []
    type_table = {
          0: "LONG",
        100: "SHORT",
        200: "LONG",
        300: "DOUBLE",  # 64bit int (not supported by ESRI)
        400: "DOUBLE",  # NSDecimal  (not supported by ESRI)
        500: "DOUBLE",
        600: "FLOAT",
        700: "TEXT",
        800: "SHORT",  # Boolean (use 0 = false, 1 = true)
        900: "DATE",
        1000: "BLOB",
    }
    for attribute in feature['attributes']:
        name = attribute['name']
        datatype = type_table[attribute['type']]
        try:
            nullable = attribute['optional']
        except KeyError:
            nullable = True

        alias = name.replace('_', ' ')
        if aliases:
            try:
                feature_aliases = aliases[feature['name']]
            except KeyError:
                try:
                    feature_aliases = aliases['mission']
                except KeyError:
                    feature_aliases = None
            if feature_aliases and name in feature_aliases:
                alias = feature_aliases[name]

        if attribute['type'] == 800:
            domain = 'YesNoBoolean'
        else:
            if domains and name in domains:
                domain = '{0}Codes'.format(name)
            else:
                domain = ''

        attribute_props = {'name': name, 'nullable': nullable, 'type': datatype, 'alias': alias, 'domain': domain}
        attribute_list.append(attribute_props)
    return attribute_list


def build_gpspoints_table_version1(fgdb, sr, protocol):
    table_name = protocol['csv']['gps_points']['name']
    field_names = protocol['csv']['gps_points']['field_names']
    field_types = protocol['csv']['gps_points']['field_types']
    arcpy.CreateFeatureclass_management(fgdb, table_name, 'POINT', '#', '#', '#', sr)
    # doing multiple operations on a view is faster than on a table
    view = arcpy.MakeTableView_management(os.path.join(fgdb, table_name), "view")
    try:
        # Protocol Attributes
        #  - None
        # Standard Attributes
        for i in range(len(field_names)):
            alias = field_names[i].replace('_', ' ')
            arcpy.AddField_management(view, field_names[i], field_types[i], '', '', '', alias)
        # Links to related data
        arcpy.AddField_management(view, "TrackLog_ID", "LONG")
    finally:
        arcpy.Delete_management(view)


def build_tracklog_table_version1(fgdb, sr, attributes, protocol):
    table_name = protocol['csv']['track_logs']['name']
    field_names = protocol['csv']['track_logs']['field_names']
    field_types = protocol['csv']['track_logs']['field_types']
    arcpy.CreateFeatureclass_management(fgdb, table_name, 'POLYLINE', '#', '#', '#', sr)
    view = arcpy.MakeTableView_management(os.path.join(fgdb, table_name), "view")
    try:
        # Protocol Attributes
        for attribute in attributes:
            arcpy.AddField_management(view, attribute['name'], attribute['type'], '', '', '', attribute['alias'],
                                      '', '', attribute['domain'])
        # Standard Attributes
        for i in range(len(field_names)):
            alias = field_names[i].replace('_', ' ')
            arcpy.AddField_management(view, field_names[i], field_types[i], '', '', '', alias)
            # Links to related data
            #  - None
    finally:
        arcpy.Delete_management(view)


def build_observations_table_version1(fgdb, sr, protocol):
    table_name = protocol['csv']['features']['obs_name']
    field_names = protocol['csv']['features']['obs_field_names']
    field_types = protocol['csv']['features']['obs_field_types']
    arcpy.CreateFeatureclass_management(fgdb, table_name, 'POINT', '', '', '', sr)
    view = arcpy.MakeTableView_management(os.path.join(fgdb, table_name), "view")
    try:
        # Protocol Attributes
        #  - None
        # Standard Attributes
        for i in range(len(field_names)):
            alias = field_names[i].replace('_', ' ')
            arcpy.AddField_management(view, field_names[i], field_types[i], '', '', '', alias)
        # Link to related data
        arcpy.AddField_management(view, "GpsPoint_ID", "LONG")
    finally:
        arcpy.Delete_management(view)


def build_feature_table_version1(fgdb, sr, raw_name, attributes, protocol):
    valid_feature_name = arcpy.ValidateTableName(raw_name, fgdb)
    field_names = protocol['csv']['features']['feature_field_names']
    field_types = protocol['csv']['features']['feature_field_types']
    arcpy.CreateFeatureclass_management(fgdb, valid_feature_name, 'POINT', '#', '#', '#', sr)
    view = arcpy.MakeTableView_management(os.path.join(fgdb, valid_feature_name), "view")
    try:
        # Protocol Attributes
        for attribute in attributes:
            arcpy.AddField_management(view, attribute['name'], attribute['type'], '', '', '', attribute['alias'],
                                      '', '', attribute['domain'])
        # Standard Attributes
        for i in range(len(field_names)):
            alias = field_names[i].replace('_', ' ')
            arcpy.AddField_management(view, field_names[i], field_types[i], '', '', '', alias)
        # Link to related data
        arcpy.AddField_management(view, "GpsPoint_ID", "LONG")
        arcpy.AddField_management(view, "Observation_ID", "LONG")
    finally:
        arcpy.Delete_management(view)


def build_relationships(fgdb, protocol):
    gps_points_table = os.path.join(fgdb, protocol['csv']['gps_points']['name'])
    track_logs_table = os.path.join(fgdb, protocol['csv']['track_logs']['name'])
    observations_table = os.path.join(fgdb, "Observations")
    arcpy.CreateRelationshipClass_management(track_logs_table, gps_points_table,
                                             os.path.join(fgdb, "GpsPoints_to_TrackLog"),
                                             "COMPOSITE", "GpsPoints", "TrackLog",
                                             "NONE", "ONE_TO_MANY", "NONE", "OBJECTID", "TrackLog_ID")

    arcpy.CreateRelationshipClass_management(gps_points_table, observations_table,
                                             os.path.join(fgdb, "Observations_to_GpsPoint"),
                                             "SIMPLE", "Observations", "GpsPoints",
                                             "NONE", "ONE_TO_ONE", "NONE", "OBJECTID", "GpsPoint_ID")

    for feature_obj in protocol['features']:
        feature = arcpy.ValidateTableName(feature_obj["name"], fgdb) 
        feature_table = os.path.join(fgdb, feature)
        arcpy.CreateRelationshipClass_management(gps_points_table, feature_table,
                                                 os.path.join(fgdb, "{0}_to_GpsPoint".format(feature)),
                                                 "SIMPLE", feature, "GpsPoint",
                                                 "NONE", "ONE_TO_ONE", "NONE", "OBJECTID", "GpsPoint_ID")
        arcpy.CreateRelationshipClass_management(observations_table, feature_table,
                                                 os.path.join(fgdb, "{0}_to_Observation".format(feature)),
                                                 "SIMPLE", feature, "Observation",
                                                 "NONE", "ONE_TO_ONE", "NONE", "OBJECTID", "Observation_ID")


def build_domains(fgdb, domains):
    arcpy.CreateDomain_management(fgdb, "YesNoBoolean", "Yes/No values", "SHORT", "CODED")
    arcpy.AddCodedValueToDomain_management(fgdb, "YesNoBoolean", 0, "No")
    arcpy.AddCodedValueToDomain_management(fgdb, "YesNoBoolean", 1, "Yes")
    for domain in domains:
        name = '{0}Codes'.format(domain)
        description = 'Valid values for {0}'.format(domain)
        arcpy.CreateDomain_management(fgdb, name, description, "SHORT", "CODED")
        items = domains[domain]
        for i in range(len(items)):
            arcpy.AddCodedValueToDomain_management(fgdb, name, i, items[i])


def get_aliases_from_protocol_v1(protocol):
    results = {}
    for feature in [protocol['mission']] + protocol['features']:
        try:
            feature_name = feature['name']
        except KeyError:
            feature_name = 'mission'
        feature_results = {}
        for section in feature['dialog']['sections']:
            try:
                section_title = section['title']
            except KeyError:
                section_title = None
            field_title = None
            for field in section['elements']:
                try:
                    field_title = field['title']
                except KeyError:
                    pass
                try:
                    field_name = field['bind'].split(':')[1]
                except (KeyError, IndexError, AttributeError) as e:
                    field_name = None
                if field_name and field_title:
                    if section_title:
                        field_alias = '{0} {1}'.format(section_title, field_title)
                    else:
                        field_alias = field_title
                    feature_results[field_name] = field_alias
        results[feature_name] = feature_results
    return results


def get_domains_from_protocol_v1(protocol):
    results = {}
    mission_attribute_names = [attrib['name'] for attrib in protocol['mission']['attributes'] if attrib['type'] == 100]
    for section in protocol['mission']['dialog']['sections']:
        for field in section['elements']:
            if field['type'] == 'QRadioElement' and field['bind'].startswith('selected:'):
                name = field['bind'].replace('selected:', '').strip()
                if name in mission_attribute_names:
                    results[name] = field['items']
    for feature in protocol['features']:
        attribute_names = [attrib['name'] for attrib in feature['attributes'] if attrib['type'] == 100]
        for section in feature['dialog']['sections']:
            for field in section['elements']:
                if field['type'] == 'QRadioElement' and field['bind'].startswith('selected:'):
                    name = field['bind'].replace('selected:', '').strip()
                    if name in attribute_names:
                        results[name] = field['items']
    return results
