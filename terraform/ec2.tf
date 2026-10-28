resource "aws_instance" "main" {
  ami                    = "ami-0e917bb9ad92a91cf"
  instance_type          = "t4g.medium"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.duly-sg.id]
  iam_instance_profile   = aws_iam_instance_profile.session_manager.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true

    tags = merge(local.common_tags, {
      Name = "duly-instance-root"
    })
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' > /etc/profile.d/k3s.sh
  EOT

  user_data_replace_on_change = true

  tags = merge(local.common_tags, {
    Name = "duly-instance"
  })
}
