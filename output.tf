output "ecr-private-url" {
  value = aws_ecr_repository.private.repository_url
}

output "ecr-public-url" {
  value = length(aws_ecrpublic_repository.public) > 0 ? aws_ecrpublic_repository.public[0].repository_uri : ""
}

 