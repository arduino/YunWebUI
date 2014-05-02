#!/bin/bash -e

echo "=== Uglifying JSs and CSSs..."

./uglify_assets.bash

echo "=== Packaging..."

SOURCE_FOLDER=`pwd`
PREFIX=`basename $SOURCE_FOLDER`

cd ..

VERSION=1.2.1

tar --transform "s|$PREFIX/|luci-app-arduino-webpanel-$VERSION/|g" -cjv -f luci-app-arduino-webpanel-$VERSION.tar.bz2 \
  $PREFIX/www/index.html \
  $PREFIX/www/luci-static/resources/arduino/*.ugly.* \
  $PREFIX/www/luci-static/resources/arduino/*.min.* \
  $PREFIX/www/luci-static/resources/arduino/*.png \
  $PREFIX/www/keystore_manager_example \
  $PREFIX/usr

mv luci-app-arduino-webpanel-* $SOURCE_FOLDER

echo "=== Done!"

cd -

md5sum luci-app-arduino-webpanel*
