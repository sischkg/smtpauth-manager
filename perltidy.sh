#!/bin/sh

cp perltidyrc $HOME/.perltidyrc

find . -name "*.pm" -exec perltidy -b {} \;
find . -name "*.pl" -exec perltidy -b {} \;
find . -name "*.t" -exec perltidy -b {} \;
find . -name "*.cgi" -exec perltidy -b {} \;
#find . -name "*.pm" -exec perltidy -html -b {} \;
#find . -name "*.pl" -exec perltidy -html -b {} \;


