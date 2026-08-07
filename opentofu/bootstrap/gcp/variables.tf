variable "project" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "region" {
  description = "리전"
  type        = string
  default     = "asia-northeast3"
}

variable "bucket_name" {
  description = "tfstate를 저장할 GCS 버킷 이름 (전역적으로 유일해야 함)"
  type        = string
}
