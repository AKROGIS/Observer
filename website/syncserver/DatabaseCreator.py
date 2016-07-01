import arcpy
import json
import os


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
        feature = feature_obj["name"]
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


if __name__ == '__main__':
    database_for_protocol_file(protocol_path=r"\\akrgis.nps.gov\inetApps\observer\protocols\sample.obsprot",
                               fgdb_folder=r"C:\tmp\observer")
