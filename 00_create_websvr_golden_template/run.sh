#!/usr/bin/env bash

stdbuf -oL ansible-playbook -i inventory.gcp_compute.yaml 0_create_instance.yaml "$@" 2>&1 | awk '{print strftime("%H:%M:%S ") $0; fflush();}' | stdbuf -oL tee apply.log 

