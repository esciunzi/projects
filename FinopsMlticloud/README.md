# Multicloud FinOps with Oracle Log Analytics

This project centralizes AWS and OCI FOCUS cost and usage data in Oracle Log Analytics, giving FinOps, engineering, and finance teams one shared view of cloud consumption.

![Oracle multicloud FinOps dashboard](https://blogs.oracle.com/observability/wp-content/uploads/sites/47/2026/07/finops_dashboard-1024x492.png)

*Multicloud dashboard. Image © Oracle, linked from the referenced blog post.*

## Business Value

Multicloud cost management is difficult when providers expose different account hierarchies, service names, SKUs, regions, and tags. FOCUS provides a common cost and usage specification; Oracle Log Analytics turns that data into one searchable and visual FinOps layer.

Stakeholders can move from a cost increase to the responsible provider, service, region, resource, SKU, and ownership group. Executives gain a clear view of spend trends and budget risk; application owners can investigate their workloads; and finance teams can support showback, chargeback, allocation, and variance analysis.

The dashboard also supports cost-driver analysis, anomaly investigation, and environment- or group-based filtering. The same normalized fields can be used for saved searches, alerts, and longer-term cost retention.

![Oracle Logan AI view](https://blogs.oracle.com/observability/wp-content/uploads/sites/47/2026/07/loganai.gif)

*Natural-language exploration with Logan AI. Image © Oracle, linked from the referenced blog post.*

## Dashboard Architecture

AWS Billing and Cost Management Data Exports publish FOCUS data to Amazon S3. Because exports can be refreshed during a billing period and contain cumulative records, the scheduled curation function selects the latest CSV or CSV.GZ export, filters it to a single usage date, and publishes one deterministic object: `aws_focus_daily__usage_date=YYYY-MM-DD.csv.gz`.

The curated AWS file lands in OCI Object Storage, where the `FOCUS_AWS` source and a Log Analytics object collection rule ingest it. OCI FOCUS data is parsed through `FOCUS_OCI`. Both providers then use the same normalized model beneath the `FinOps_MC` dashboard.

![Oracle reference architecture](https://blogs.oracle.com/observability/wp-content/uploads/sites/47/2026/07/Architecture.jpg)

*Reference architecture. Image © Oracle, linked from the referenced blog post.*

![Oracle AWS FOCUS pipeline](https://blogs.oracle.com/observability/wp-content/uploads/sites/47/2026/06/image-10.png)

*AWS FOCUS pipeline. Image © Oracle, linked from the referenced blog post.*

The Terraform stack in [`terraform/`](terraform/) creates the OCI collection environment, required OCI policies, the scoped Object Storage write path, and the scheduled AWS Lambda curation function. The Log Analytics content exports remain in [`src/`](src/) as portable imports.

## Normalization Fields

The parsers map each provider report to stable `MC_*` fields. This separates the dashboard from provider-specific report versions, optional fields, and extensions.

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
| `MC_USAGE` | Usage measure exposed by the AWS parser |

The OCI parser includes `MC_GROUP`; add an equivalent AWS allocation mapping when business-unit reporting is needed. Owner, application, cost centre, tags, and commitment-discount detail can be added without changing the shared dashboard contract.

![Oracle normalized FinOps fields](https://blogs.oracle.com/observability/wp-content/uploads/sites/47/2026/06/finops_normdata-1024x366.png)

*Normalized field model. Image © Oracle, linked from the referenced blog post.*

## Included Assets

| Asset | Purpose |
| --- | --- |
| [`src/FOCUS_AWS.xml`](src/FOCUS_AWS.xml) | Log Analytics `FOCUS_AWS` parser and source export |
| [`src/FOCUS_OCI.xml`](src/FOCUS_OCI.xml) | Log Analytics `FOCUS_OCI` parser and source export |
| [`src/FinOps_MC.json`](src/FinOps_MC.json) | `FinOps_MC` dashboard export; six tiles and six saved searches |
| [`terraform/`](terraform/) | Resource Manager-ready infrastructure stack and AWS curation function |
| [`terraform/finops-mc-oci-stack.zip`](terraform/finops-mc-oci-stack.zip) | Deployable OCI Resource Manager package |

## Deploy on Oracle Cloud

[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://raw.githubusercontent.com/esciunzi/projects/finOpsMC/FinopsMlticloud/terraform/finops-mc-oci-stack.zip)

The button opens OCI Resource Manager's **Create stack** page using the published stack ZIP from the `finOpsMC` branch.

## References

- [Monitoring FinOps Data Across Multicloud with Oracle Log Analytics](https://blogs.oracle.com/observability/monitor-finops-multicloud-oracle-log-analytics)
- [Observability for AWS FinOps Data with Oracle Log Analytics](https://blogs.oracle.com/observability/observability-aws-finops-data-oracle-log-analytics)
- [FOCUS specification](https://focus.finops.org/)
- [Collect Logs from Your OCI Object Storage Bucket](https://docs.oracle.com/en-us/iaas/log-analytics/doc/collect-logs-from-your-oci-object-storage-bucket.html)
- [Deploy to Oracle Cloud button documentation](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Tasks/deploybutton.htm)
