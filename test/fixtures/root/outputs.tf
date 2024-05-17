#
# Module under test outputs
#
output "self_links" {
  value = module.test.self_links
}

# output "target_groups" {
#   value = module.test.target_groups
# }

# output "target_instances" {
#   value = module.test.target_instances
# }

output "names" {
  value = module.test.names
}

#
# Fixture outputs expected by Inspec
#
output "prefix" {
  value = var.prefix
}

output "project_id" {
  value = var.project_id
}

output "zones" {
  value = var.zones
}

output "service_account" {
  value = var.service_account
}

output "gcp_secret_name" {
  value = var.gcp_secret_name
}

output "f5_username" {
  value = var.f5_username
}

output "f5_password" {
  value = var.f5_password
}

output "f5_ssh_publickey" {
  value = var.f5_ssh_publickey
}

output "labels" {
  value = var.labels
}

output "bigip_addresses" {
  value = [for k, v in module.test.mgmtPublicIPs : v]
}

output "bigip_address_0" {
  value = sort([for k, v in module.test.mgmtPublicIPs : v])[0]
}

output "bigip_address_1" {
  value = sort([for k, v in module.test.mgmtPublicIPs : v])[1]
}

output "mgmt_interface_json" {
  value = jsonencode(var.mgmt_interface)
}

output "external_interface_json" {
  value = jsonencode(var.external_interface)
}

output "internal_interfaces_json" {
  value = jsonencode(var.internal_interfaces)
}

output "instances_json" {
  value = jsonencode(var.instances)
}
