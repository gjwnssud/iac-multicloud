terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # opentofu/bootstrap/aws를 먼저 apply해 S3 버킷+DynamoDB 테이블을 만든 뒤
  # partial config로 연결한다 (bucket/key/region/dynamodb_table을
  # -backend-config 플래그 또는 backend.hcl로 주입, CI는 plan.yml/deploy.yml 참고):
  #   tofu init -backend-config="bucket=<bootstrap output>" \
  #             -backend-config="key=aws/terraform.tfstate" \
  #             -backend-config="region=ap-northeast-2" \
  #             -backend-config="dynamodb_table=<bootstrap output>"
  backend "s3" {}
}
