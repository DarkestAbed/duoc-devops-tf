output "sg_web_id" {
  description = "ID of the Web security group"
  value       = aws_security_group.sg_web.id
}

output "sg_app_id" {
  description = "ID of the App security group"
  value       = aws_security_group.sg_app.id
}

output "sg_datos_id" {
  description = "ID of the Data security group"
  value       = aws_security_group.sg_datos.id
}
