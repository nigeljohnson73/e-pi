#/bin/sh

cd /webroot/*/app
#sleep 20
source /webroot/*/env/bin/activate
python ./app.py >> /tmp/appd.log 2>&1

