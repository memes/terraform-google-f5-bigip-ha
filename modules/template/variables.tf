variable "prefix" {
  type = string
  validation {
    # Instance template prefix is limited to 37 chars
    condition     = can(regex("^[a-z][a-z0-9-]{0,36}$", var.prefix))
    error_message = "The prefix variable must be RFC1035 compliant and between 1 and 37 characters in length."
  }
  description = <<-EOD
The prefix to use when naming resources managed by this module. Must be RFC1035
compliant and between 1 and 37 characters in length, inclusive.
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
  type        = bool
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

variable "metadata" {
  description = "Provide custom metadata values for BIG-IP instances"
  type        = map(string)
  default     = {}
}

variable "network_tags" {
  type        = list(string)
  default     = []
  description = "The network tags which will be added to the BIG-IP VMs."
}

variable "runtime_init_config" {
  type    = string
  default = null
}

variable "runtime_init_installer" {
  type = object({
    url       = string
    sha256sum = string
  })
  default = {
    url       = "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/1.5.2/f5-bigip-runtime-init-1.5.2-1.gz.run"
    sha256sum = "b9eea6a7b2627343553f47d18f4ebbb2604cec38a6e761ce4b79d518ac24b2d4"
  }
}
