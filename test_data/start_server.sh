#!/bin/sh
cd `dirname $0`
echo `pwd` 
python -m SimpleHTTPServer 8000  &
