variable "name_prefix" {
  description = "리소스 그룹/스토리지 계정 이름 접두사. 스토리지 계정 이름은 소문자+숫자만 허용되어 하이픈이 제거된다"
  type        = string
  default     = "iacmulticloudtfstate"
}

variable "location" {
  description = "Azure 리전"
  type        = string
  default     = "koreacentral"
}
