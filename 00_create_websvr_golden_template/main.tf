variable "project" {
  description = "Name of the project"
}

variable "google_project_id" {
  description = "The project ID like 'yadda-123456', it's also in service_account_key_file"
}

variable "service_account_key_file" {
  description = "The private key json file for the service account"
}

variable "region" {
  description = "Region like 'us-central1' or 'europe-west1'"
}

variable "zone" {
  description = "Zone like 'europe-west1-c'"
}

variable "extra_creds" {
  description = "Extra credentials in the format '<user>:<openssh pub key line>\n<user>:...'"
}

locals {
  provisioner_user     = "prov"
  provisioner_pub_key  = "${file("../provisioner.openssh.pub")}"
  ssh_creds   = "${local.provisioner_user}:${local.provisioner_pub_key}\n${var.extra_creds}"
}

provider "google" {
  version     = "~> 2.5"
  credentials = "../${var.service_account_key_file}"
  project     = "${var.google_project_id}"
  region      = "${var.region}"
}

##############################################################################

resource "google_compute_instance" "webserver-template" {
  name                      = "${var.project}-webserver-template"
  machine_type              = "g1-small"
  zone                      = "${var.zone}"
  allow_stopping_for_update = true

  metadata = {
    sshKeys = "${local.ssh_creds}"
  }

  labels = {
    project = "${var.project}"
  }

  boot_disk {
    #auto_delete = false

    initialize_params {
      size  = 10
      type  = "pd-standard"
      image = "centos-7"
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }

  #provisioner "local-exec" {
  #  inline = [
  #    # substitute the public ip into the ansible inventory file 'hosts'
  #    "sed -r '/^webserver-template\>/ s/(ansible_host=)\S*/\1${google_compute_instance.webserver-template.network_interface.0.access_config.0.nat_ip}/' hosts"
  #  ]
  #}

}

##############################################################################

# NOTE: If the instance is restarted, its ephemeral external IP gets renewed,
# but a plain 'terraform show' will display only the contents of `terrform.tfstate`,
# and it may be misleading.
# 'terraform apply' refreshes the computed/generated values, so either use that,
# or display the up-to-date values from the data source instead.
# On the other hand, until the instance is created, the data source returns
# null, and that can't be indexed with '.0.', so that's an error, which
# should be handled, perhaps via a long and ugly ternary expression.

#data "google_compute_instance" "webserver-template" {
#  name = "${var.project}-webserver-template"
#  zone = "${var.zone}"
#}
#
#output "REAL-webserver-template-public-ip" {
#  value = "${data.google_compute_instance.webserver-template.network_interface.0.access_config.0.nat_ip}"
#}


##############################################################################

output "webserver-template-public-ip" {
  value = "${google_compute_instance.webserver-template.network_interface.0.access_config.0.nat_ip}"
}

output "webserver-template-private-ip" {
  value = "${google_compute_instance.webserver-template.network_interface.0.network_ip}"
}

# vim: set sw=2 ts=2 et:

