resource "aws_instance" "main" {
  ami                    = "ami-051c6296b8d2535f1"
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.duly-sg.id]
  iam_instance_profile   = aws_iam_instance_profile.session_manager.name

  tags = merge(local.common_tags, {
    Name = "duly-instance"
  })
}