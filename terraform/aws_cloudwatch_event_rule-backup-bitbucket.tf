resource "aws_cloudwatch_event_rule" "bitbucket_backup_scheduler" {
  name                = "bitbucket-backup-scheduler"
  description         = "retry scheduled every 7 days"
  schedule_expression = "rate(7 days)"
}

resource "aws_cloudwatch_event_target" "profile_generator_lambda_target" {
  arn  = aws_lambda_function.bitbucket-backup.arn
  rule = aws_cloudwatch_event_rule.bitbucket_backup_scheduler.name
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_rw_fallout_retry_step_deletion_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bitbucket-backup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.bitbucket_backup_scheduler.arn
}