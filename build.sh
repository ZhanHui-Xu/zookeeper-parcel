#!/bin/bash
set -x
set -e
set -v

ZOOKEEPER_URL=`sed '/^ZOOKEEPER_URL=/!d;s/.*=//' zookeeper-parcel.properties` 
ZOOKEEPER_VERSION=`sed '/^ZOOKEEPER_VERSION=/!d;s/.*=//' zookeeper-parcel.properties`
EXTENS_VERSION=`sed '/^EXTENS_VERSION=/!d;s/.*=//' zookeeper-parcel.properties`
OS_VERSION=`sed '/^OS_VERSION=/!d;s/.*=//' zookeeper-parcel.properties`
CDH_MIN_FULL=`sed '/^CDH_MIN_FULL=/!d;s/.*=//' zookeeper-parcel.properties`
CDH_MIN=`sed '/^CDH_MIN=/!d;s/.*=//' zookeeper-parcel.properties`
CDH_MAX_FULL=`sed '/^CDH_MAX_FULL=/!d;s/.*=//' zookeeper-parcel.properties`
CDH_MAX=`sed '/^CDH_MAX=/!d;s/.*=//' zookeeper-parcel.properties`

zookeeper_service_name="ZOOKEEPER"
zookeeper_service_name_lower="$( echo $zookeeper_service_name | tr '[:upper:]' '[:lower:]' )"
zookeeper_archive="$( basename $ZOOKEEPER_URL )"
zookeeper_unzip_folder="${zookeeper_service_name_lower}-${ZOOKEEPER_VERSION}"
zookeeper_folder_lower="$( basename $zookeeper_archive .tgz )"
zookeeper_parcel_folder="$( echo $zookeeper_folder_lower | tr '[:lower:]' '[:upper:]')"
zookeeper_parcel_name="$zookeeper_parcel_folder-el${OS_VERSION}.parcel"
zookeeper_built_folder="${zookeeper_parcel_folder}_build"
zookeeper_csd_build_folder="zookeeper_csd_build"

function build_cm_ext {  #Checkout if dir does not exist
  if [ ! -d cm_ext ]; then
    git clone https://github.com/cloudera/cm_ext.git
  fi
  if [ ! -f cm_ext/validator/target/validator.jar ]; then
    cd cm_ext
    #git checkout "$CM_EXT_BRANCH"
    mvn install -Dmaven.test.skip=true
    cd ..
  fi
}

function get_zookeeper {
  if [ ! -f "$zookeeper_archive" ]; then
    wget $ZOOKEEPER_URL --no-check-certificate
  fi
  #zookeeper_md5="$( md5sum $zookeeper_archive | cut -d' ' -f1 )"
  #if [ "$zookeeper_md5" != "$ZOOKEEPER_MD5" ]; then
   # echo ERROR: md5 of $zookeeper_archive is not correct
    #exit 1
  #fi
  if [ ! -d "$zookeeper_unzip_foleder" ]; then
    tar -xvf $zookeeper_archive
  fi
}

function build_zookeeper_parcel {
  if [ -f "$zookeeper_built_folder/$zookeeper_parcel_name" ] && [ -f "$zookeeper_built_folder/manifest.json" ]; then
    return
  fi
  if [ ! -d $zookeeper_parcel_folder ]; then
    get_zookeeper
    mkdir -p $zookeeper_parcel_folder/lib
    sleep 3
    echo ${zookeeper_unzip_folder}
    mv ${zookeeper_unzip_folder}  ${zookeeper_parcel_folder}/lib/${zookeeper_service_name_lower}
  fi
  cp -r parcel/meta $zookeeper_parcel_folder/
  chmod 755 parcel/zookeeper*

  sed -i -e "s/%zookeeper_version%/$zookeeper_parcel_folder/" ./$zookeeper_parcel_folder/meta/zookeeper_env.sh
  sed -i -e "s/%VERSION%/$ZOOKEEPER_VERSION/" ./$zookeeper_parcel_folder/meta/parcel.json
  sed -i -e "s/%EXTENS_VERSION%/$EXTENS_VERSION/" ./$zookeeper_parcel_folder/meta/parcel.json
  sed -i -e "s/%CDH_MAX_FULL%/$CDH_MAX_FULL/" ./$zookeeper_parcel_folder/meta/parcel.json
  sed -i -e "s/%CDH_MIN_FULL%/$CDH_MIN_FULL/" ./$zookeeper_parcel_folder/meta/parcel.json
  sed -i -e "s/%SERVICENAME%/$zookeeper_service_name/" ./$zookeeper_parcel_folder/meta/parcel.json
  sed -i -e "s/%SERVICENAMELOWER%/$zookeeper_service_name_lower/" ./$zookeeper_parcel_folder/meta/parcel.json
  java -jar cm_ext/validator/target/validator.jar -d ./$zookeeper_parcel_folder
  mkdir -p $zookeeper_built_folder
  tar zcvhf ./$zookeeper_built_folder/$zookeeper_parcel_name $zookeeper_parcel_folder --owner=root --group=root
  java -jar cm_ext/validator/target/validator.jar -f ./$zookeeper_built_folder/$zookeeper_parcel_name
  python cm_ext/make_manifest/make_manifest.py ./$zookeeper_built_folder
  sha1sum ./$zookeeper_built_folder/$zookeeper_parcel_name |awk '{print $1}' > ./$zookeeper_built_folder/${zookeeper_parcel_name}.sha
}

function build_zookeeper_csd {
  JARNAME=${zookeeper_service_name}-${ZOOKEEPER_VERSION}.jar
  if [ -f "$JARNAME" ]; then
    return
  fi
  rm -rf ${zookeeper_csd_build_folder}
  cp -rf ./csd ${zookeeper_csd_build_folder}
  sed -i -e "s/%SERVICENAME%/$zookeeper_service_name/" ${zookeeper_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%SERVICENAMELOWER%/$zookeeper_service_name_lower/" ${zookeeper_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%VERSION%/$ZOOKEEPER_VERSION/" ${zookeeper_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%CDH_MIN%/$CDH_MIN/" ${zookeeper_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%CDH_MAX%/$CDH_MAX/" ${zookeeper_csd_build_folder}/descriptor/service.sdl
  sed -i -e "s/%SERVICENAMELOWER%/$zookeeper_service_name_lower/" ${zookeeper_csd_build_folder}/scripts/control.sh
  java -jar cm_ext/validator/target/validator.jar -s ${zookeeper_csd_build_folder}/descriptor/service.sdl -l "ZOOKEEPER_SERVER"
  jar -cvf ./$JARNAME -C ${zookeeper_csd_build_folder} .
}


case $1 in
parcel)
  build_cm_ext
  build_zookeeper_parcel
  ;;
csd)
  build_zookeeper_csd
  ;;
*)
  echo "Usage: $0 [parcel|csd]"
  ;;
esac

