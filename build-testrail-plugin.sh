#!/bin/bash
set -evuo pipefail
IFS=$'\n\t'

rm -rf temp
git clone https://github.com/jenkinsci/testrail-plugin.git temp

cd temp

docker run -it --rm --name testrail-jenkins-build -v "$(pwd)":/usr/src/testrail-jenkins \
  -w /usr/src/testrail-jenkins \
  maven:3.5.3-jdk-8 mvn clean package

cd ..
