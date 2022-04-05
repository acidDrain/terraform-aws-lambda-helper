terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = "~> 1.1.0"
}

locals {
  lambda_name                = "${var.lambda_name}-${var.environment}"
  lambda_bucket              = "${var.lambda_name}-${var.environment}-bucket"
  lambda_archive             = "${var.lambda_name}-${var.environment}-archive.zip"
  lambda_handler_export_name = "index.${var.handler_name}"
}

provider "aws" {
  default_tags {
    tags = {
      environment = var.environment
      application = var.lambda_name
      ManagedBy   = "terraform"
    }
  }
}



data "archive_file" "lambda_handler_archive" {
  type        = "zip"
  source_dir  = "${path.module}/build"
  output_path = "${path.module}/build/${local.lambda_archive}"
}


resource "aws_s3_bucket" "lambda_bucket" {
  bucket        = local.lambda_bucket
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_bucket-encryption" {
  bucket = aws_s3_bucket.lambda_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "lambda_handler_object" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = local.lambda_archive
  source = data.archive_file.lambda_handler_archive.output_path
  etag   = filemd5(data.archive_file.lambda_handler_archive.output_path)
}

/*
 * CloudWatch Logs for the Lambda
 */

resource "aws_cloudwatch_log_group" "lambda_run_log" {
  name = "/aws/lambda/${local.lambda_name}"
}

resource "aws_cloudwatch_log_stream" "lambda_successes" {
  name           = "/success"
  log_group_name = aws_cloudwatch_log_group.lambda_run_log.name
}

resource "aws_cloudwatch_log_stream" "lambda_failures" {
  name           = "/failure"
  log_group_name = aws_cloudwatch_log_group.lambda_run_log.name
}

resource "aws_cloudwatch_event_rule" "scheduled-lambda" {
  name                = "scheduled"
  description         = "This rule invokes a Lambda every day at the specified time (UTC)."
  schedule_expression = "cron(${var.cron-minutes} ${var.cron-hours} * * ? *)"
  event_bus_name      = "default" # Schedule expression is only supported on default event bus
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled-lambda.arn
}

resource "aws_cloudwatch_event_target" "run_lambda_daily" {
  rule           = aws_cloudwatch_event_rule.scheduled-lambda.id
  arn            = aws_lambda_function.main.arn
  event_bus_name = "default"
  input          = <<DOC
{
  "detail-type": "Scheduled Event",
  "detail": {}
}
DOC
}

resource "aws_lambda_function" "main" {
  function_name    = local.lambda_name
  s3_bucket        = aws_s3_bucket.lambda_bucket.id
  s3_key           = aws_s3_object.lambda_handler_object.key
  runtime          = "nodejs14.x"
  handler          = local.lambda_handler_export_name
  source_code_hash = data.archive_file.lambda_handler_archive.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      LambdaName = local.lambda_name
      region     = var.region
    }
  }

}

resource "aws_iam_role" "lambda_exec" {
  name               = "scheduled-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role-policy.json
}

data "aws_iam_policy_document" "lambda-assume-role-policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_overrides" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    effect    = "Allow"
    resources = ["${aws_cloudwatch_log_group.lambda_run_log.arn}/*"]
  }
}

resource "aws_iam_policy" "lambda_overrides_policy" {
  policy = data.aws_iam_policy_document.lambda_overrides.json

}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_overrides_policy.arn
}

