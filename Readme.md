# Arduino Yún Web panel

This is the web configuration panel and REST api provider you find running on your Yún at http://arduino.local/

It's a custom [LuCI](http://luci.subsignal.org/trac) controller.

It has two goals:
* hide all the complexity (and power) offered by LuCI in order to give users a fast and straightforward experience in setting up their Yún.
* provide an easy to use REST (web) API. Yún REST API is a "web way" to talk to your sketch through your browser: for example, you can query sensors value, send commands and share data between.

## Development: the easy way

The easiest way to hack the web panel is to copy on your Yún the files you find in this repo, maintaining the folders structure.

For example, file `usr/lib/lua/luci/controller/arduino/index.lua` will go to `/usr/lib/lua/luci/controller/arduino/index.lua` on your Yún.

Then access the webpanel at http://arduino.local/ (where "arduino" is the name of your Yún), properly edit file `index.lua` and refresh the page to see the changes.

Once done, copy the files back to your pc and submit us a [pull request](https://help.github.com/categories/63/articles), so that everyone can take advantage of the improvements you made.

## Development: the fast, local but hard way

You need a GNU/Linux box and the following packages: `subversion`, `gnupg`, `lua5.1`, `make`, `gcc`, `wget`

Open the terminal and type
```bash
sudo mkdir /etc/arduino
cd /etc/arduino
sudo wget https://raw.github.com/arduino/linino/master/trunk/package/linino/yun-conf/files/etc/arduino/gpg_gen_key_batch
sudo gpg --batch --gen-key /etc/arduino/gpg_gen_key_batch
sudo rm -f /etc/arduino/arduino_gpg.asc
sudo gpg --no-default-keyring --secret-keyring /etc/arduino/arduino_gpg.sec --keyring /etc/arduino/arduino_gpg.pub --export --armor --output /etc/arduino/arduino_gpg.asc
sudo chmod 644 /etc/arduino/arduino_gpg.*

cd ~ #makes sure your home folder is the starting one. Change it accordingly and adapt subsequent paths
svn co http://svn.luci.subsignal.org/luci/branches/luci-0.11 luci
git clone git@github.com:arduino/YunWebUI.git

cd luci
mkdir applications/arduino
cp applications/myapplication/Makefile applications/arduino
ln -s ~/YunWebUI/usr/lib/lua/luci applications/arduino/luasrc
ln -s ~/YunWebUI/www applications/arduino/htdocs
```

If everything run smoothly, you're now ready to start the webpanel. Type the last command on the terminal
```bash
make runhttpd
```
and finally go to http://localhost:8080/luci/webpanel