#!/bin/sh -x

cd www/luci-static/resources/arduino

rm *.ugly.*

for js in aes-enc base64 webpanel mouse PGencode PGpubkey rsa sha1; do
  uglifyjs -o $js.ugly.js $js.js
done

for js in aes-enc base64 mouse PGencode PGpubkey rsa sha1; do
  cat $js.ugly.js >> gpg.ugly.js
  rm $js.ugly.js
done

uglifycss style.css > style.ugly.css