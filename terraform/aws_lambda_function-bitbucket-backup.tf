
resource "aws_lambda_function" "bitbucket-backup" {
  # If the file is not in the current working directory you will need to include a 
  # path.module in the filename.
  #   filename      = "lambda_function_payload.zip"

  function_name = "bitbucket-backup-lambda"
  role          = aws_iam_role.lambda_role_bitbucket_lambda_execution.arn
  filename      = data.archive_file.bitbucket_backup_code_zip.output_path

  # Source code hash allows Terraform to auto-detect source code changes
  source_code_hash = data.archive_file.bitbucket_backup_code_zip.output_base64sha256
  handler          = "index.lambda_handler"
  runtime          = "python3.8"
  timeout          = 500
  memory_size      = 1000

  environment {
    variables = {
      backup_master_only        = true,
      use_credstash             = true,
      CREDSTASH_ACCOUNTNAME     = "bitbucket-backup-username",
      CREDSTASH_ACCOUNTPASSWORD = "bitbucket-backup-password"
    }
  }
}

# Zips the lambda code
data "archive_file" "bitbucket_backup_code_zip" {

  # IMPORTANT: Make sure you run the following inside the zip folder to add a depedencies folder
  # (That is if you don't already have the /vendor folder with all dependencies for the python project)
  # pip3 install -t vendor -r aws_requirements.txt

  type        = "zip"
  source_dir  = "../"
  output_path = "../bitbucket-backups-to-s3.zip"
}

# Create role
resource "aws_iam_role" "lambda_role_bitbucket_lambda_execution" {
  name               = "bitbucket_lambda_execution"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "lambda.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

# Create policy
resource "aws_iam_policy" "iam_policy_for_bitbucket_backup" {

  name        = "aws_iam_policy_for_bitbucket_backup"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "kms:Decrypt"
      ],
      "Effect": "Allow",
      "Resource": "${aws_kms_key.credstash.arn}"
    },
    {
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/credential-store"
    },
    {
      "Action": [
        "s3:PutObject",
        "s3:CreateMultipartUpload"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.apkd-bitbucket-backups.arn}/*"
    }
  ]
}
EOF
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "attach_to_bitbucket_backup" {
  role       = aws_iam_role.lambda_role_bitbucket_lambda_execution.name
  policy_arn = aws_iam_policy.iam_policy_for_bitbucket_backup.arn
}