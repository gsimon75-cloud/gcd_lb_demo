#!/bin/bash

set -e
THIS_PATH=$(readlink -m $(dirname -- $0))

STATE=terraform.tfstate

# `terraform plan -destroy -out xyz` and then `terraform apply xyz` does not work. period.
# and i'm fed up to the gills with terraform thingies that 'do not work', and i dont really
# care if they just dont work or dont work just yet.

function do_install() {
    if [ -e $STATE ]; then
        echo "Stop and destroy it first (and also remove $STATE)"
        # Reason: leftover variable values in the state file make
        # the situation different from the clean state, i.e.
        # you may make changes that work when started from an
        # existing state, but not from a clean one
        exit 1
    fi

    terraform init
    terraform get
    time stdbuf -oL terraform apply -auto-approve -no-color -backup=- 2>&1 | awk '{ print strftime("%Y-%m-%d %H:%M:%S"), $0; fflush(); }' | sed -ruf "$THIS_PATH/junkfilter.sed" | tee apply.log
}

function do_destroy() {
    if [ ! -e $STATE ]; then
        echo "Don't know what to destroy (there is no $STATE)"
	exit 1
    fi
    terraform destroy -force -backup=- -refresh=false
    date
    rm $STATE
}

for arg in "$@"; do
	case "$arg" in
	    install)
		do_install;;

	    destroy)
		do_destroy;;

	    clean)
		rm -f *tfstate*;;

	    *)
		echo "Unknown command $1"
		exit 1;;
	esac
done
