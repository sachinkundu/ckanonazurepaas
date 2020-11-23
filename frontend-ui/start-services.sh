#!/bin/bash 
set -e
service nginx start
supervisord --nodaemon -e trace
