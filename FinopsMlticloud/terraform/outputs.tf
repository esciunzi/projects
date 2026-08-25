output "oci_ingest_bucket" {
  value       = oci_objectstorage_bucket.finops.name
  description = "OCI bucket receiving the curated AWS data."
}

output "log_analytics_log_group_id" {
  value       = oci_log_analytics_log_analytics_log_group.finops.id
  description = "Log Analytics log group created for the FOCUS data."
}

output "aws_curation_function_name" {
  value       = aws_lambda_function.curate_focus.function_name
  description = "AWS Lambda function that curates and publishes FOCUS data."
}

output "oci_par_url" {
  value       = "https://objectstorage.${var.oci_region}.oraclecloud.com${oci_objectstorage_preauthrequest.lambda_writer.access_uri}"
  description = "Write-only OCI Object Storage PAR used by Lambda. Store securely."
  sensitive   = true
}


