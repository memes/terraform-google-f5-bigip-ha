# BIG-IP Instance Template

This sub-module creates a Google Compute instance template suitable for BIG-IP.

> NOTE: This module is not intended to be used directly but as a common configuration element for an _unmanaged group_
> of stateful instances as created by the root module, or as the template for a _managed group_ of stateless instances
> as created by stateless module.

<!-- markdownlint-disable no-inline-html no-bare-urls -->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_instance_template.bigip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_image.bigip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_image) | data source |
| [google_compute_subnetwork.external](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_subnetwork.internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_subnetwork.mgmt](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_external_interface"></a> [external\_interface](#input\_external\_interface) | Defines the subnetwork that will be attached to each instance's external interface (nic0), and a flag to assign a public<br>IP address to the management interface. | <pre>object({<br>    subnet_id = string<br>    public_ip = bool<br>  })</pre> | n/a | yes |
| <a name="input_internal_interfaces"></a> [internal\_interfaces](#input\_internal\_interfaces) | An optional list of up to 6 subnetworks that will be attached to each instance's internal interfaces (nic2...nicN),<br>and flags to assign a public IP address to the internal interface. | <pre>list(object({<br>    subnet_id = string<br>    public_ip = bool<br>  }))</pre> | n/a | yes |
| <a name="input_mgmt_interface"></a> [mgmt\_interface](#input\_mgmt\_interface) | Defines the subnetwork that will be attached to each instance's management interface (nic1), and a flag to assign a public<br>IP address to the management interface. | <pre>object({<br>    subnet_id = string<br>    public_ip = bool<br>  })</pre> | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | The prefix to use when naming resources managed by this module. Must be RFC1035<br>compliant and between 1 and 37 characters in length, inclusive. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project identifier where the BIG-IP HA pair will be created | `string` | n/a | yes |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | The email address of the service account which will be used for BIG-IP instances. | `string` | n/a | yes |
| <a name="input_automatic_restart"></a> [automatic\_restart](#input\_automatic\_restart) | Determines if the BIG-IP VMs should be automatically restarted if terminated by<br>GCE. Defaults to true to match expected GCE behaviour. | `bool` | `true` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Use this flag to set the boot volume size in GB. If left at the default value<br>the boot disk will have the same size as the base image. | `number` | `null` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | The boot disk type to use with instances; can be 'pd-balanced', 'pd-ssd' (default),<br>or 'pd-standard'. | `string` | `"pd-ssd"` | no |
| <a name="input_image"></a> [image](#input\_image) | The self-link URI for a BIG-IP image to use as a base for the VM cluster. This<br>can be an official F5 image from GCP Marketplace, or a customised image. | `string` | `"projects/f5-7626-networks-public/global/images/f5-bigip-17-1-1-3-0-0-5-payg-good-1gbps-240321070835"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | An optional map of string key:value pairs that will be applied to all resources<br>created that accept labels. Default is an empty map. | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type to use for BIG-IP VMs; this may be a standard GCE machine type,<br>or a customised VM ('custom-VCPUS-MEM\_IN\_MB'). Default value is 'n1-standard-8'.<br>\_NOTE:\_ machine\_type is highly-correlated with network bandwidth and performance;<br>an N2 machine type will give better performance but has limited regional availability. | `string` | `"n1-standard-8"` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Provide custom metadata values for BIG-IP instances | `map(string)` | `{}` | no |
| <a name="input_min_cpu_platform"></a> [min\_cpu\_platform](#input\_min\_cpu\_platform) | An optional constraint used when scheduling the BIG-IP VMs; this value prevents<br>the VMs from being scheduled on hardware that doesn't meet the minimum CPU<br>micro-architecture. Default value is 'Intel Skylake'. | `string` | `"Intel Skylake"` | no |
| <a name="input_network_tags"></a> [network\_tags](#input\_network\_tags) | The network tags which will be added to the BIG-IP VMs. | `list(string)` | `[]` | no |
| <a name="input_preemptible"></a> [preemptible](#input\_preemptible) | If set to true, the BIG-IP instances will be deployed on preemptible VMs, which<br>could be terminated at any time, and have a maximum lifetime of 24 hours. Default<br>value is false. DO NOT SET TO TRUE UNLESS YOU UNDERSTAND THE RAMIFICATIONS! | `bool` | `false` | no |
| <a name="input_runtime_init_config"></a> [runtime\_init\_config](#input\_runtime\_init\_config) | n/a | `string` | `null` | no |
| <a name="input_runtime_init_installer"></a> [runtime\_init\_installer](#input\_runtime\_init\_installer) | Defines the location of the runtime-init package to install, and an optional SHA256 checksum. During initialisation,<br>the runtime-init installer will be downloaded from this location - which can be an http/https/gs/file/ftp URL - and<br>verified against the provided checksum, if provided. Additional flags can change the behaviour of runtime-init when used<br>in restricted environments (see https://github.com/F5Networks/f5-bigip-runtime-init?tab=readme-ov-file#private-environments). | <pre>object({<br>    url                          = string<br>    sha256sum                    = string<br>    skip_telemetry               = bool<br>    skip_toolchain_metadata_sync = bool<br>    skip_verify                  = bool<br>    verify_gpg_key_url           = string<br>  })</pre> | <pre>{<br>  "sha256sum": "e38fabfee268d6b965a7c801ead7a5708e5766e349cfa6a19dd3add52018549a",<br>  "skip_telemetry": false,<br>  "skip_toolchain_metadata_sync": false,<br>  "skip_verify": false,<br>  "url": "https://github.com/F5Networks/f5-bigip-runtime-init/releases/download/2.0.3/f5-bigip-runtime-init-2.0.3-1.gz.run",<br>  "verify_gpg_key_url": null<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_id"></a> [id](#output\_id) | n/a |
| <a name="output_metadata"></a> [metadata](#output\_metadata) | n/a |
| <a name="output_name"></a> [name](#output\_name) | n/a |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- markdownlint-enable no-inline-html no-bare-urls -->
