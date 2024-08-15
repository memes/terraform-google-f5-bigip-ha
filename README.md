# BIG-IP HA on Google Cloud

![GitHub release](https://img.shields.io/github/v/release/f5devcentral/terraform-google-f5-bigip-ha?sort=semver)
![Maintenance](https://img.shields.io/maintenance/yes/2024)
[![Contributor Covenant](https://img.shields.io/badge/Code_of_conduct-Yes-4baaaa.svg)](code_of_conduct.md)

> NOTE: This module is pre-release and functionality can change abruptly prior to v1.0 release. Be sure to pin to an
> exact version to avoid unintentional breakage due to updates.

This Terraform module creates Google Cloud infrastructure for an *opinionated, stateful, regional or zonal cluster* of
F5 BIG-IP VE instances, that are **ready to be joined as a sync group** - the actual joining of the instances
as a group relies on manual post-deployment configuration OR the use of a full declarative onboarding payload appropriate
to your scenario.

> For the purpose of this module, *stateful* is taken to mean that each BIG-IP VE instance knows the names and addresses
> of other instances in the cluster, and configuration is shared between the instances to create an Active-Standby (one
> instance handles all traffic) or Active-Active (all instances could handle traffic) HA deployment.
>
> The [stateless](modules/stateless) sub-module can be used to create an Active-Active HA cluster of BIG-IP VE instances
> that do not share configuration and does not rely on consistent naming and addressing.

## What makes the module opinionated, and why might it be wrong for me?

F5's published [BIG-IP on Google Cloud Terraform module][upstream] can be used to create a set of VE instances that can
be joined into a device sync group when combined with additional effort/configuration, but it has defaults that can make
it harder to create a group during instantiation. This module makes the following choices to ease creation and management
of a stateful HA cluster.

1. Virtual machine naming

   > OPINION: VM names should be deterministic to ease onboarding of a DSC cluster through runtime-init.

   The module provides a `num_instances` input to create between 2 and 8 instances with consistent names of the form
   *PREFIX-bigip-N*, where *PREFIX* is the value of `prefix` input variable and *N* is the one-based index of the VM in
   the cluster.

   The `instances` variable can be used instead to set the name of every instance explicitly.

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

   For these reasons this module eschews that approach, preferring to expose the inputs `mgmt_interface`, and
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
   entries named `big_ip_ha_peer_name`, `big_ip_ha_peer_address` to each instance which contains the BIG-IP VE name and
   primary IP address of the external interface of another instance provisioned by the module.
   `big_ip_ha_peer_owner_index` will have the fixed value *1* for the first BIG-IP VE provisioned, all others will have
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

5. Module responsibility for onboarding stops at runtime-init

   > OPINION: Consumers of the module must provide a runtime-init configuration to set passwords, enable data-plane, and
   > add applications, etc.

   There are simply too many configuration options and deployment scenarios to have a one-size-fits-all module suitable
   for every situation. This module will provide a cloud-init file through `user-data` metadata value that will configure
   the management interface (nic1) of every instance from Compute Engine metadata, attempt to download and install
   runtime-init, then execute a provided configuration file.

   If a runtime-init configuration file is not provided the instances will not be fully configured; the admin user
   password will be unknown, device sync will not be setup, etc.

<!-- markdownlint-disable no-inline-html no-bare-urls -->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_template"></a> [template](#module\_template) | ./modules/template/ | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_address.external](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_address.mgmt](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.data_sync](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.mgt_sync](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance_from_template.bigip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_from_template) | resource |
| [random_id.cluster_tag](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_shuffle.zones](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/shuffle) | resource |
| [google_compute_subnetwork.external](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_subnetwork.internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_subnetwork.mgmt](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_zones.zones](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_external_interface"></a> [external\_interface](#input\_external\_interface) | Defines the subnetwork that will be attached to each instance's external interface (nic0), and a flag to assign a public<br>IP address to the management interface. | <pre>object({<br>    subnet_id = string<br>    public_ip = bool<br>  })</pre> | n/a | yes |
| <a name="input_internal_interfaces"></a> [internal\_interfaces](#input\_internal\_interfaces) | An optional list of up to 6 subnetworks that will be attached to each instance's internal interfaces (nic2...nicN),<br>and flags to assign a public IP address to the internal interface. | <pre>list(object({<br>    subnet_id = string<br>    public_ip = bool<br>  }))</pre> | n/a | yes |
| <a name="input_mgmt_interface"></a> [mgmt\_interface](#input\_mgmt\_interface) | Defines the subnetwork that will be attached to each instance's management interface (nic1), and a flag to assign a public<br>IP address to the management interface. | <pre>object({<br>    subnet_id = string<br>    public_ip = bool<br>  })</pre> | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | The prefix to use when naming resources managed by this module. Must be RFC1035<br>compliant and between 1 and 37 characters in length, inclusive. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project identifier where the BIG-IP HA pair will be created | `string` | n/a | yes |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | The email address of the service account which will be used for BIG-IP instances. | `string` | n/a | yes |
| <a name="input_automatic_restart"></a> [automatic\_restart](#input\_automatic\_restart) | Determines if the BIG-IP VMs should be automatically restarted if terminated by<br>GCE. Defaults to true to match expected Compute Engine behaviour. | `bool` | `true` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Use this flag to set the boot volume size in GB; the default value is 100. | `number` | `100` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | The boot disk type to use with instances; can be 'pd-balanced', 'pd-ssd' (default),<br>or 'pd-standard'. | `string` | `"pd-ssd"` | no |
| <a name="input_image"></a> [image](#input\_image) | The self-link URI for a BIG-IP image to use as a base for the VM cluster. This can be an official F5 image from GCP<br>Marketplace, or a customised image. | `string` | `"projects/f5-7626-networks-public/global/images/f5-bigip-17-1-1-3-0-0-5-payg-good-1gbps-240321070835"` | no |
| <a name="input_instances"></a> [instances](#input\_instances) | An optional map of instances names that will be used to override num\_instances and common parameters. When creating BIG-IP<br>instances the names will correspond to the keys in `instances` variable, and each instance named will receive the primary<br>and/or Alias IPs associated with the instance. | <pre>map(object({<br>    metadata = map(string)<br>    external = object({<br>      primary_ip    = string<br>      secondary_ips = list(string)<br>    })<br>    mgmt = object({<br>      primary_ip    = string<br>      secondary_ips = list(string)<br>    })<br>    internals = list(object({<br>      primary_ip    = string<br>      secondary_ips = list(string)<br>    }))<br>  }))</pre> | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of string key:value pairs that will be applied to all resources created that accept labels. Default is<br>an empty map. | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type to use for BIG-IP VMs; this may be a standard GCE machine type,<br>or a customised VM ('custom-VCPUS-MEM\_IN\_MB'). Default value is 'n1-standard-8'.<br>\_NOTE:\_ machine\_type is highly-correlated with network bandwidth and performance;<br>an N2 machine type will give better performance but has limited regional availability. | `string` | `"n1-standard-8"` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | An optional set of metadata values to add to all BIG-IP instances. Can be used to override the onboarding script. | `map(string)` | `{}` | no |
| <a name="input_min_cpu_platform"></a> [min\_cpu\_platform](#input\_min\_cpu\_platform) | An optional constraint used when scheduling the BIG-IP VMs; this value prevents<br>the VMs from being scheduled on hardware that doesn't meet the minimum CPU<br>micro-architecture. Default value is 'Intel Skylake'. | `string` | `"Intel Skylake"` | no |
| <a name="input_network_tags"></a> [network\_tags](#input\_network\_tags) | The network tags which will be added to the BIG-IP VMs. | `list(string)` | `[]` | no |
| <a name="input_num_instances"></a> [num\_instances](#input\_num\_instances) | The number of BIG-IP instances to create as an HA group. | `number` | `2` | no |
| <a name="input_preemptible"></a> [preemptible](#input\_preemptible) | If set to true, the BIG-IP instances will be deployed on preemptible VMs, which<br>could be terminated at any time, and have a maximum lifetime of 24 hours. Default<br>value is false. DO NOT SET TO TRUE UNLESS YOU UNDERSTAND THE RAMIFICATIONS! | `bool` | `false` | no |
| <a name="input_runtime_init_config"></a> [runtime\_init\_config](#input\_runtime\_init\_config) | A runtime-init YAML configuration that will be executed during initialisation. If omitted, the BIG-IP instances will<br>be largely unconfigured, with only the management interface accessible. | `string` | `null` | no |
| <a name="input_runtime_init_installer"></a> [runtime\_init\_installer](#input\_runtime\_init\_installer) | Defines the location of the runtime-init package to install, and an optional SHA256 checksum. During initialisation,<br>the runtime-init installer will be downloaded from this location - which can be an http/https/gs/file/ftp URL - and<br>verified against the provided checksum, if provided. Additional flags can change the behaviour of runtime-init when used<br>in restricted environments (see https://github.com/F5Networks/f5-bigip-runtime-init?tab=readme-ov-file#private-environments). | <pre>object({<br>    url                          = string<br>    sha256sum                    = string<br>    skip_telemetry               = bool<br>    skip_toolchain_metadata_sync = bool<br>    skip_verify                  = bool<br>    verify_gpg_key_url           = string<br>  })</pre> | <pre>{<br>  "sha256sum": "e38fabfee268d6b965a7c801ead7a5708e5766e349cfa6a19dd3add52018549a",<br>  "skip_telemetry": false,<br>  "skip_toolchain_metadata_sync": false,<br>  "skip_verify": false,<br>  "url": "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run",<br>  "verify_gpg_key_url": null<br>}</pre> | no |
| <a name="input_zones"></a> [zones](#input\_zones) | An optional list of compute zones where where the BIG-IP instances will be deployed; if null or empty (default) instances<br>will be randomly distributed to known zones in the subnetwork region. If one or more zone is given, the instances will be<br>constrained to the zones specified. | `list(string)` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_tag"></a> [cluster\_tag](#output\_cluster\_tag) | The pseudo-random network tag generated to uniquely identify the instances in this HA cluster. |
| <a name="output_instances_by_zone"></a> [instances\_by\_zone](#output\_instances\_by\_zone) | A map of Compute Engine zones to a list of instance self-links. |
| <a name="output_names"></a> [names](#output\_names) | The instance names of the BIG-IPs. |
| <a name="output_private_mgmt_ips"></a> [private\_mgmt\_ips](#output\_private\_mgmt\_ips) | A map of BIG-IP instance name to private IP address on the management interface. |
| <a name="output_public_mgmt_ips"></a> [public\_mgmt\_ips](#output\_public\_mgmt\_ips) | A map of BIG-IP instance name to public IP address, if any, on the management interface. |
| <a name="output_self_links"></a> [self\_links](#output\_self\_links) | A map of BIG-IP instance name to fully-qualified self-links. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- markdownlint-enable no-inline-html no-bare-urls -->

[upstream]: https://registry.terraform.io/modules/F5Networks/bigip-module/gcp/latest
