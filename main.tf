terraform {
  required_version = ">= 1.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

locals {
  vm_names = try(length(var.instances), 0) > 0 ? keys(var.instances) : [for i in range(0, var.num_instances) : format("%s-%02d", var.prefix, i + 1)]
}

data "google_compute_subnetwork" "dsc_mgmt" {
  self_link = var.mgmt_interface.subnet_id
}

data "google_compute_subnetwork" "dsc_data" {
  self_link = var.external_interface.subnet_id
}

resource "google_compute_address" "mgmt" {
  for_each     = toset([for name in local.vm_names : name if try(var.instances[name].mgmt_primary_ip, "") == ""])
  name         = format("%s-mgmt", each.key)
  description  = format("Reserved control-plane address for BIG-IP instance %s", each.key)
  address_type = "INTERNAL"
  ip_version   = "IPV4"
  purpose      = "GCE_ENDPOINT"
  project      = var.project_id
  subnetwork   = data.google_compute_subnetwork.dsc_mgmt.id
  region       = data.google_compute_subnetwork.dsc_mgmt.region
  labels       = var.labels
}

resource "google_compute_address" "external" {
  for_each     = toset([for name in local.vm_names : name if try(var.instances[name].external_primary_ip, "") == ""])
  name         = format("%s-ext", each.key)
  description  = format("Reserved data-plane address for BIG-IP instance %s", each.key)
  address_type = "INTERNAL"
  ip_version   = "IPV4"
  purpose      = "GCE_ENDPOINT"
  project      = var.project_id
  subnetwork   = data.google_compute_subnetwork.dsc_data.id
  region       = data.google_compute_subnetwork.dsc_data.region
  labels       = var.labels
}

module "instances" {
  for_each = { for i, name in local.vm_names : name => {
    zone = element(var.zones, i)
    metadata = merge({
      # For the first instance, BigIPPeerName, BigIPPeerIP, and BigIPPeerOwnerIndex will refer to the and BIG_IP_HA_PEER_INDEX will refer to the second instance, for all
      # others it will refer to first instance
      BigIPHAPeerName       = local.vm_names[i == 0 ? 1 : 0]
      BigIPHAPeerIP         = try(var.instances[local.vm_names[i == 0 ? 1 : 0]].external.primary_ip, google_compute_address.external[local.vm_names[i == 0 ? 1 : 0]].address)
      BigIPHAPeerOwnerIndex = i == 0 ? "1" : "0"
    }, (var.metadata != null ? var.metadata : {}), try(var.instances[name].metadata, {}))
    mgmt_subnet_ids = [{
      subnet_id          = var.mgmt_interface.subnet_id
      public_ip          = var.mgmt_interface.public_ip
      private_ip_primary = try(var.instances[name].mgmt.primary_ip, google_compute_address.mgmt[name].address)
      # TODO @memes - upstream doesn't support assigning Alias IPs on control-plane interfaces
      # private_ip_secondary = try(var.instances[name].mgmt.secondary_ip, "")
    }]
    external_subnet_ids = [{
      subnet_id            = var.external_interface.subnet_id
      public_ip            = var.external_interface.public_ip
      private_ip_primary   = try(var.instances[name].external.primary_ip, google_compute_address.external[name].address)
      private_ip_secondary = try(var.instances[name].external.secondary_ip, "")
    }]
    internal_subnet_ids = var.internal_interfaces == null ? [] : [for j, interface in var.internal_interfaces : {
      subnet_id          = interface.subnet_id
      public_ip          = interface.public_ip
      private_ip_primary = try(var.instances[name].internals[j].primary_ip, "")
      # TODO @memes - upstream doesn't support assigning Alias IPs on 'internal' interfaces
      # private_ip_secondary = try(var.instances[name].internals[j].secondary_ip, "")
    }]
    }
  }
  source                            = "F5Networks/bigip-module/gcp"
  version                           = "1.1.19"
  vm_name                           = each.key
  prefix                            = var.prefix
  project_id                        = var.project_id
  zone                              = each.value.zone
  min_cpu_platform                  = var.min_cpu_platform
  machine_type                      = var.machine_type
  automatic_restart                 = var.automatic_restart
  preemptible                       = var.preemptible
  image                             = var.image
  disk_type                         = var.disk_type
  disk_size_gb                      = var.disk_size_gb
  mgmt_subnet_ids                   = each.value.mgmt_subnet_ids
  external_subnet_ids               = each.value.external_subnet_ids
  internal_subnet_ids               = each.value.internal_subnet_ids
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
  metadata                          = each.value.metadata
  sleep_time                        = var.sleep_time

  depends_on = [
    google_compute_address.mgmt,
    google_compute_address.external,
  ]
}


# resource "google_compute_instance_group" "group" {
#   for_each    = { for k, v in module.instances : v.zone => v.self_link... if var.targets.groups }
#   project     = var.project_id
#   name        = format("%s-%02d", var.prefix, index(var.zones, each.key))
#   description = format("BIG-IP instance group (%s %s)", var.prefix, each.key)
#   zone        = each.key
#   instances   = each.value
# }

# resource "google_compute_target_instance" "target" {
#   for_each = { for i in range(0, local.num_bigips) : "${i}" => {
#     name      = module.instances["${i}"].name
#     zone      = module.instances["${i}"].zone
#     self_link = module.instances["${i}"].self_link
#   } if var.targets.instances }
#   #for_each    = { for k, v in module.instances : v.name => { zone = v.zone, self_link = v.self_link } if var.targets.instances }
#   project     = var.project_id
#   name        = format("%s-tgt", each.value.name)
#   description = format("BIG-IP %s target instance", each.value.name)
#   zone        = each.value.zone
#   instance    = each.value.self_link
# }

# DSC requires BIG-IP instances to communicate via HTTPS management port on
# control-plane network.
resource "google_compute_firewall" "mgt_sync" {
  project     = data.google_compute_subnetwork.dsc_mgmt.project
  name        = format("%s-allow-dsc-mgmt", var.prefix)
  network     = data.google_compute_subnetwork.dsc_mgmt.network
  description = "BIG-IP ConfigSync for management network"
  direction   = "INGRESS"
  source_service_accounts = [
    var.service_account,
  ]
  target_service_accounts = [
    var.service_account,
  ]
  allow {
    protocol = "tcp"
    ports = [
      443,
    ]
  }
}

# DSC requires BIG-IP instances to communicate via known ports on data-plane
# network.
resource "google_compute_firewall" "data_sync" {
  project     = data.google_compute_subnetwork.dsc_data.project
  name        = format("%s-allow-dsc-data", var.prefix)
  network     = data.google_compute_subnetwork.dsc_data.network
  description = "BIG-IP ConfigSync for data-plane network"
  direction   = "INGRESS"
  source_service_accounts = [
    var.service_account,
  ]
  target_service_accounts = [
    var.service_account,
  ]
  allow {
    protocol = "tcp"
    ports = [
      443,
      4353,
    ]
  }
  allow {
    protocol = "udp"
    ports = [
      1026,
    ]
  }
}
