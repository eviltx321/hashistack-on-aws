# Grab remote outputs from the infrastructure workspace and use in place of the variables if available
# Requirements: allow shared outputs between infrastructure -> packages workspace in HCP Terraform

output "aws_lb_controller_role_arn" {
  value = local.aws_lb_controller_role_arn
}