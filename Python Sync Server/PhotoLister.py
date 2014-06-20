__author__ = 'RESarwas'

import os
import datetime

start = ur"T:\PROJECTS\AKR\Buildings\PhotosFromAllYears-Geotagged"
csv = os.path.join(start, "PhotoList.csv")

with open(csv, 'w') as f:
    f.write('photo,folder,size,filedate,id,date,master,tagged,thumbnail,new_id,new_date,new_name\n')
    for root, dirs, files in os.walk(start):
        folder = root.replace(start, '.')
        for filename in files:
            base, extension = os.path.splitext(filename)
            if extension.lower() == '.jpg':
                path = os.path.join(root, filename)
                newbase = base.lower().replace('_', '-')
                if -1 < newbase.find('-tag'):
                    master = 'N'
                    tagged = 'Y'
                    newbase = newbase.replace('-tag', '')
                else:
                    master = 'Y'
                    tagged = 'N'
                if -1 < newbase.find('-thm'):
                    thumb = 'Y'
                    master = 'N'
                    newbase = newbase.replace('-thm', '')
                else:
                    thumb = 'N'
                try:
                    code, date = newbase.split("-", 1)
                except ValueError:
                    code, date = newbase, ''
                size = os.path.getsize(path)/1024/1024.0
                filedate = datetime.datetime.fromtimestamp(os.path.getmtime(path))
                f.write('{0},{1},{2:0.3f},{3},{4},{5},{6},{7},{8},,,\n'.format(filename, folder, size, filedate, code, date, master, tagged, thumb))
