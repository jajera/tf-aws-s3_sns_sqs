variable "use_case" {
  default = "tf-aws-s3-sns-sqs"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_resourcegroups_group" "example" {
  name        = "tf-rg-example"
  description = "Resource group for example resources"

  resource_query {
    query = <<JSON
    {
      "ResourceTypeFilters": [
        "AWS::AllSupported"
      ],
      "TagFilters": [
        {
          "Key": "Owner",
          "Values": ["John Ajera"]
        },
        {
          "Key": "UseCase",
          "Values": ["${var.use_case}"]
        }
      ]
    }
    JSON
  }

  tags = {
    Name    = "tf-rg-example"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_s3_bucket" "example" {
  bucket        = "example-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name    = "tf-s3-bucket-example"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_sns_topic" "example" {
  name = "tf-sns-example"

  tags = {
    Name    = "tf-sns-example"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_sns_topic_policy" "example" {
  arn    = aws_sns_topic.example.arn
  policy = <<POLICY
{
    "Version":"2012-10-17",
    "Statement":[
      {
        "Sid": "__default_statement_ID",
        "Effect": "Allow",
        "Principal": {
          "AWS": "*"
        },
        "Action": [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish",
          "SNS:Receive"
        ],
        "Resource": "${aws_sns_topic.example.arn}",
        "Condition": {
          "StringEquals": {
            "AWS:SourceAccount": "${data.aws_caller_identity.current.account_id}"
          }
        }
      },
      {
        "Effect": "Allow",
        "Principal": { "Service": "s3.amazonaws.com" },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:*:*:tf-sns-example",
        "Condition":{
            "ArnLike":{"aws:SourceArn":"${aws_s3_bucket.example.arn}"}
        }
      }
    ]
}
POLICY
}

resource "aws_s3_bucket_notification" "example" {
  bucket = aws_s3_bucket.example.id
  topic {
    topic_arn = aws_sns_topic.example.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_sqs_queue" "example" {
  name                      = "tf-sqs-example"
  receive_wait_time_seconds = 20
  message_retention_seconds = 60

  tags = {
    Name    = "tf-sqs-example"
    Owner   = "John Ajera"
    UseCase = var.use_case
  }
}

resource "aws_sns_topic_subscription" "example" {
  protocol             = "sqs"
  raw_message_delivery = true
  topic_arn            = aws_sns_topic.example.arn
  endpoint             = aws_sqs_queue.example.arn
}

resource "aws_sqs_queue_policy" "example" {
  queue_url = aws_sqs_queue.example.id
  policy    = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": [
        "${aws_sqs_queue.example.arn}"
      ],
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.example.arn}"
        }
      }
    }
  ]
}
EOF
}
