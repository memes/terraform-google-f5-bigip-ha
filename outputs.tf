output "self_links" {
  value       = { for k, v in google_compute_instance_from_template.bigip : v.name => v.self_link }
  description = <<-EOD
A map of BIG-IP instance name to fully-qualified self-links.
EOD
}

output "names" {
  value       = [for k, v in google_compute_instance_from_template.bigip : v.name]
  description = <<-EOD
The instance names of the BIG-IPs.
EOD
}

output "mgmtPublicIPs" {
  value       = { for k, v in google_compute_instance_from_template.bigip : v.name => try(v.network_interface[1].access_config[0].nat_ip, "") }
  description = <<-EOD
A map of BIG-IP instance name to public IP address, if any, on the management interface.
EOD
}
