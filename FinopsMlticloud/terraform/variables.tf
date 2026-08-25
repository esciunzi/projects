variable "name_prefix" {
  description = "Prefix used for created resource names."
  type        = string
  default     = "finops-mc"
}

variable "aws_region" {
  description = "AWS Region containing the FOCUS export bucket."
  type        = string
}

variable "aws_access_key" {
  description = "Optional AWS access key for OCI Resource Manager; use the normal AWS credential chain when null."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "aws_secret_key" {
  description = "Optional AWS secret key for OCI Resource Manager; use the normal AWS credential chain when null."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "aws_session_token" {
  description = "Optional AWS session token when using temporary credentials."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "aws_source_bucket_name" {
  description = "Existing S3 bucket receiving the AWS FOCUS data export."
  type        = string
}

variable "aws_source_prefix" {
  description = "Prefix containing CSV or CSV.GZ FOCUS objects."
  type        = string
  default     = ""
}

variable "aws_schedule_expression" {
  description = "UTC EventBridge schedule for the curation function."
  type        = string
  default     = "cron(0 4 * * ? *)"
}

variable "target_lag_days" {
  description = "UTC days back to curate; increase when exports arrive late."
  type        = number
  default     = 1
}

variable "oci_region" {
  description = "OCI region identifier, for example eu-frankfurt-1."
  type        = string
}

variable "tenancy_ocid" {
  description = "OCI tenancy OCID."
  type        = string
}

variable "compartment_ocid" {
  description = "OCI compartment OCID for the collection resources."
  type        = string
}

variable "oci_namespace" {
  description = "Object Storage and Log Analytics namespace; null discovers it."
  type        = string
  default     = null
  nullable    = true
}

variable "oci_ingest_bucket_name" {
  description = "New private OCI bucket for curated AWS FOCUS data."
  type        = string
}

variable "oci_ingest_prefix" {
  description = "Object-name prefix granted to Lambda through the write-only PAR."
  type        = string
  default     = "aws-focus/"
}

variable "oci_par_expiration_rfc3339" {
  description = "Write-only PAR expiration in RFC3339 format."
  type        = string
}

variable "oci_admin_group_name" {
  description = "Existing OCI IAM group allowed to manage this environment."
  type        = string
}

variable "create_object_collection_rule" {
  description = "Create the Log Analytics LIVE Object Storage rule for FOCUS_AWS."
  type        = bool
  default     = true
}
