#!/bin/bash
cp -R customers $1
sed -i 's\NEW_CUSTOMER\'$1'\' $1/main.tf $1/vars.tf
