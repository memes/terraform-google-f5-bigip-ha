variable "num_instances" {
  type    = number
  default = 2
  validation {
    # An HA group requires between 2 and 8 BIG-IP instances, inclusive.
    condition     = floor(var.num_instances) == var.num_instances && var.num_instances > 1 && var.num_instances < 9
    error_message = "The num_instances variable must be an integer between 2 and 8, inclusive."
  }
  description = <<-EOD
  The number of BIG-IP instances to create as an HA group.
  EOD
}

variable "prefix" {
  type = string
  validation {
    # This module names BIG-IP instances as this value + "-0n", where n is the one-based index of the instance. E.g.
    # prefix-01, prefix-02,..., which means the maximum supported length for prefix is 60. Validate the prefix is
    # RFC1035 compliant with a maximum length of 60 alphanumeric and/or - characters.
    condition     = can(regex("^[a-z][a-z0-9-]{0,60}$", var.prefix))
    error_message = "The prefix variable must be RFC1035 compliant and between 1 and 60 characters in length."
  }
  description = <<-EOD
The prefix to use when naming resources managed by this module. Must be RFC1035
compliant and between 1 and 60 characters in length, inclusive.
EOD
}

variable "project_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "The project_id variable must must be 6 to 30 lowercase letters, digits, or hyphens; it must start with a letter and cannot end with a hyphen."
  }
  description = <<-EOD
The GCP project identifier where the BIG-IP HA pair will be created
EOD
}

variable "zones" {
  type = list(string)
  validation {
    condition     = length(var.zones) > 0 && alltrue([for zone in var.zones : can(regex("^[a-z]{2,20}-[a-z]{4,20}[0-9]-[a-z]$", zone))])
    error_message = "At least one zone must be specified, and each zone must be a valid GCE zone name."
  }
  description = <<-EOD
The compute zones where where the BIG-IP instances will be deployed. At least one
zone must be provided; if more than one zone is given, the instances will be
distributed among them.
EOD
}

variable "min_cpu_platform" {
  type        = string
  default     = "Intel Skylake"
  description = <<-EOD
An optional constraint used when scheduling the BIG-IP VMs; this value prevents
the VMs from being scheduled on hardware that doesn't meet the minimum CPU
micro-architecture. Default value is 'Intel Skylake'.
EOD
}

variable "machine_type" {
  type        = string
  default     = "n1-standard-8"
  description = <<-EOD
The machine type to use for BIG-IP VMs; this may be a standard GCE machine type,
or a customised VM ('custom-VCPUS-MEM_IN_MB'). Default value is 'n1-standard-8'.
*Note:* machine_type is highly-correlated with network bandwidth and performance;
an N2 machine type will give better performance but has limited regional availability.
EOD
}

variable "automatic_restart" {
  type        = bool
  default     = true
  description = <<EOD
Determines if the BIG-IP VMs should be automatically restarted if terminated by
GCE. Defaults to true to match expected GCE behaviour.
EOD
}

variable "preemptible" {
  type        = string
  default     = false
  description = <<EOD
If set to true, the BIG-IP instances will be deployed on preemptible VMs, which
could be terminated at any time, and have a maximum lifetime of 24 hours. Default
value is false. DO NOT SET TO TRUE UNLESS YOU UNDERSTAND THE RAMIFICATIONS!
EOD
}

variable "image" {
  type = string
  validation {
    condition     = can(regex("^(?:https://www.googleapis.com/compute/v1/)?projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/global/images/[a-z][a-z0-9-]{0,61}[a-z0-9]", var.image))
    error_message = "The image variable must be a fully-qualified URI."
  }
  default     = "projects/f5-7626-networks-public/global/images/f5-bigip-17-1-1-3-0-0-5-payg-good-1gbps-240321070835"
  description = <<-EOD
The self-link URI for a BIG-IP image to use as a base for the VM cluster. This
can be an official F5 image from GCP Marketplace, or a customised image.
EOD
}

variable "disk_type" {
  type    = string
  default = "pd-ssd"
  validation {
    condition     = contains(["pd-balanced", "pd-ssd", "pd-standard"], var.disk_type)
    error_message = "The disk_type variable must be one of 'pd-balanced', 'pd-ssd', or 'pd-standard'."
  }
  description = <<EOD
The boot disk type to use with instances; can be 'pd-balanced', 'pd-ssd' (default),
or 'pd-standard'.
EOD
}

variable "disk_size_gb" {
  type        = number
  default     = null
  description = <<EOD
Use this flag to set the boot volume size in GB. If left at the default value
the boot disk will have the same size as the base image.
EOD
}

