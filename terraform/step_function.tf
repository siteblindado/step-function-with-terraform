resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = var.stf_name
  role_arn = aws_iam_role.step_function_role.arn

  definition = <<EOF
  {
    "Comment": "Orquestrando AWS Lambdas com Step Functions",
    "StartAt": "StartScan",
    "States": {
        "StartScan": {
            "Type": "Task",
            "Resource": "${aws_lambda_function.lambda_function.arn}",
            "Catch": [{
                "ErrorEquals": ["States.ALL"],
                "ResultPath": "$.error",
                "Next": "Error"
            }],
            "Next": "Branch"
        },
        "Branch": {
            "Type": "Choice",
            "Choices": [{
                "Variable": "$.scan_status",
                "StringEquals": "running",
                "Next": "Sleep"
            }],
            "Default": "Done"
        },
        "Sleep": {
            "Type": "Wait",
            "SecondsPath": "$.sleep_seconds",
            "Next": "CheckScan"
        },
        "CheckScan": {
            "Type": "Task",
            "Resource": "${aws_lambda_function.lambda_function.arn}",
            "Retry": [{
                "ErrorEquals": ["States.All"],
                "IntervalSeconds": 1,
                "MaxAttempts": 10,
                "BackoffRate": 1.5
            }],
            "Catch": [{
                "ErrorEquals": ["States.ALL"],
                "ResultPath": "$.error",
                "Next": "Error"
            }],
            "Next": "Branch"
        },
        "Error": {
            "Type": "Task",
            "Resource": "${aws_lambda_function.lambda_function.arn}",
            "End": true
        },
        "Done": {
            "Type": "Task",
            "Resource": "${aws_lambda_function.lambda_function.arn}",
            "End": true
        }
    }
  }
  EOF
}

resource "aws_iam_role" "step_function_role" {
  name               = "${var.stf_name}-role"
  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "states.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": "StepFunctionAssumeRole"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "step_function_policy" {
  name    = "${var.stf_name}-policy"
  role    = aws_iam_role.step_function_role.id

  policy  = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "lambda:InvokeFunction"
        ],
        "Effect": "Allow",
        "Resource": "${aws_lambda_function.lambda_function.arn}"
      }
    ]
  }
  EOF
}
