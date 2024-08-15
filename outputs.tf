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

output "public_mgmt_ips" {
  value       = { for k, v in google_compute_instance_from_template.bigip : v.name => try(v.network_interface[1].access_config[0].nat_ip, "") }
  description = <<-EOD
A map of BIG-IP instance name to public IP address, if any, on the management interface.
EOD
}

output "private_mgmt_ips" {
  value       = { for k, v in google_compute_instance_from_template.bigip : v.name => v.network_interface[1].network_ip }
  description = <<-EOD
A map of BIG-IP instance name to private IP address on the management interface.
EOD
}

output "instances_by_zone" {
  value       = { for k, v in google_compute_instance_from_template.bigip : v.zone => v.self_link... }
  description = <<-EOD
  A map of Compute Engine zones to a list of instance self-links.
  EOD
}

output "cluster_tag" {
  value       = random_id.cluster_tag.hex
  description = <<-EOD
  The pseudo-random network tag generated to uniquely identify the instances in this HA cluster.
  EOD
}
