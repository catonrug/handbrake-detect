#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/handbrake-detect.git && cd handbrake-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

if [ -f ~/uploader_credentials.txt ]; then
sed "s/folder = test/folder = `echo $appname`/" ../uploader.cfg > ../gd/$appname.cfg
else
echo google upload will not be used cause ~/uploader_credentials.txt do not exist
fi

name=$(echo "HandBrake")
site=$(echo "https://handbrake.fr/downloads.php")

#download some information about site
wget -S --spider -o $tmp/output.log "$site"

#check if the site statuss is good
grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

#check if there is any exe installer
wget -qO- "$site" | sed "s/\d034/\n/g" | grep "exe$"
if [ $? -eq 0 ]; then

#create a new array [linklist] with two internet links inside and add one extra line
linklist=$(wget -qO- "$site" | sed "s/\d034/\n/g" | grep "exe$" | sed "s/^/https:\/\/handbrake\.fr\//" | sed '$alast line')

printf %s "$linklist" | while IFS= read -r link
do {

#make sure the tmp dirtory is there
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#get all info about link
wget -S --spider -o $tmp/output.log "$link"

#look for full link
grep -A99 "^Resolving" $tmp/output.log | sed "s/http/\nhttp/g" | sed "s/exe/exe\n/g" | grep "^http.*exe$" | head -1
if [ $? -eq 0 ]; then

#set full link
url=$(grep -A99 "^Resolving" $tmp/output.log | sed "s/http/\nhttp/g" | sed "s/exe/exe\n/g" | grep "^http.*exe$" | head -1)

#set filename
filename=$(echo $url | sed "s/^.*\///g")

#check if this filename is in database
grep "$filename" $db
if [ $? -ne 0 ]; then

echo new version detected!

echo Downloading $filename
wget $url -O $tmp/$filename
echo

#check downloded file size if it is fair enought
size=$(du -b $tmp/$filename | sed "s/\s.*$//g")
if [ $size -gt 2048000 ]; then

echo extracting installer..
7z x $tmp/$filename -y -o$tmp > /dev/null
echo

customname=$(find $tmp -maxdepth 1 -iname *`echo $name`.exe* | sed "s/^.*\///g") 
echo $customname

echo detecting version
version=$(pestr $tmp/$customname | grep -m1 -A1 "ProductVersion" | grep -v "ProductVersion" | sed "s/\.[0-9]\+//3")
echo

echo "$version" | grep "^[0-9]\+[\., ]\+[0-9]\+[\., ]\+[0-9]\+"
if [ $? -eq 0 ]; then
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo "$filename">> $db
echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $filename to Google Drive..
echo Make sure you have created \"$appname\" directory inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$filename"
echo
fi

echo $filename | grep "i686" > /dev/null
if [ $? -eq 0 ]; then
bit=$(echo "(32-bit)")
else
bit=$(echo "(64-bit)")
fi

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version $bit" "$url 
https://9bd14dcf5a14ca8c7f7d8bcd02adc5916034be53.googledrive.com/host/0B_3uBwg3RcdVVUtFWENJWUxYNEE/$filename 
$md5
$sha1"
} done
echo

else
#version do not match version pattern
echo version do not match version pattern
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Version do not match version pattern: 
$site "
} done
fi

else
#downloaded file size is to small
echo downloaded file size is to small
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Downloaded file size is to small: 
$site 
$filename 
$size"
} done
fi

else
#filename is already in database
echo filename is already in database
echo
fi

else
#full link not found
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "full link not found on site: 
$site "
} done
echo 
echo
fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null

} done

else
#there are no exe installers on site
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "There are no exe installers on site: 
$site "
} done
echo 
echo
fi

else
#site do not retrieve good status
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "The following site do not retrieve good http status code: 
$site "
} done
echo 
echo
fi
