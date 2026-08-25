output "oci_ingest_bucket" {
  value       = oci_objectstorage_bucket.finops.name
  description = "Private Object Storage bucket receiving FOCUS reports."
}

output "log_analytics_log_group_id" {
  value       = oci_log_analytics_log_analytics_log_group.finops.id
  description = "Log Analytics log group for the FOCUS data."
}

output "object_collection_rule_id" {
  value       = oci_log_analytics_log_analytics_object_collection_rule.aws_focus.id
  description = "Live Object Storage collection rule for FOCUS_AWS."
}
