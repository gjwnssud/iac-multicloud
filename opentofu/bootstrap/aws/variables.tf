variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "bucket_name" {
  description = "tfstate를 저장할 S3 버킷 이름 (전역적으로 유일해야 함)"
  type        = string
}

variable "lock_table_name" {
  description = "state 잠금용 DynamoDB 테이블 이름"
  type        = string
  default     = "iac-multicloud-tfstate-lock"
}
