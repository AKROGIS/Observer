import sys
import os
import zipfile
import tempfile
import CsvLoader
import shutil

tool = "Park Observer Sync Tool"
usage = "Usage: {0} FILE.poz\n"


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
        database, protocol_json = CsvLoader.DatabaseCreator.database_for_protocol_file(protocol_path, fgdb_folder)
        # CSVLoad file
        CsvLoader.process_csv_folder(extraction_folder, protocol_json, database)
    finally:
        shutil.rmtree(extraction_folder)


def main():
    if len(sys.argv) != 2:
        print usage.format(sys.argv[0])
        sys.exit()
    archive_path = os.path.realpath(sys.argv[1])
    if not os.path.exists(archive_path):
        print "Error: '{0}' does not exist".format(archive_path)
        print usage.format(sys.argv[0])
        sys.exit()
    process(archive_path)

if __name__ == '__main__':
    main()
