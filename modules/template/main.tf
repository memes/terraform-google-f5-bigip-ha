terraform {
  required_version = ">= 1.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
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

data "google_compute_image" "bigip" {
  project = try(regex("projects/([^/]+)/global/", var.image)[0], var.project_id)
  family  = try(regex("family/([^/]+)$", var.image)[0], null)
  name    = try(regex("images/([^/]+)$", var.image)[0], null)
}

locals {
  user_data = templatefile(format("%s/templates/cloud-config.yaml", path.module), {
    runtime_init_url       = try(var.runtime_init_installer.url, "")
    runtime_init_sha256sum = try(var.runtime_init_installer.sha256sum, "")
    runtime_init_installer_args = trimspace(join(" ", concat([
      "--cloud gcp",
      try(var.runtime_init_installer.skip_toolchain_metadata_sync, false) ? "--skip-toolchain-metadata-sync" : "",
      try(var.runtime_init_installer.skip_verify, false) ? "--skip-verify" : "",
      coalesce(try(var.runtime_init_installer.verify_gpg_key_url, "unspecified"), "unspecified") != "unspecified" ? format("--key %s", var.runtime_init_installer.verify_gpg_key_url) : "",
    ])))
    runtime_init_extra_args = trimspace(join(" ", concat([
      try(var.runtime_init_installer.skip_telemetry, false) ? "--skip-telemetry" : "",
    ])))
    runtime_init_config = var.runtime_init_config
  })
  metadata = var.metadata == null ? {
    user-data = local.user_data
    } : merge({
      user-data = local.user_data
  }, var.metadata)
  # Official published images have a common naming convention that can be used to infer the release
  inferred_version = element(coalescelist(regexall("/f5-bigip-((?:[0-9]{1,2}-){5,6}[0-9]+)-[^0-9].*$", data.google_compute_image.bigip.name), ["unknown-version"]), 0)
}


resource "google_compute_instance_template" "bigip" {
  project              = var.project_id
  name_prefix          = var.prefix
  description          = format("%d-nic BIG-IP instance template for %s", 2 + try(length(var.internal_interfaces), 0), local.inferred_version)
  instance_description = format("%d-nic BIG-IP instance", 2 + try(length(var.internal_interfaces), 0))
  region               = data.google_compute_subnetwork.mgmt.region
  labels               = var.labels
  metadata             = local.metadata
  disk {
    device_name  = "boot-disk"
    auto_delete  = true
    boot         = true
    source_image = data.google_compute_image.bigip.self_link
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb
    labels       = var.labels
  }

  can_ip_forward = true
  tags           = var.network_tags

  # External interface is on nic0
  network_interface {
    subnetwork = data.google_compute_subnetwork.external.self_link
    dynamic "access_config" {
      for_each = try(var.external_interface.public_ip, false) ? ["1"] : []
      content {}
    }
  }
  # Management interface is on nic1
  network_interface {
    subnetwork = data.google_compute_subnetwork.mgmt.self_link
    dynamic "access_config" {
      for_each = try(var.mgmt_interface.public_ip, false) ? ["1"] : []
      content {}
    }
  }
  # If there are internal interfaces, assign to nic2+
  dynamic "network_interface" {
    for_each = { for i, v in var.internal_interfaces == null ? [] : var.internal_interfaces : "${i}" => try(v.public_ip, false) }
    content {
      subnetwork = data.google_compute_subnetwork.internal[network_interface.key].self_link
      dynamic "access_config" {
        for_each = network_interface.value ? ["1"] : []
        content {}
      }
    }
  }

  machine_type     = var.machine_type
  min_cpu_platform = var.min_cpu_platform
  scheduling {
    automatic_restart   = var.automatic_restart
    on_host_maintenance = ""
    preemptible         = var.preemptible
  }

  service_account {
    email = var.service_account
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}
