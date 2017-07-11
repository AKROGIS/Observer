__author__ = 'RESarwas'

import os
import zipfile
import tempfile
import CsvLoader
import shutil
import ssl

from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer


class SyncHandler(BaseHTTPRequestHandler):
    root_folder = r"E:\MapData\Observer"
    upload_folder = os.path.join(root_folder, "upload")
    error_log = os.path.join(root_folder, "error.log")
    name = "Park Observer Sync Tool"
    usage = "Usage:\n" + \
            "\tPOST with /sync with a zip containing the protocol and CSV files\n" + \
            "\tGET with /dir to list the databases\n" + \
            "\tGET with /load to show a form to upload a zip file\n" + \
            "\tGET with /error to list the error log file\n" +\
            "\tGET with /help for this message\n"

    def do_GET(self):
        if self.path == '/error':
            self.std_response()
            if os.path.exists(self.error_log):
                self.wfile.write("Error Log contents:\n")
                with open(self.error_log) as fh:
                    self.wfile.write(fh.read())
            else:
                self.wfile.write("There are no errors to report.")
        elif self.path == '/dir':
            self.std_response()
            self.wfile.write("Databases:\n")
            for f in os.listdir(self.root_folder):
                if f != "upload" and f != "error.log":
                    self.wfile.write("\t{0}\n".format(f))
        elif self.path == '/help':
            self.std_response()
            self.wfile.write(self.usage)
        elif self.path == '/load':
            html = """
        <html><body>
        <form enctype="multipart/form-data" method="post" action="sync">
        <p>File: <input type="file" name="file"></p>
        <p><input type="submit" value="Upload"></p>
        </form>
        </body></html>
        """
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.send_header('Content-length', len(html))
            self.end_headers()
            self.wfile.write(html)
        else:
            self.std_response()
            self.wfile.write("Unknown command request '{0}'\n".format(self.path[1:]))
            self.wfile.write(self.usage)

    def std_response(self):
        self.send_response(200)
        self.send_header('Content-type', 'text')
        self.end_headers()
        self.wfile.write("{0}\n".format(self.name))

    def err_response(self):
        self.send_response(500)
        self.send_header('Content-type', 'text')
        self.end_headers()

    def do_POST(self):
        if self.path == '/sync':
            try:
                length = self.headers.getheader('content-length')
                data = self.rfile.read(int(length))
                fd, fname = tempfile.mkstemp(dir=self.upload_folder)
                try:
                    with open(fname, 'wb') as fh:
                        fh.write(data)
                    csv_folder = tempfile.mkdtemp(dir=self.upload_folder)
                    try:
                        self.process(fname, csv_folder)
                    finally:
                        pass #shutil.rmtree(csv_folder)
                    self.std_response()
                    self.wfile.write("\tSuccessfully applied the uploaded file")
                except Exception as ex:
                    self.err_response()
                    msg = "{0}:{1} - {2}\n".format(self.log_date_time_string(), type(ex).__name__, ex)
                    self.wfile.write(msg)
                    with open(self.error_log, 'a') as eh:
                         eh.write(msg)
                finally:
                    os.close(fd)
                    #os.remove(fname)
            except Exception as ex:
                self.err_response()
                self.wfile.write("Unable to create/open temporary file on server:\n\t{0} - {1}".format(type(ex).__name__, ex))

    def process(self, filename, csv_folder):
        #unzip file
        with zipfile.ZipFile(filename) as myzip:
            for name in myzip.namelist():
                myzip.extract(name, csv_folder)
        #get the protocol file
        protocol_path = os.path.join(csv_folder, "protocol.obsprot")
        fgdb_folder = self.root_folder
        database, protocol_json = CsvLoader.DatabaseCreator.database_for_protocol_file(protocol_path, fgdb_folder)
        #CSVLoad file
        CsvLoader.process_csv_folder(csv_folder, protocol_json, database)


if not os.path.exists(SyncHandler.upload_folder):
    os.makedirs(SyncHandler.upload_folder)
# Next line is for an insecure (http) service
# server = HTTPServer(('', 8080), SyncHandler)
# Next two lines are for a secure (https) service
server = HTTPServer(('', 8443), SyncHandler)
server.socket = ssl.wrap_socket (server.socket, keyfile='key.pem', certfile='cert.pem', server_side=True)
# For more info on https see: https://gist.github.com/dergachev/7028596
server.serve_forever()
