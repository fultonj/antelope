#!/bin/bash

source functions.sh

IMG_TASK="image_locations image_members image_properties image_tags images task_info tasks"
# IMG_TASK=""
META="metadef_namespace_resource_types metadef_namespaces metadef_objects metadef_properties metadef_resource_types metadef_tags"
# META=""

for TABLE in $IMG_TASK $META; do
    echo $TABLE;
    gsql "desc $TABLE"
    gsql "select * from $TABLE"
done
