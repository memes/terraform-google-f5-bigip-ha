variable "num_instances" {
  type    = number
  default = 2
}

variable "prefix" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zones" {
  type = set(string)
}

variable "min_cpu_platform" {
  type    = string
  default = "Intel Skylake"
}

variable "machine_type" {
  type = string
}

variable "automatic_restart" {
  type    = bool
  default = true
}

variable "preemptible" {
  type    = string
  default = false
}

variable "image" {
  type    = string
  default = "projects/f5-7626-networks-public/global/images/f5-bigip-17-1-1-3-0-0-5-payg-good-1gbps-240321070835"
}

variable "disk_type" {
  type    = string
  default = "pd-ssd"
}

variable "disk_size_gb" {
  type    = number
  default = null
}

variable "mgmt_interface" {
  type = object({
    subnet_id = string
    public_ip = bool
  })
}

variable "external_interface" {
  type = object({
    subnet_id = string
    public_ip = bool
  })
}

variable "internal_interfaces" {
  type = list(object({
    subnet_id = string
    public_ip = bool
  }))
}

variable "f5_username" {
  default = "bigipuser"
}

variable "f5_password" {
  default = ""
}

variable "onboard_log" {
  default = "/var/log/startup-script.log"
  type    = string
}

variable "libs_dir" {
  default = "/config/cloud/gcp/node_modules"
  type    = string
}

variable "gcp_secret_manager_authentication" {
  type    = bool
  default = false
}

variable "gcp_secret_name" {
  type    = string
  default = ""
}

variable "gcp_secret_version" {
  type    = string
  default = "latest"
}

variable "DO_URL" {
  type    = string
  default = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.42.0/f5-declarative-onboarding-1.42.0-9.noarch.rpm"
}

variable "AS3_URL" {
  type    = string
  default = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.49.0/f5-appsvcs-3.49.0-6.noarch.rpm"
}

variable "TS_URL" {
  type    = string
  default = "https://github.com/F5Networks/f5-telemetry-streaming/releases/download/v1.34.0/f5-telemetry-1.34.0-1.noarch.rpm"
}

variable "CFE_URL" {
  type    = string
  default = "https://github.com/F5Networks/f5-cloud-failover-extension/releases/download/v2.0.2/f5-cloud-failover-2.0.2-2.noarch.rpm"
}

variable "FAST_URL" {
  type    = string
  default = "https://github.com/F5Networks/f5-appsvcs-templates/releases/download/v1.25.0/f5-appsvcs-templates-1.25.0-1.noarch.rpm"
}

variable "INIT_URL" {
  type    = string
  default = "https://cdn.f5.com/product/cloudsolutions/f5-bigip-runtime-init/v2.0.1/dist/f5-bigip-runtime-init-2.0.1-1.gz.run"
}

variable "labels" {
  type = map(string)
}

variable "service_account" {
  type = string
}

variable "f5_ssh_publickey" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "custom_user_data" {
  type    = string
  default = null
}

variable "metadata" {
  type    = map(string)
  default = {}
}

variable "sleep_time" {
  type    = string
  default = "300s"
}

variable "network_tags" {
  type    = list(string)
  default = []
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
}