variable "mgmt_interface" {
  type = object({
    subnet_id = string
    public_ip = bool
  })
  validation {
    condition     = can(regex("^(?:https://www\\.googleapis\\.com/compute/v1/)?projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/regions/[a-z][a-z-]+[0-9]/subnetworks/[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.mgmt_interface.subnet_id))
    error_message = "The mgmt_interface value must contain a fully-qualified subnet self-link."
  }
  description = <<EOD
Defines the subnetwork that will be attached to each instance's management interface (nic1), and a flag to assign a public
IP adddress to the management interface.
EOD
}

variable "external_interface" {
  type = object({
    subnet_id = string
    public_ip = bool
  })
  validation {
    condition     = can(regex("^(?:https://www\\.googleapis\\.com/compute/v1/)?projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/regions/[a-z][a-z-]+[0-9]/subnetworks/[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.external_interface.subnet_id))
    error_message = "The external_interface object must contain a fully-qualified subnet self-link."
  }
  description = <<-EOD
Defines the subnetwork that will be attached to each instance's external interface (nic0), and a flag to assign a public
IP adddress to the management interface.
EOD
}

variable "internal_interfaces" {
  type = list(object({
    subnet_id = string
    public_ip = bool
  }))
  validation {
    condition     = var.internal_interfaces == null ? true : length(var.internal_interfaces) <= 6 && alltrue([for interface in var.internal_interfaces : can(regex("^(?:https://www\\.googleapis\\.com/compute/v1/)?projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/regions/[a-z][a-z-]+[0-9]/subnetworks/[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", interface.subnet_id))])
    error_message = "Each internal_interfaces entry must contain a fully-qualified subnet self-link."
  }
  description = <<-EOD
An optional list of up to 6 subnetworks that will be attached to each instance's internal interfaces (nic2...nicN),
and flags to assign a public IP adddress to the internal interface.
EOD
}

variable "f5_username" {
  description = "The admin username of the F5 Bigip that will be deployed"
  default     = "bigipuser"
}

variable "f5_password" {
  description = "The admin password of the F5 Bigip that will be deployed"
  default     = ""
}

variable "onboard_log" {
  description = "Directory on the BIG-IP to store the cloud-init logs"
  default     = "/var/log/startup-script.log"
  type        = string
}

variable "libs_dir" {
  description = "Directory on the BIG-IP to download the A&O Toolchain into"
  default     = "/config/cloud/gcp/node_modules"
  type        = string
}

variable "gcp_secret_manager_authentication" {
  description = "Whether to use secret manager to pass authentication"
  type        = bool
  default     = false
}

variable "gcp_secret_name" {
  description = "The secret to get the secret version for"
  type        = string
  default     = ""
}

variable "gcp_secret_version" {
  description = "(Optional)The version of the secret to get. If it is not provided, the latest version is retrieved."
  type        = string
  default     = "latest"
}

## Please check and update the latest DO URL from https://github.com/F5Networks/f5-declarative-onboarding/releases
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "DO_URL" {
  description = "URL to download the BIG-IP Declarative Onboarding module"
  type        = string
  default     = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.42.0/f5-declarative-onboarding-1.42.0-9.noarch.rpm"
}

## Please check and update the latest AS3 URL from https://github.com/F5Networks/f5-appsvcs-extension/releases/latest
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "AS3_URL" {
  description = "URL to download the BIG-IP Application Service Extension 3 (AS3) module"
  type        = string
  default     = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.49.0/f5-appsvcs-3.49.0-6.noarch.rpm"
}

## Please check and update the latest TS URL from https://github.com/F5Networks/f5-telemetry-streaming/releases/latest
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "TS_URL" {
  description = "URL to download the BIG-IP Telemetry Streaming module"
  type        = string
  default     = "https://github.com/F5Networks/f5-telemetry-streaming/releases/download/v1.34.0/f5-telemetry-1.34.0-1.noarch.rpm"
}

## Please check and update the latest Failover Extension URL from https://github.com/f5devcentral/f5-cloud-failover-extension/releases/latest
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "CFE_URL" {
  description = "URL to download the BIG-IP Cloud Failover Extension module"
  type        = string
  default     = "https://github.com/F5Networks/f5-cloud-failover-extension/releases/download/v2.0.2/f5-cloud-failover-2.0.2-2.noarch.rpm"
}

## Please check and update the latest FAST URL from https://github.com/F5Networks/f5-appsvcs-templates/releases/latest
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "FAST_URL" {
  description = "URL to download the BIG-IP FAST module"
  type        = string
  default     = "https://github.com/F5Networks/f5-appsvcs-templates/releases/download/v1.25.0/f5-appsvcs-templates-1.25.0-1.noarch.rpm"
}

## Please check and update the latest runtime init URL from https://github.com/F5Networks/f5-bigip-runtime-init/releases/latest
# always point to a specific version in order to avoid inadvertent configuration inconsistency
variable "INIT_URL" {
  description = "URL to download the BIG-IP runtime init"
  type        = string
  default     = "https://cdn.f5.com/product/cloudsolutions/f5-bigip-runtime-init/v2.0.1/dist/f5-bigip-runtime-init-2.0.1-1.gz.run"
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = <<EOD
An optional map of string key:value pairs that will be applied to all resources
created that accept labels. Default is an empty map.
EOD
}

variable "service_account" {
  type = string
  validation {
    condition     = can(regex("^(?:[a-z][a-z0-9-]{4,28}[a-z0-9]@[a-z][a-z0-9-]{4,28}[a-z0-9]\\.iam|[0-9]+-compute@developer)\\.gserviceaccount\\.com$", var.service_account))
    error_message = "The service_account variable must be a valid GCP service account email address."
  }
  description = <<-EOD
The email address of the service account which will be used for BIG-IP instances.
EOD
}

variable "f5_ssh_publickey" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = <<-EOD
The path to the SSH public key to install on BIG-IP instances for admin access.
EOD
}

variable "custom_user_data" {
  type        = string
  default     = null
  description = <<-EOD
Override the onboarding BASH script used by F5Networks/terraform-gcp-bigip-module.
EOD
}

variable "metadata" {
  description = "Provide custom metadata values for BIG-IP instance"
  type        = map(string)
  default     = {}
}

variable "sleep_time" {
  type        = string
  default     = "300s"
  description = "The number of seconds/minutes of delay to build into creation of BIG-IP VMs; default is 250. BIG-IP requires a few minutes to complete the onboarding process and this value can be used to delay the processing of dependent Terraform resources."
}

variable "network_tags" {
  type        = list(string)
  default     = []
  description = "The network tags which will be added to the BIG-IP VMs."
}

variable "instances" {
  type = map(object({
    metadata = map(string)
    external = object({
      primary_ip   = string
      secondary_ip = string
    })
    mgmt = object({
      primary_ip = string
      # TODO @memes - upstream doesn't support assigning Alias IPs on control-plane
      # secondary_ip = string
    })
    internals = list(object({
      primary_ip = string
      # TODO @memes - upstream doesn't support assigning Alias IPs on 'internal' interfaces
      # secondary_ip = string
    }))
  }))
  default = null
  validation {
    condition     = var.instances == null ? true : alltrue([for k, v in var.instances : can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", k)) && (v == null ? true : (v.external == null ? true : (v.metadata == null ? true : alltrue([for k, v in v.metadata : can(regex("^[a-zA-Z0-9-_]{1,127}$", k))])) && (coalesce(v.external.primary_ip, "unspecified") == "unspecified" || can(cidrhost(v.external.primary_ip, 0))) && (coalesce(v.external.secondary_ip, "unspecified") == "unspecified" || can(cidrhost(v.external.secondary_ip, 0)))) && (v.mgmt == null ? true : (coalesce(v.mgmt.primary_ip, "unspecified") == "unspecified" || can(cidrhost(v.mgmt.primary_ip, 0))) /* TODO @memes && (coalesce(v.mgmt.secondary_ip, "unspecified") == "unspecified" || can(cidrhost(v.mgmt.secondary_ip, 0)))*/) && (v.internals == null ? true : alltrue([for entry in v.internals : (coalesce(entry.primary_ip, "unspecified") == "unspecified" || can(cidrhost(entry.primary_ip, 0))) /* TODO @memes && (coalesce(entry.secondary_ip, "unspecified") == "unspecified" || can(cidrhost(entry.secondary_ip, 0)))*/])))])
    error_message = "Each interfaces entry key must be an RFC1035 compliant VM name, and valid or empty IP addresses for each entry."
  }
  description = <<-EOD
An optional list of up to 6 subnetworks that will be attached to each instance's internal interfaces (nic2...nicN),
a flag to assign a public IP adddress to the internal interface, and an optional list of IP addresses. If the list of IP
addresses is not empty, the values will be assigned to the interface as a primary address, one address per interface per
provisioned VM.
  EOD
}
