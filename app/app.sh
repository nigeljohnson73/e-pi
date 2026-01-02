#/bin/sh

cd /webroot/*/app
source /webroot/*/py-*/bin/activate
python ./app.py >> /tmp/appd.log 2>&1

