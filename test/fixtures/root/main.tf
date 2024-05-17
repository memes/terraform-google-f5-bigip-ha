terraform {
  required_version = ">= 0.14.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 3.85"
    }
  }
}

# Upstream module *requires* setting parameters on the provider
provider "google" {
  project = var.project_id
  region  = var.region
}

module "test" {
  source                            = "./../../../"
  instances                         = var.instances
  num_instances                     = var.num_instances
  prefix                            = var.prefix
  project_id                        = var.project_id
  zones                             = var.zones
  min_cpu_platform                  = var.min_cpu_platform
  machine_type                      = var.machine_type
  automatic_restart                 = var.automatic_restart
  preemptible                       = var.preemptible
  image                             = var.image
  disk_type                         = var.disk_type
  disk_size_gb                      = var.disk_size_gb
  mgmt_interface                    = var.mgmt_interface
  external_interface                = var.external_interface
  internal_interfaces               = var.internal_interfaces
  f5_username                       = var.f5_username
  f5_password                       = var.f5_password
  onboard_log                       = var.onboard_log
  libs_dir                          = var.libs_dir
  gcp_secret_manager_authentication = var.gcp_secret_manager_authentication
  gcp_secret_name                   = var.gcp_secret_name
  gcp_secret_version                = var.gcp_secret_version
  DO_URL                            = var.DO_URL
  AS3_URL                           = var.AS3_URL
  TS_URL                            = var.TS_URL
  CFE_URL                           = var.CFE_URL
  FAST_URL                          = var.FAST_URL
  INIT_URL                          = var.INIT_URL
  labels                            = var.labels
  service_account                   = var.service_account
  f5_ssh_publickey                  = var.f5_ssh_publickey
  custom_user_data                  = var.custom_user_data
  metadata                          = var.metadata
  sleep_time                        = var.sleep_time
  network_tags                      = var.network_tags
}
