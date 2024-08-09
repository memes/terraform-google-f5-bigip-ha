# Stateless BIG-IP Active-Active HA on Google Cloud

> NOTE: This module is pre-release and functionality can change abruptly prior to v1.0 release. Be sure to pin to an
> exact version to avoid unintentional breakage due to updates.

This Terraform module creates Google Cloud infrastructure for an *opinionated, stateless, regional or zonal cluster* of
F5 BIG-IP VE instances, where Google Cloud determines when instances are created, destroyed and how they are named. You
must provide a full declarative onboarding payload appropriate to your scenario that can be applied identically to all
instances.

> For the purpose of this module, *stateless* is taken to mean that each BIG-IP VE instance is independent of every other
> instance in the cluster, providing an Active-Active (all instances could handle traffic) HA deployment.
>
> The root module is [stateful](../../) and can be used to create an Active-Standby or Active-Active HA cluster of BIG-IP
> VE instances that share configuration through sync groups.

## What makes the module opinionated, and why might it be wrong for me?

F5's published [BIG-IP on Google Cloud Terraform module][upstream] can be used to create a set of VE instances that can
be joined into a device sync group when combined with additional effort/configuration, but it has no support for
*stateless* clusters of BIG-IP VE instances.

1. Virtual machine lifecycle

   > OPINION: Google Cloud will be responsible for launching and terminating BIG-IP VE instances as needed.

   The module provides a `num_instances` input to set the size of the cluster; module consumers can change that value and
   reapply to have Google Cloud automatically add or terminate instances as needed for manual scaling.

   Autoscaling can be supported by setting `num_instances` to 0, and adding the instance group to an autoscaler; see
   [autoscaling](../../examples/autoscaling-alb/) for an example.

   > NOTE: Per-instance naming or lifecycle management is not supported for *stateless* clusters.

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

   > NOTE: Per-instance IP addressing is not supported for *stateless* clusters.

3. Module responsibility for onboarding stops at runtime-init

   > OPINION: Consumers of the module must provide a runtime-init configuration to set passwords, enable data-plane, and
   > add applications, etc.

   There are simply too many configuration options and deployment scenarios to have a one-size-fits-all module suitable
   for every situation. This module will provide a cloud-init file through `user-data` metadata value that will configure
   the management interface (nic1) of every instance from Compute Engine metadata, attempt to download and install
   runtime-init, then execute a provided configuration file.

   If a runtime-init configuration file is not provided the instances will not be fully configured; the admin user
   password will be unknown, traffic will not be processed, and the instance group manager will kill instances.

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
| <a name="module_template"></a> [template](#module\_template) | ..//template/ | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.livez](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_health_check.livez](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_region_instance_group_manager.mig](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
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
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project identifier where the BIG-IP instances will be created. | `string` | n/a | yes |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | The email address of the service account which will be used for BIG-IP instances. | `string` | n/a | yes |
| <a name="input_automatic_restart"></a> [automatic\_restart](#input\_automatic\_restart) | Determines if the BIG-IP VMs should be automatically restarted if terminated by<br>GCE. Defaults to true to match expected Compute Engine behaviour. | `bool` | `true` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Use this flag to set the boot volume size in GB; the default value is 100. | `number` | `100` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | The boot disk type to use with instances; can be 'pd-balanced', 'pd-ssd' (default),<br>or 'pd-standard'. | `string` | `"pd-ssd"` | no |
| <a name="input_image"></a> [image](#input\_image) | The self-link URI for a BIG-IP image to use as a base for the VM cluster. This can be an official F5 image from GCP<br>Marketplace, or a customised image. | `string` | `"projects/f5-7626-networks-public/global/images/f5-bigip-17-1-1-3-0-0-5-payg-good-1gbps-240321070835"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of string key:value pairs that will be applied to all resources created that accept labels. Default is<br>an empty map. | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type to use for BIG-IP VMs; this may be a standard GCE machine type,<br>or a customised VM ('custom-VCPUS-MEM\_IN\_MB'). Default value is 'n1-standard-8'.<br>\_NOTE:\_ machine\_type is highly-correlated with network bandwidth and performance;<br>an N2 machine type will give better performance but has limited regional availability. | `string` | `"n1-standard-8"` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | An optional set of metadata values to add to all BIG-IP instances. Can be used to override the onboarding script. | `map(string)` | `{}` | no |
| <a name="input_min_cpu_platform"></a> [min\_cpu\_platform](#input\_min\_cpu\_platform) | An optional constraint used when scheduling the BIG-IP VMs; this value prevents<br>the VMs from being scheduled on hardware that doesn't meet the minimum CPU<br>micro-architecture. Default value is 'Intel Skylake'. | `string` | `"Intel Skylake"` | no |
| <a name="input_network_tags"></a> [network\_tags](#input\_network\_tags) | The network tags which will be added to the BIG-IP VMs. | `list(string)` | `[]` | no |
| <a name="input_num_instances"></a> [num\_instances](#input\_num\_instances) | The number of BIG-IP instances to create as a stateless group; if using with an autoscaler this value should be set to<br>0. | `number` | `2` | no |
| <a name="input_preemptible"></a> [preemptible](#input\_preemptible) | If set to true, the BIG-IP instances will be deployed on preemptible VMs, which<br>could be terminated at any time, and have a maximum lifetime of 24 hours. Default<br>value is false. DO NOT SET TO TRUE UNLESS YOU UNDERSTAND THE RAMIFICATIONS! | `bool` | `false` | no |
| <a name="input_runtime_init_config"></a> [runtime\_init\_config](#input\_runtime\_init\_config) | A runtime-init YAML configuration that will be executed during initialisation. If omitted, the BIG-IP instances will<br>be largely unconfigured, with only the management interface accessible. | `string` | `null` | no |
| <a name="input_runtime_init_installer"></a> [runtime\_init\_installer](#input\_runtime\_init\_installer) | Defines the location of the runtime-init package to install, and an optional SHA256 checksum. During initialisation,<br>the runtime-init installer will be downloaded from this location - which can be an http/https/gs/file/ftp URL - and<br>verified against the provided checksum, if provided. Additional flags can change the behaviour of runtime-init when used<br>in restricted environments (see https://github.com/F5Networks/f5-bigip-runtime-init?tab=readme-ov-file#private-environments). | <pre>object({<br>    url                          = string<br>    sha256sum                    = string<br>    skip_telemetry               = bool<br>    skip_toolchain_metadata_sync = bool<br>    skip_verify                  = bool<br>    verify_gpg_key_url           = string<br>  })</pre> | <pre>{<br>  "sha256sum": "e38fabfee268d6b965a7c801ead7a5708e5766e349cfa6a19dd3add52018549a",<br>  "skip_telemetry": false,<br>  "skip_toolchain_metadata_sync": false,<br>  "skip_verify": false,<br>  "url": "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run",<br>  "verify_gpg_key_url": null<br>}</pre> | no |
| <a name="input_zones"></a> [zones](#input\_zones) | An optional list of compute zones where where the BIG-IP instances will be deployed; if null or empty (default) instances<br>will be randomly distributed to known zones in the subnetwork region. If one or more zone is given, the instances will be<br>constrained to the zones specified. | `list(string)` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- markdownlint-enable no-inline-html no-bare-urls -->

[upstream]: https://registry.terraform.io/modules/F5Networks/bigip-module/gcp/latest
