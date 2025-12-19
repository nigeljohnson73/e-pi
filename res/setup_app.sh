#!/bin/sh

#git clone https://github.com/pimoroni/inky
#cd inky
#./install.sh

echo "Configuring spi and i2c"
sudo raspi-config nonint do_i2c 0
sudo raspi-config nonint do_spi 0
echo "Installing core tools"
sudo apt install -y python3 pip
echo "Creating virtual python environment"
#python3 -m venv --system-site-packages $HOME/.virtualenvs/e-pi
#. ~/.virtualenvs/e-pi/bin/activate
python3 -m venv --system-site-packages /webroot/e-pi/env
. /webroot/e-pi/env/bin/activate
echo "Installing inky libraries"
pip install matplotlib pandas-stubs inky urlextract

echo "Testing install. You should see a colour and resolution shown"
python app/test.py
echo "Setup complete"

