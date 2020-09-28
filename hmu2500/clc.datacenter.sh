#!/bin/sh
id=`pm2 ls|grep clc.datacenter|awk '{print $2}'`
cd /root/huayuan/node_modules/clc.datacenter
pm2 start index.js --name clc.datacenter -f
pm2 delete ${id}