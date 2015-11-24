__author__ = 'RESarwas'

import arcpy
import os
import glob
import DatabaseCreator
import dateutil.parser

#MACROS: Key indexes for GPS data in CSV data (T=Timestamp, X=Longitude, Y=Latitude)
T, X, Y = 0, 1, 2


def process_csv_folder(csv_path, protocol, database_path):
    version = protocol['meta-version']
    if version == 1:
        process_csv_folder_v1(csv_path, protocol, database_path)
    else:
        print("Unable to process protocol specification version {1}.".format(version))


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
        for line in track_file:
            items = line.split(',')
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

    feature_table_name = feature_name
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
        for line in feature_f:
            items = line.split(',')
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
            feature = [feature_shape] + \
                      [cast(protocol_items[i], feature_field_types[i]) for i in range(feature_fields_count)] + \
                      [cast(feature_items[i], feature_types[i]) for i in range(len(feature_items))] + \
                      [feature_gps_oid]
            observation = [observation_shape] + \
                          [cast(observe_items[i], observation_types[i]) for i in range(len(observe_items))] + \
                          [observation_gps_oid]
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
    attributes = DatabaseCreator.get_attributes(protocol['mission'])
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
            attributes = DatabaseCreator.get_attributes(feature)
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


if __name__ == '__main__':
    protocol_path = r"\\akrgis.nps.gov\inetApps\observer\protocols\sample.obsprot"
    fgdb_folder = r"C:\tmp\observer"
    csv_folder = r"C:\tmp\observer\test1"
    database, protocol_json = DatabaseCreator.database_for_protocol_file(protocol_path, fgdb_folder)
    process_csv_folder(csv_folder, protocol_json, database)
