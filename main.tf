terraform {
  required_version = ">= 1.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

data "google_compute_subnetwork" "mgmt" {
  self_link = var.mgmt_interface.subnet_id
}

data "google_compute_subnetwork" "external" {
  self_link = var.external_interface.subnet_id
}

data "google_compute_subnetwork" "internal" {
  for_each  = { for i, v in var.internal_interfaces == null ? [] : var.internal_interfaces : "${i}" => v.subnet_id }
  self_link = each.value
}

data "google_compute_zones" "zones" {
  project = data.google_compute_subnetwork.mgmt.project
  region  = data.google_compute_subnetwork.mgmt.region
}

resource "random_shuffle" "zones" {
  input = data.google_compute_zones.zones.names
}

# Generate a pseudo-random tag value that can be used in firewall rules that are unique to this cluster of BIG-IPs.
resource "random_id" "cluster_tag" {
  prefix      = var.prefix
  byte_length = 4
}

module "template" {
  source                 = "./modules/template/"
  prefix                 = var.prefix
  project_id             = var.project_id
  min_cpu_platform       = var.min_cpu_platform
  machine_type           = var.machine_type
  automatic_restart      = var.automatic_restart
  preemptible            = var.preemptible
  image                  = var.image
  disk_type              = var.disk_type
  disk_size_gb           = var.disk_size_gb
  mgmt_interface         = var.mgmt_interface
  external_interface     = var.external_interface
  internal_interfaces    = var.internal_interfaces
  labels                 = var.labels
  service_account        = var.service_account
  metadata               = var.metadata
  network_tags           = var.network_tags == null ? [random_id.cluster_tag.hex] : concat(var.network_tags, [random_id.cluster_tag.hex])
  runtime_init_config    = var.runtime_init_config
  runtime_init_installer = var.runtime_init_installer
}

locals {
  zones    = coalescelist(var.zones, random_shuffle.zones.result)
  vm_names = try(length(var.instances), 0) > 0 ? keys(var.instances) : [for i in range(0, var.num_instances) : format("%s-%02d", var.prefix, i + 1)]
  vms = { for i, name in local.vm_names : name => {
    zone = element(local.zones, i)
    metadata = merge({
      bigip_ha_peer_name    = local.vm_names[i == 0 ? 1 : 0]
      bigip_ha_peer_address = coalesce(try(var.instances[local.vm_names[i == 0 ? 1 : 0]].external.primary_ip, ""), try(google_compute_address.external[local.vm_names[i == 0 ? 1 : 0]].address, ""))
      # For the first instance bigip_ha_peer_owner_index will refer to the second instance in the group; for all others
      # it will always refer to the first instance in the group.
      bigip_ha_peer_owner_index = i == 0 ? "1" : "0"
    }, module.template.metadata, try(var.instances[name].metadata, {}))
    mgmt = {
      subnet               = data.google_compute_subnetwork.mgmt.self_link
      enable_public_ip     = try(var.mgmt_interface.public_ip, false)
      private_ip_primary   = coalesce(try(var.instances[name].mgmt.primary_ip, ""), try(google_compute_address.mgmt[name].address, ""))
      private_ip_secondary = compact(try(var.instances[name].mgmt.secondary_ips, []))
    }
    external = {
      subnet               = data.google_compute_subnetwork.external.self_link
      enable_public_ip     = try(var.external_interface.public_ip, false)
      private_ip_primary   = coalesce(try(var.instances[name].external.primary_ip, ""), try(google_compute_address.external[name].address, ""))
      private_ip_secondary = compact(try(var.instances[name].external.secondary_ips, []))
    }
    internals = var.internal_interfaces == null ? [] : [for j, interface in var.internal_interfaces : {
      subnet               = data.google_compute_subnetwork.internal["${j}"].self_link
      enable_public_ip     = try(interface.public_ip, false)
      private_ip_primary   = try(var.instances[name].internals[j].primary_ip, "")
      private_ip_secondary = compact(try(var.instances[name].internals[j].secondary_ips, []))
    }]
  } }
}

resource "google_compute_address" "mgmt" {
  for_each     = toset([for name in local.vm_names : name if try(var.instances[name].mgmt_primary_ip, "") == ""])
  name         = format("%s-mgmt", each.key)
  description  = format("Reserved control-plane address for BIG-IP instance %s", each.key)
  address_type = "INTERNAL"
  ip_version   = "IPV4"
  purpose      = "GCE_ENDPOINT"
  project      = var.project_id
  subnetwork   = data.google_compute_subnetwork.mgmt.id
  region       = data.google_compute_subnetwork.mgmt.region
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
  subnetwork   = data.google_compute_subnetwork.external.id
  region       = data.google_compute_subnetwork.external.region
  labels       = var.labels
}

resource "google_compute_instance_from_template" "bigip" {
  for_each                 = local.vms
  project                  = var.project_id
  name                     = each.key
  description              = format("%d-nic BIG-IP instance", 2 + try(length(var.internal_interfaces), 0))
  source_instance_template = module.template.id

  # Override with per-instance configuration
  zone     = each.value.zone
  metadata = each.value.metadata
  network_interface {
    subnetwork = each.value.external.subnet
    network_ip = each.value.external.private_ip_primary
    dynamic "access_config" {
      for_each = each.value.external.enable_public_ip ? ["1"] : []
      content {}
    }
    dynamic "alias_ip_range" {
      for_each = each.value.external.private_ip_secondary
      content {
        ip_cidr_range = alias_ip_range.value
      }
    }
  }
  network_interface {
    subnetwork = each.value.mgmt.subnet
    network_ip = each.value.mgmt.private_ip_primary
    dynamic "access_config" {
      for_each = each.value.mgmt.enable_public_ip ? ["1"] : []
      content {}
    }
    dynamic "alias_ip_range" {
      for_each = each.value.mgmt.private_ip_secondary
      content {
        ip_cidr_range = alias_ip_range.value
      }
    }
  }
  dynamic "network_interface" {
    for_each = each.value.internals
    content {
      subnetwork = network_interface.value.subnet
      network_ip = network_interface.value.private_ip_primary
      dynamic "access_config" {
        for_each = network_interface.value.enable_public_ip ? ["1"] : []
        content {}
      }
      dynamic "alias_ip_range" {
        for_each = network_interface.value.private_ip_secondary
        content {
          ip_cidr_range = alias_ip_range.value
        }
      }
    }
  }

  lifecycle {
    # When deploying with CFE, Alias IP may be moved between instances on failover; ignore these changes and rely on
    # CFE doing the right thing. This will require a manual intervention if the Alias IPs are changed.
    ignore_changes = [
      network_interface.0.alias_ip_range,
      network_interface.1.alias_ip_range,
      network_interface.2.alias_ip_range,
      network_interface.3.alias_ip_range,
      network_interface.4.alias_ip_range,
      network_interface.5.alias_ip_range,
      network_interface.6.alias_ip_range,
      network_interface.7.alias_ip_range,
    ]
  }

  depends_on = [
    google_compute_address.mgmt,
    google_compute_address.external,
    module.template,
  ]
}

# DSC requires BIG-IP instances to communicate via HTTPS management port on
# control-plane network.
resource "google_compute_firewall" "mgt_sync" {
  project     = data.google_compute_subnetwork.mgmt.project
  name        = format("%s-allow-dsc-mgmt", var.prefix)
  network     = data.google_compute_subnetwork.mgmt.network
  description = "BIG-IP ConfigSync for management network"
  direction   = "INGRESS"
  source_tags = [random_id.cluster_tag.hex]
  target_tags = [random_id.cluster_tag.hex]
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
  project     = data.google_compute_subnetwork.external.project
  name        = format("%s-allow-dsc-data", var.prefix)
  network     = data.google_compute_subnetwork.external.network
  description = "BIG-IP ConfigSync for data-plane network"
  direction   = "INGRESS"
  source_tags = [random_id.cluster_tag.hex]
  target_tags = [random_id.cluster_tag.hex]
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
