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
  source                 = "..//template/"
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

resource "google_compute_health_check" "livez" {
  project             = var.project_id
  name                = format("%s-livez", var.prefix)
  check_interval_sec  = 60
  timeout_sec         = 2
  healthy_threshold   = 2
  unhealthy_threshold = 3
  http_health_check {
    port               = 26000
    request_path       = "/"
    response           = "OK"
    port_specification = "USE_FIXED_PORT"
  }
}

resource "google_compute_region_instance_group_manager" "mig" {
  project                          = var.project_id
  name                             = var.prefix
  description                      = format("%d-nic BIG-IP stateless group", 2 + try(length(var.internal_interfaces), 0))
  base_instance_name               = var.prefix
  region                           = data.google_compute_subnetwork.mgmt.region
  target_size                      = var.num_instances
  wait_for_instances               = false
  distribution_policy_zones        = try(length(var.zones), 0) > 0 ? var.zones : null
  distribution_policy_target_shape = "EVEN"

  version {
    name              = module.template.name
    instance_template = module.template.self_link
  }

  update_policy {
    type                           = "OPPORTUNISTIC"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    instance_redistribution_type   = "NONE"
    max_surge_fixed                = length(coalescelist(var.zones, random_shuffle.zones.result))
    max_unavailable_fixed          = 0
    replacement_method             = "SUBSTITUTE"
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.livez.id
    initial_delay_sec = 600
  }

  instance_lifecycle_policy {
    force_update_on_repair    = "YES"
    default_action_on_failure = "REPAIR"
  }

  lifecycle {
    ignore_changes = [
      target_size,
    ]
  }
}

# MIG health checks require access to BIG-IP external interface.
resource "google_compute_firewall" "livez" {
  project     = data.google_compute_subnetwork.external.project
  name        = format("%s-allow-livez", var.prefix)
  network     = data.google_compute_subnetwork.external.network
  description = "Allow liveness check for MIG"
  direction   = "INGRESS"
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]
  target_tags = [random_id.cluster_tag.hex]
  allow {
    protocol = "tcp"
    ports = [
      26000,
    ]
  }
}
