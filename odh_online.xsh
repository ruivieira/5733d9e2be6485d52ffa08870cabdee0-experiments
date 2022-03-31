#!/usr/bin/env xonsh
import xlog as l

token=input("Enter your OpenShift token: ")
url=input("Enter your OpenShift URL: ")
oc login --token=@(token) --server=@(url)