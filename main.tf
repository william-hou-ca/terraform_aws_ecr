provider "aws" {
  region = "ca-central-1"
}

###########################################################################
#
# Create a private elastic container registry
#
###########################################################################

resource "aws_ecr_repository" "private" {

  # General settings
  name                 = "william-private-ecr"
  image_tag_mutability = "MUTABLE"

  # Image scan settings
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encryption settings
  /*
  encryption_configuration {
    encryption_type =  # Valid values are AES256 or KMS
    kms_key =  # The ARN of the KMS key to use when encryption_type is KMS
  }
  */
}

###########################################################################
#
# Create a public elastic container registry
#
###########################################################################

resource "aws_ecrpublic_repository" "public" {
  count = 0
  
  # Detail
  repository_name = "william-pubic-ecr"

  catalog_data {
    about_text        = "demo public ecr created by terraform"
    architectures     = ["Linux"]
    operating_systems = ["x86-64"]
    description       = "Description"
    #logo_image_blob   = filebase64(image.png)
    usage_text        = "Usage Text"
  }
}

###########################################################################
#
# attach a permission to private repository
# aws console: amazon ecr->repository->choice a repository-> in left menu, permission
#
###########################################################################
data "aws_caller_identity" "current" {}

resource "aws_ecr_repository_policy" "private-policy" {
  repository = aws_ecr_repository.private.name

  policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "new statement",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchDeleteImage",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DeleteLifecyclePolicy",
        "ecr:DeleteRepository",
        "ecr:DeleteRepositoryPolicy",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetLifecyclePolicy",
        "ecr:GetLifecyclePolicyPreview",
        "ecr:GetRepositoryPolicy",
        "ecr:InitiateLayerUpload",
        "ecr:ListImages",
        "ecr:PutImage",
        "ecr:SetRepositoryPolicy",
        "ecr:StartLifecyclePolicyPreview",
        "ecr:UploadLayerPart",
        "ecr:PutLifecyclePolicy"
      ],
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "eks.amazonaws.com"
        ],
        "AWS": [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/admin_tf"
        ]
      }
    }
  ]
}
EOF
}

###########################################################################
#
# attach a lifecycle policy to private repository
# aws console: amazon ecr->repository->choice a repository-> in left menu, lifecycle policy
#
###########################################################################

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.private.name

  # Policy 1 on untagged images and policy 2 on tagged images
  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 14
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Keep last 30 images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["test"],
                "countType": "imageCountMoreThan",
                "countNumber": 30
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

###########################################################################
#
# attach a permission to Registries
# aws console: amazon ecr->registries->private->permission
#
###########################################################################

data "aws_region" "current" {}

data "aws_partition" "current" {}

resource "aws_ecr_registry_policy" "this" {
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "testpolicy",
        Effect = "Allow",
        Principal = {
          "AWS" : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = [
          "ecr:ReplicateImage"
        ],
        Resource = [
          "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
        ]
      }
    ]
  })
}

###########################################################################
#
# Create an Elastic Container Registry Replication Configuration.
#
###########################################################################

resource "aws_ecr_replication_configuration" "this" {
  count = 0
  replication_configuration {
    rule {
      destination {
        region      = "us-east-1"
        registry_id = data.aws_caller_identity.current.account_id
      }
    }
  }
}
