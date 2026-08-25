# Multicloud FinOps with Oracle Log Analytics

Cloud cost data becomes hard to govern when it is scattered across providers,
accounts, regions, SKU catalogs, and tag models. This project applies the
[FOCUS](https://focus.finops.org/) cost and usage specification as a common
language for cost observability across AWS and OCI.

It follows Oracle's [multicloud FinOps article](https://blogs.oracle.com/observability/monitor-finops-multicloud-oracle-log-analytics)
and its [AWS FOCUS data pipeline article](https://blogs.oracle.com/observability/observability-aws-finops-data-oracle-log-analytics).

![Oracle multicloud FinOps dashboard](https://blogs.oracle.com/observability/wp-content/uploads/sites/47/2026/07/finops_dashboard-1024x492.png)

*Multicloud dashboard. Image © Oracle, linked from the referenced blog post.*

## One cost-data contract

The dashboard is only as dependable as the normalized model beneath it.
Providers can change FOCUS versions, omit optional columns, add extensions,
and use different hierarchy and tag models. The parsers map each provider
report to stable `MC_*` fields so saved searches, alarms, and dashboard widgets
do not need to change with every upstream report revision.

| Normalized field | Meaning |
| --- | --- |
| `MC_CONSUMPTION` | Cost or consumption amount used for analysis |
| `MC_CURRENCY` | Billing currency |
| `MC_Hypervisor` | Source cloud or platform, such as AWS or OCI |
| `MC_REGION` | Usage region |
| `MC_SERVICE` | Cloud service |
| `MC_ResourceID` / `MC_ResourceName` | Resource identifier and display name |
| `MC_SKU` | SKU or metering dimension |
| `MC_ENVIRONMENT` | Environment classification |
| `MC_GROUP` | Allocation or ownership group |

The AWS parser also exposes `MC_USAGE`. The OCI parser includes `MC_GROUP`; an
equivalent AWS allocation mapping can be added when business-unit reporting is
needed. Owner, application, cost centre, tags, and commitment-discount detail
can be added without changing the shared dashboard contract.

![Oracle normalized FinOps fields](https://blogs.oracle.com/observability/wp-content/uploads/sites/47/2026/06/finops_normdata-1024x366.png)

*Normalized field model. Image © Oracle, linked from the referenced blog post.*

## From AWS export to cost observability

AWS Billing and Cost Management Data Exports deliver FOCUS data to Amazon S3.
That delivery is source data, not a reliable daily fact table: an export can be
refreshed during a billing period and can include cumulative or overlapping
records. The curation function selects the latest available export, filters it
to one usage date, and publishes exactly one object named
`aws_focus_daily__usage_date=YYYY-MM-DD.csv.gz`.

OCI Object Storage is the governed handoff into Log Analytics. The collection
rule associates the objects with the `FOCUS_AWS` source, Log Analytics parses
them, and the shared dashboard makes the data searchable and visual.

![Oracle reference architecture](https://blogs.oracle.com/observability/wp-content/uploads/sites/47/2026/07/Architecture.jpg)

*Reference architecture. Image © Oracle, linked from the referenced blog post.*

![Oracle AWS FOCUS pipeline](https://blogs.oracle.com/observability/wp-content/uploads/sites/47/2026/06/image-10.png)

*AWS FOCUS pipeline. Image © Oracle, linked from the referenced blog post.*

The separation is what makes the pattern extensible. Adding a provider becomes
an extraction-and-mapping task while the analytics layer continues to work with
the same normalized dimensions. It supports executives tracking trend and
budget risk, application owners investigating their services and resources,
and finance teams running allocation, showback, or chargeback analysis.

![Oracle Logan AI view](https://blogs.oracle.com/observability/wp-content/uploads/sites/47/2026/07/loganai.gif)

*Natural-language exploration with Logan AI. Image © Oracle, linked from the
referenced blog post.*

## Repository content

| Asset | Purpose |
| --- | --- |
| [`src/FOCUS_AWS.xml`](src/FOCUS_AWS.xml) | Log Analytics `FOCUS_AWS` parser and source export |
| [`src/FOCUS_OCI.xml`](src/FOCUS_OCI.xml) | Log Analytics `FOCUS_OCI` parser and source export |
| [`src/FinOps_MC.json`](src/FinOps_MC.json) | `FinOps_MC` dashboard export; six tiles and six saved searches |
| [`terraform/`](terraform/) | AWS-to-OCI collection environment, policies, and curation function |
| [`img/`](img/) | Attribution for the Oracle images embedded above |
| [`video/`](video/) | Place demonstrations here |

The three Log Analytics files are kept unchanged so they remain portable
imports. The exact Oracle images above are linked directly from their original
blog locations rather than copied into this repository.

## Terraform environment

<!-- Replace REPLACE_WITH_GITHUB_OWNER and REPLACE_WITH_GITHUB_REPOSITORY after publishing this repository. -->
[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://raw.githubusercontent.com/REPLACE_WITH_GITHUB_OWNER/REPLACE_WITH_GITHUB_REPOSITORY/main/terraform/finops-mc-oci-stack.zip)

[`terraform/`](terraform/) provisions the AWS-to-OCI environment: a private
OCI bucket with object events, a 48-hour OCI stream, a Log Analytics log group
and `LIVE` collection rule, OCI dynamic-group and administrator policies, a
scoped write-only Object Storage pre-authenticated request (PAR), and the AWS
Lambda role and scheduled curation function.

The configuration expects the `FOCUS_AWS` Log Analytics source to already
exist, because content exports and dashboard imports are not Terraform
resources. The function is intentionally limited to CSV and CSV.GZ input,
matching the supplied parser. Its source prefix, schedule, delivery lag, and
PAR expiry are configurable in
[`terraform/terraform.tfvars.example`](terraform/terraform.tfvars.example).
Treat Terraform state as sensitive because it contains the PAR URL.

The linked [`terraform/finops-mc-oci-stack.zip`](terraform/finops-mc-oci-stack.zip)
has the Terraform files at its root, ready for OCI Resource Manager. Update the
two GitHub placeholders in the button URL with the published repository owner
and name; OCI Resource Manager then opens its **Create stack** page with this
package preselected.

Oracle documents that a bucket can have one `LIVE` or `HISTORIC_LIVE` object
collection rule, and that the supporting stream must have a public endpoint.
See [Collect Logs from Your OCI Object Storage Bucket](https://docs.oracle.com/en-us/iaas/log-analytics/doc/collect-logs-from-your-oci-object-storage-bucket.html)
for operational limits and service behaviour.
