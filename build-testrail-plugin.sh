#!/bin/bash
set -evuo pipefail
IFS=$'\n\t'

mkdir temp || true
cd temp

wget https://github.com/jenkinsci/testrail-plugin/archive/testrail-1.0.6.tar.gz
tar -zxf testrail-1.0.6.tar.gz --strip-components 1

docker run -it --rm --name testrail-jenkins-build -v "$(pwd)":/usr/src/testrail-jenkins \
  -w /usr/src/testrail-jenkins \
  maven:3.5.3-jdk-8 mvn clean package

cd ..
