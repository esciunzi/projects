variable "name_prefix" {
  description = "Prefix used for created resource names."
  type        = string
  default     = "finops-mc"
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
  description = "OCI compartment OCID for the FinOps resources."
  type        = string
}

variable "oci_namespace" {
  description = "Object Storage and Log Analytics namespace; null discovers it."
  type        = string
  default     = null
  nullable    = true
}

variable "oci_ingest_bucket_name" {
  description = "Name for the new private OCI bucket that receives FOCUS reports."
  type        = string
}

variable "oci_ingest_prefix" {
  description = "Object-name prefix the live Object Storage rule monitors."
  type        = string
  default     = "aws-focus"
}

variable "oci_admin_group_name" {
  description = "Existing OCI IAM group allowed to manage the FinOps environment."
  type        = string
}
