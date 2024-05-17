# BIG-IP HA on Google Cloud

![GitHub release](https://img.shields.io/github/v/release/f5devcentral/terraform-google-f5-bigip-ha?sort=semver)
![Maintenance](https://img.shields.io/maintenance/yes/2024)
[![Contributor Covenant](https://img.shields.io/badge/Code_of_conduct-Yes-4baaaa.svg)](code_of_conduct.md)

> NOTE: This module is pre-release and functionality can change abruptly prior to v1.0 release. Be sure to pin to an
> exact version to avoid unintentional breakage due to updates.

This Terraform module creates Google Cloud infrastructure for an *opinionated regional or zonal cluster* of F5 BIG-IP
VE instances, that are **ready to be joined as a failover sync group** - the actual joining of the instances as a group
relies on manual post-deployment configuration OR the use of a full declarative onboarding payload appropriate to your
scenario. See the [examples](examples/) for details.

## What makes the module opinionated, and why might it be wrong for me?

This module is a wrapper for F5's published [BIG-IP on Google Cloud Terraform module][upstream]. Except
where called out below, the module exposes the same set of inputs and default values, where appropriate, as those present
in the standalone F5 BIG-IP module.

1. Virtual machine naming

   > OPINION: VM names should be deterministic to ease onboarding of a DSC cluster through runtime-init.

   The module provides a `num_instances` input to create between 2 and 8 instances with consistent names of the form
   *PREFIX-bigip-N*, where *PREFIX* is the value of `prefix` input variable and *N* is the one-based index of the VM in
   the cluster.

   This behavior can be modified through the `instances` variable.

2. Subnetwork and IP addressing

   > OPINION: Subnetworks used and addressing flags should be consistent on all created instances, and the cluster should
   > be *regional* or *zonal*.

   The [F5][upstream] Terraform module inputs `mgmt_subnet_ids`, `external_subnet_ids`, and `internal_subnet_ids`
   take a list of subnetwork identifiers, flags, and optional IP addresses to assign to the instances; while this
   provides support for exotic deployments and consistency with F5's modules for AWS and Azure, it has the potential to
   break naive deployments to Google Cloud. Almost all F5 and third-party published onboarding scripts assume/force
   management interface to nic1 if the VM has more than one interface; this will brick deployments if
   `external_subnet_ids` contains more than one entry, or if it is empty and `internal_subnet_ids` contains one or more
   values.

   Additionally, each VM in the cluster should be attached to the same subnets, and have the same basic configuration
   for public IP flag. This also forces the cluster to be contained in the same Compute Engine *region*, since subnetworks
   are regional on Google Cloud.

   For these reasons this module hides those inputs, preferring to expose the inputs `mgmt_interface`, and
   `external_interface`, which defines the subnetwork and public IP flag to use for the *management* (nic1) and
   *external* (nic0) interfaces respectively on every created instance. These input variables are required and must be
   provided. Similarly, `internal_interfaces` defines an optional **list** of subnetwork sand public IP flags to use for
   *internal* (nic2+) interfaces on every created instance. If specified, `internal_interfaces` can contain a maximum of
   6 subnetwork entries.

   Per-instance IP addressing can be handled using the `instances` variable.

3. Metadata - provide cluster onboarding information as instance metadata values

   > OPINION: Enable declarative onboarding for arbitrary clusters with sync group members without relying on prior
   > knowledge of primary IP addresses.

   Provisioning a fully-functional and ready to use HA cluster can be a challenge when IP addresses or names assigned to
   BIG-IP instances are not known in advance. To help in this scenario this module will add Compute Engine metadata
   entries named `BIG_IP_HA_PEER_NAME`, `BIG_IP_HA_PEER_IP` to each instance which contains the BIG-IP VE name and
   primary IP address of the external interface of another instance provisioned by the module.
   `BIG_IP_HA_PEER_OWNER_INDEX` will have the fixed value *1* for the first BIG-IP VE provisioned, all others will have
   the fixed value *0*; this can be used in a Declarative Onboarding failover group definition to indicate if a BIG-IP VE
   is the initial failover group owner.

   **NOTE:** The effective metadata value assigned to each BIG-IP VE is the result of merging the defined values above,
   the `metadata` input variable if not null or empty, and any per-instance metadata from `instances` input variable.

4. Overriding per-instance defaults

   > OPINION: Consumers of the module should be able to customize VM names, assign primary and secondary IP addresses,
   > and metadata to named instances.

   The `instances` input allows module consumers to set specific names to use for VMs, assign primary and secondary IP
   addresses, and add metadata to BIG-IP VMs on a per-instance basis. The input is a Terraform map where each key will
   be the name of an instance, and optional

   > **NOTE:** The `instances` variable has precedence over `prefix` and `num_instances`; if `instances` is provided and
   > not null or empty, a VM will be created for each key in `instances`, ignoring the value of `prefix` and
   `num_instances`.

## Details

<!-- markdownlint-disable no-inline-html no-bare-urls -->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_instances"></a> [instances](#module\_instances) | F5Networks/bigip-module/gcp | 1.1.19 |

## Resources

| Name | Type |
|------|------|
| [google_compute_address.external](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_address.mgmt](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.data_sync](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.mgt_sync](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_subnetwork.dsc_data](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_subnetwork.dsc_mgmt](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_external_interface"></a> [external\_interface](#input\_external\_interface) | Defines the subnetwork that will be attached to each instance's external interface (nic0), and a flag to assign a public<br>IP adddress to the management interface. | <pre>object({<br>    subnet_id = string<br>    public_ip = bool<br>  })</pre> | n/a | yes |
| <a name="input_internal_interfaces"></a> [internal\_interfaces](#input\_internal\_interfaces) | An optional list of up to 6 subnetworks that will be attached to each instance's internal interfaces (nic2...nicN),<br>and flags to assign a public IP adddress to the internal interface. | <pre>list(object({<br>    subnet_id = string<br>    public_ip = bool<br>  }))</pre> | n/a | yes |
| <a name="input_mgmt_interface"></a> [mgmt\_interface](#input\_mgmt\_interface) | Defines the subnetwork that will be attached to each instance's management interface (nic1), and a flag to assign a public<br>IP adddress to the management interface. | <pre>object({<br>    subnet_id = string<br>    public_ip = bool<br>  })</pre> | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | The prefix to use when naming resources managed by this module. Must be RFC1035<br>compliant and between 1 and 60 characters in length, inclusive. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project identifier where the BIG-IP HA pair will be created | `string` | n/a | yes |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | The email address of the service account which will be used for BIG-IP instances. | `string` | n/a | yes |
| <a name="input_zones"></a> [zones](#input\_zones) | The compute zones where where the BIG-IP instances will be deployed. At least one<br>zone must be provided; if more than one zone is given, the instances will be<br>distributed among them. | `list(string)` | n/a | yes |
| <a name="input_AS3_URL"></a> [AS3\_URL](#input\_AS3\_URL) | URL to download the BIG-IP Application Service Extension 3 (AS3) module | `string` | `"https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.49.0/f5-appsvcs-3.49.0-6.noarch.rpm"` | no |
| <a name="input_CFE_URL"></a> [CFE\_URL](#input\_CFE\_URL) | URL to download the BIG-IP Cloud Failover Extension module | `string` | `"https://github.com/F5Networks/f5-cloud-failover-extension/releases/download/v2.0.2/f5-cloud-failover-2.0.2-2.noarch.rpm"` | no |
| <a name="input_DO_URL"></a> [DO\_URL](#input\_DO\_URL) | URL to download the BIG-IP Declarative Onboarding module | `string` | `"https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.42.0/f5-declarative-onboarding-1.42.0-9.noarch.rpm"` | no |
| <a name="input_FAST_URL"></a> [FAST\_URL](#input\_FAST\_URL) | URL to download the BIG-IP FAST module | `string` | `"https://github.com/F5Networks/f5-appsvcs-templates/releases/download/v1.25.0/f5-appsvcs-templates-1.25.0-1.noarch.rpm"` | no |
| <a name="input_INIT_URL"></a> [INIT\_URL](#input\_INIT\_URL) | URL to download the BIG-IP runtime init | `string` | `"https://cdn.f5.com/product/cloudsolutions/f5-bigip-runtime-init/v2.0.1/dist/f5-bigip-runtime-init-2.0.1-1.gz.run"` | no |
| <a name="input_TS_URL"></a> [TS\_URL](#input\_TS\_URL) | URL to download the BIG-IP Telemetry Streaming module | `string` | `"https://github.com/F5Networks/f5-telemetry-streaming/releases/download/v1.34.0/f5-telemetry-1.34.0-1.noarch.rpm"` | no |
| <a name="input_automatic_restart"></a> [automatic\_restart](#input\_automatic\_restart) | Determines if the BIG-IP VMs should be automatically restarted if terminated by<br>GCE. Defaults to true to match expected GCE behaviour. | `bool` | `true` | no |
| <a name="input_custom_user_data"></a> [custom\_user\_data](#input\_custom\_user\_data) | Override the onboarding BASH script used by F5Networks/terraform-gcp-bigip-module. | `string` | `null` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Use this flag to set the boot volume size in GB. If left at the default value<br>the boot disk will have the same size as the base image. | `number` | `null` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | The boot disk type to use with instances; can be 'pd-balanced', 'pd-ssd' (default),<br>or 'pd-standard'. | `string` | `"pd-ssd"` | no |
| <a name="input_f5_password"></a> [f5\_password](#input\_f5\_password) | The admin password of the F5 Bigip that will be deployed | `string` | `""` | no |
| <a name="input_f5_ssh_publickey"></a> [f5\_ssh\_publickey](#input\_f5\_ssh\_publickey) | The path to the SSH public key to install on BIG-IP instances for admin access. | `string` | `"~/.ssh/id_rsa.pub"` | no |
| <a name="input_f5_username"></a> [f5\_username](#input\_f5\_username) | The admin username of the F5 Bigip that will be deployed | `string` | `"bigipuser"` | no |
| <a name="input_gcp_secret_manager_authentication"></a> [gcp\_secret\_manager\_authentication](#input\_gcp\_secret\_manager\_authentication) | Whether to use secret manager to pass authentication | `bool` | `false` | no |
| <a name="input_gcp_secret_name"></a> [gcp\_secret\_name](#input\_gcp\_secret\_name) | The secret to get the secret version for | `string` | `""` | no |
| <a name="input_gcp_secret_version"></a> [gcp\_secret\_version](#input\_gcp\_secret\_version) | (Optional)The version of the secret to get. If it is not provided, the latest version is retrieved. | `string` | `"latest"` | no |
| <a name="input_image"></a> [image](#input\_image) | The self-link URI for a BIG-IP image to use as a base for the VM cluster. This<br>can be an official F5 image from GCP Marketplace, or a customised image. | `string` | `"projects/f5-7626-networks-public/global/images/f5-bigip-17-1-1-3-0-0-5-payg-good-1gbps-240321070835"` | no |
| <a name="input_instances"></a> [instances](#input\_instances) | An optional list of up to 6 subnetworks that will be attached to each instance's internal interfaces (nic2...nicN),<br>a flag to assign a public IP adddress to the internal interface, and an optional list of IP addresses. If the list of IP<br>addresses is not empty, the values will be assigned to the interface as a primary address, one address per interface per<br>provisioned VM. | <pre>map(object({<br>    metadata = map(string)<br>    external = object({<br>      primary_ip   = string<br>      secondary_ip = string<br>    })<br>    mgmt = object({<br>      primary_ip = string<br>      # TODO @memes - upstream doesn't support assigning Alias IPs on control-plane<br>      # secondary_ip = string<br>    })<br>    internals = list(object({<br>      primary_ip = string<br>      # TODO @memes - upstream doesn't support assigning Alias IPs on 'internal' interfaces<br>      # secondary_ip = string<br>    }))<br>  }))</pre> | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of string key:value pairs that will be applied to all resources<br>created that accept labels. Default is an empty map. | `map(string)` | `{}` | no |
| <a name="input_libs_dir"></a> [libs\_dir](#input\_libs\_dir) | Directory on the BIG-IP to download the A&O Toolchain into | `string` | `"/config/cloud/gcp/node_modules"` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type to use for BIG-IP VMs; this may be a standard GCE machine type,<br>or a customised VM ('custom-VCPUS-MEM\_IN\_MB'). Default value is 'n1-standard-8'.<br>*Note:* machine\_type is highly-correlated with network bandwidth and performance;<br>an N2 machine type will give better performance but has limited regional availability. | `string` | `"n1-standard-8"` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Provide custom metadata values for BIG-IP instance | `map(string)` | `{}` | no |
| <a name="input_min_cpu_platform"></a> [min\_cpu\_platform](#input\_min\_cpu\_platform) | An optional constraint used when scheduling the BIG-IP VMs; this value prevents<br>the VMs from being scheduled on hardware that doesn't meet the minimum CPU<br>micro-architecture. Default value is 'Intel Skylake'. | `string` | `"Intel Skylake"` | no |
| <a name="input_network_tags"></a> [network\_tags](#input\_network\_tags) | The network tags which will be added to the BIG-IP VMs. | `list(string)` | `[]` | no |
| <a name="input_num_instances"></a> [num\_instances](#input\_num\_instances) | The number of BIG-IP instances to create as an HA group. | `number` | `2` | no |
| <a name="input_onboard_log"></a> [onboard\_log](#input\_onboard\_log) | Directory on the BIG-IP to store the cloud-init logs | `string` | `"/var/log/startup-script.log"` | no |
| <a name="input_preemptible"></a> [preemptible](#input\_preemptible) | If set to true, the BIG-IP instances will be deployed on preemptible VMs, which<br>could be terminated at any time, and have a maximum lifetime of 24 hours. Default<br>value is false. DO NOT SET TO TRUE UNLESS YOU UNDERSTAND THE RAMIFICATIONS! | `string` | `false` | no |
| <a name="input_sleep_time"></a> [sleep\_time](#input\_sleep\_time) | The number of seconds/minutes of delay to build into creation of BIG-IP VMs; default is 250. BIG-IP requires a few minutes to complete the onboarding process and this value can be used to delay the processing of dependent Terraform resources. | `string` | `"300s"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_mgmtPublicIPs"></a> [mgmtPublicIPs](#output\_mgmtPublicIPs) | A map of BIG-IP instance name to public IP address, if any, on the management interface. |
| <a name="output_names"></a> [names](#output\_names) | The instance names of the BIG-IPs. |
| <a name="output_self_links"></a> [self\_links](#output\_self\_links) | A map of BIG-IP instance name to fully-qualified self-links. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- markdownlint-enable no-inline-html no-bare-urls -->

[upstream]: https://registry.terraform.io/modules/F5Networks/bigip-module/gcp/1.1.19
