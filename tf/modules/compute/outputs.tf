output "web_instance_id" {
  description = "ID of the web EC2 instance"
  value       = aws_instance.ec2_web.id
}

output "web_instance_private_ip" {
  description = "Private IP of the web instance"
  value       = aws_instance.ec2_web.private_ip
}

output "web_eip_public_ip" {
  description = "Stable public Elastic IP of the Web/Bastion instance"
  value       = aws_eip.web_eip.public_ip
}

output "app_instance_id" {
  description = "ID of the app EC2 instance"
  value       = aws_instance.ec2_app.id
}

output "app_instance_private_ip" {
  description = "Private IP of the app instance"
  value       = aws_instance.ec2_app.private_ip
}

output "datos_instance_id" {
  description = "ID of the datos EC2 instance"
  value       = aws_instance.ec2_datos.id
}

output "datos_instance_private_ip" {
  description = "Private IP of the datos instance"
  value       = aws_instance.ec2_datos.private_ip
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile created"
  value       = aws_iam_instance_profile.lab_profile.name
}

output "ami_id_used" {
  description = "AMI ID actually used for the instances"
  value       = local.ami
}
