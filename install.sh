#!/bin/bash
DIR="$( cd "$( dirname "$0" )" && pwd )"
APPNAME="gaar"
vmc push $APPNAME --runtime="ruby19" --no-start --path=$DIR
vmc env-add $APPNAME DB_VERSION=1
vmc start $APPNAME
