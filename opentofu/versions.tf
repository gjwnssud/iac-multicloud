# 저장소 공통 OpenTofu 버전 제약.
# provider별 required_providers는 각 environments/{env}/versions.tf에서 개별 선언한다.
terraform {
  required_version = ">= 1.7.0"
}
