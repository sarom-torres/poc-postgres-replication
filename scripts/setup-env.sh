#!/bin/bash

base_path=$(pwd)
primary_path="data/psql/primary"
standby_path="data/psql/standby"

list_dirname="scripts/dirname_list.txt" 

echo "Reading directories list..."
dir_list=()
while read -r dir
do
    echo "$dir"
    dir_list+=($dir)
done < "$list_dirname"

echo "Creating primary base directories..."
count=0
for i in "${dir_list[@]}"
do
    if [ ! -d ${base_path}"/"${primary_path}"/"${dir_list[count]} ] 
    then
        mkdir -p ${base_path}"/"${primary_path}"/"${dir_list[count]}
        echo "Directory ${primary_path}/${dir_list[count]} created"  
    else    
        echo "Directory ${primary_path}/${dir_list[count]} already exists"
    fi

    let count=count+1
done

echo "Creating standby base directories..."
count=0
for i in "${dir_list[@]}"
do
    if [ ! -d ${base_path}"/"${standby_path}"/"${dir_list[count]} ] 
    then
        mkdir -p ${base_path}"/"${standby_path}"/"${dir_list[count]}
        echo "Directory ${standby_path}/${dir_list[count]} created"  
    else    
        echo "Directory ${standby_path}/${dir_list[count]} already exists"
    fi

    let count=count+1
done

chown 999:999 -R data/
chown 999:999 -R certs/
sudo chmod 600 certs/server.key


