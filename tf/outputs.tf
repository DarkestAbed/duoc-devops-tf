# ==============================================================================
# ROOT OUTPUTS
# These values are required for the Ansible inventory and manual SSH jumps.
# ==============================================================================

output "web_instance_private_ip" {
  description = "The private IP of the Web instance"
  value       = module.compute.web_instance_private_ip
}

output "web_eip_public_ip" {
  description = "Stable public Elastic IP of the Web/Bastion instance"
  value       = module.compute.web_eip_public_ip
}

output "app_instance_private_ip" {
  description = "The private IP of the Application instance (Use this for SSH jump from Web)"
  value       = module.compute.app_instance_private_ip
}

output "datos_instance_private_ip" {
  description = "The private IP of the Data instance (Use this for SSH jump from App)"
  value       = module.compute.datos_instance_private_ip
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile attached to the EC2s"
  value       = module.compute.instance_profile_name
}

output "ami_id_used" {
  description = "AMI ID that was actually used for the instances"
  value       = module.compute.ami_id_used
}
