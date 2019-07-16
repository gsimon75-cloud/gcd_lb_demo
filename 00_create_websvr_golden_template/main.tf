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
  provisioner_priv_key = "${file("../provisioner.pem")}"
  ssh_creds   = "${local.provisioner_user}:${local.provisioner_pub_key}\n${var.extra_creds}"

  machine_type         = "g1-small"
}

provider "google" {
  version     = "~> 2.5"
  credentials = "../${var.service_account_key_file}"
  project     = "${var.google_project_id}"
  region      = "${var.region}"
}

##############################################################################

resource "google_compute_disk" "webserver-golden-disk" {
  name        = "webserver-golden-disk"
  type        = "pd-standard"
  zone        = "${var.zone}"
  size        = 10
  image       = "centos-7"
}


##############################################################################

resource "google_compute_instance" "webserver-golden-instance" {
  name                      = "${var.project}-webserver-golden-instance"
  machine_type              = "${local.machine_type}"
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
    source      = "${google_compute_disk.webserver-golden-disk.self_link}"
  }

  network_interface {
    network = "default"
    access_config {
    }
  }

  connection {
    type        = "ssh"
    host        = "${self.network_interface.0.access_config.0.nat_ip}"
    user        = "${local.provisioner_user}"
    private_key = "${local.provisioner_priv_key}"
    timeout     = "2m"
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [ 
      "echo '==== Instance is available via SSH'",
    ]
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i inventory.gcp_compute.yaml websrv_golden.install.yaml -v"
  }

}

##############################################################################

#resource "google_compute_snapshot" "webserver-golden-disk-snapshot" {
#  name = "${var.project}-webserver"
#  depends_on  = [
#    google_compute_instance.webserver-golden-instance
#  ]
#  source_disk = "${google_compute_disk.webserver-golden-disk.name}"
#  zone = "${var.zone}"
#}


##############################################################################

resource "google_compute_image" "webserver-golden-image" {
  name        = "webserver-golden-image"
  depends_on  = [
    google_compute_instance.webserver-golden-instance
  ]
  source_disk = "${google_compute_disk.webserver-golden-disk.self_link}"
  #source_disk = "${google_compute_snapshot.webserver-golden-disk-snapshot.self_link}"
}


##############################################################################

resource "google_compute_instance_template" "webserver-template" {
  # NOTE: just using 'source_instance' is not yet supported by Terraform,
  # so we'll clone every setting one by one
  name        = "${var.project}-webserver"
  description = "This template is used to create frontend web server instances."
  machine_type         = "${local.machine_type}"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image  = "${google_compute_image.webserver-golden-image.self_link}"
    boot          = true
  }

  network_interface {
    network = "default"
    access_config {
    }
  }

  metadata = {
    sshKeys = "${local.ssh_creds}"
  }

  labels = {
    project = "${var.project}"
  }

}


##############################################################################

#resource "null_resource" "webserver-template" {
#  depends_on  = [
#    google_compute_instance.webserver-golden-instance
#  ]
#
#  provisioner "local-exec" {
#    command = "echo '==== Here will be the template created'"
#  }
#}

output "webserver-golden-instance-public-ip" {
  value = "${google_compute_instance.webserver-golden-instance.network_interface.0.access_config.0.nat_ip}"
}

output "webserver-golden-instance-private-ip" {
  value = "${google_compute_instance.webserver-golden-instance.network_interface.0.network_ip}"
}

# vim: set sw=2 ts=2 et:

