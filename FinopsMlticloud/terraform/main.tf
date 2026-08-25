data "aws_s3_bucket" "focus_export" {
  bucket = var.aws_source_bucket_name
}

data "oci_objectstorage_namespace" "current" {
  compartment_id = var.tenancy_ocid
}

locals {
  oci_namespace = coalesce(var.oci_namespace, data.oci_objectstorage_namespace.current.namespace)
  ingest_prefix = trimsuffix(var.oci_ingest_prefix, "/")
}

resource "oci_objectstorage_bucket" "finops" {
  compartment_id        = var.compartment_ocid
  name                  = var.oci_ingest_bucket_name
  namespace             = local.oci_namespace
  access_type           = "NoPublicAccess"
  object_events_enabled = true
}

resource "oci_streaming_stream" "object_collection" {
  compartment_id     = var.compartment_ocid
  name               = "${var.name_prefix}-object-collection"
  partitions         = 1
  retention_in_hours = 48
}

resource "oci_log_analytics_log_analytics_log_group" "finops" {
  compartment_id = var.compartment_ocid
  namespace      = local.oci_namespace
  display_name   = "${var.name_prefix}-focus"
  description    = "Curated multicloud FOCUS cost and usage data"
}

resource "oci_identity_dynamic_group" "object_collection" {
  compartment_id = var.tenancy_ocid
  name           = "${var.name_prefix}-object-collection"
  description    = "Log Analytics Object Collection Rule resource principals"
  matching_rule  = "ALL {resource.type='loganalyticsobjectcollectionrule'}"
}

resource "oci_identity_policy" "object_collection_service" {
  compartment_id = var.tenancy_ocid
  name           = "${var.name_prefix}-object-collection-service"
  description    = "Allow Log Analytics Object Collection Rules to collect FOCUS objects"
  statements = [
    "allow dynamic-group ${oci_identity_dynamic_group.object_collection.name} to read buckets in compartment id ${var.compartment_ocid}",
    "allow dynamic-group ${oci_identity_dynamic_group.object_collection.name} to read objects in compartment id ${var.compartment_ocid}",
    "allow dynamic-group ${oci_identity_dynamic_group.object_collection.name} to manage cloudevents-rules in compartment id ${var.compartment_ocid}",
    "allow dynamic-group ${oci_identity_dynamic_group.object_collection.name} to inspect compartments in tenancy",
    "allow dynamic-group ${oci_identity_dynamic_group.object_collection.name} to use tag-namespaces in tenancy where all {target.tag-namespace.name = /oracle-tags/}",
    "allow dynamic-group ${oci_identity_dynamic_group.object_collection.name} to {STREAM_CONSUME} in compartment id ${var.compartment_ocid}"
  ]
}

resource "oci_identity_policy" "collection_administrators" {
  compartment_id = var.tenancy_ocid
  name           = "${var.name_prefix}-collection-administrators"
  description    = "Allow FinOps administrators to manage the collection environment"
  statements = [
    "allow group ${var.oci_admin_group_name} to use loganalytics-features-family in tenancy",
    "allow group ${var.oci_admin_group_name} to use loganalytics-resources-family in compartment id ${var.compartment_ocid}",
    "allow group ${var.oci_admin_group_name} to use object-family in compartment id ${var.compartment_ocid}",
    "allow group ${var.oci_admin_group_name} to use stream-family in compartment id ${var.compartment_ocid}"
  ]
}

resource "oci_objectstorage_preauthrequest" "lambda_writer" {
  namespace    = local.oci_namespace
  bucket       = oci_objectstorage_bucket.finops.name
  name         = "${var.name_prefix}-aws-focus-writer"
  access_type  = "AnyObjectWrite"
  object       = "${local.ingest_prefix}/"
  time_expires = var.oci_par_expiration_rfc3339
}

data "archive_file" "curate_focus" {
  type        = "zip"
  source_file = "${path.module}/function/curate_focus.py"
  output_path = "${path.module}/curate_focus.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "curate_focus" {
  name               = "${var.name_prefix}-curate-focus"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "curate_focus" {
  name = "${var.name_prefix}-curate-focus"
  role = aws_iam_role.curate_focus.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = data.aws_s3_bucket.focus_export.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${data.aws_s3_bucket.focus_export.arn}/${var.aws_source_prefix}*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.name_prefix}-curate-focus:*"
      }
    ]
  })
}

resource "aws_lambda_function" "curate_focus" {
  function_name    = "${var.name_prefix}-curate-focus"
  role             = aws_iam_role.curate_focus.arn
  handler          = "curate_focus.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.curate_focus.output_path
  source_code_hash = data.archive_file.curate_focus.output_base64sha256
  timeout          = 900
  memory_size      = 1024

  ephemeral_storage {
    size = 2048
  }

  environment {
    variables = {
      AWS_SOURCE_BUCKET = var.aws_source_bucket_name
      AWS_SOURCE_PREFIX = var.aws_source_prefix
      OCI_OBJECT_PREFIX = "${local.ingest_prefix}/"
      OCI_PAR_URL       = "https://objectstorage.${var.oci_region}.oraclecloud.com${oci_objectstorage_preauthrequest.lambda_writer.access_uri}"
      TARGET_LAG_DAYS   = tostring(var.target_lag_days)
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily_curation" {
  name                = "${var.name_prefix}-daily-curation"
  description         = "Run the AWS FOCUS curation function"
  schedule_expression = var.aws_schedule_expression
}

resource "aws_cloudwatch_event_target" "daily_curation" {
  rule = aws_cloudwatch_event_rule.daily_curation.name
  arn  = aws_lambda_function.curate_focus.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.curate_focus.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_curation.arn
}

resource "oci_log_analytics_log_analytics_object_collection_rule" "aws_focus" {
  count = var.create_object_collection_rule ? 1 : 0

  namespace           = local.oci_namespace
  compartment_id      = var.compartment_ocid
  name                = "${var.name_prefix}-aws-focus"
  description         = "Collect curated AWS FOCUS CSV.GZ data"
  os_namespace        = local.oci_namespace
  os_bucket_name      = oci_objectstorage_bucket.finops.name
  log_group_id        = oci_log_analytics_log_analytics_log_group.finops.id
  log_source_name     = "FOCUS_AWS"
  collection_type     = "LIVE"
  stream_id           = oci_streaming_stream.object_collection.id
  stream_cursor_type  = "LATEST"
  object_name_filters = ["${local.ingest_prefix}/*"]

  depends_on = [
    oci_identity_policy.object_collection_service,
    oci_identity_policy.collection_administrators
  ]
}
