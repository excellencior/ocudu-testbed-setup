#!/bin/bash

docker stop ocudu-sandbox
docker container prune
docker rmi ocudu-ubuntu:latest

echo "==== CLEANUP COMPLETE ===="