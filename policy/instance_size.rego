package main

# 비용 통제를 위한 인스턴스 타입 허용 목록.
# Phase 4에서 k3s+ArgoCD 구동 최소 스펙으로 정한 값들만 허용하고,
# PR에서 실수로 훨씬 큰(비싼) 타입으로 바뀌는 것을 차단한다.

allowed_aws_instance_types := {"t3.small", "t3.medium"}

allowed_gcp_machine_types := {"e2-small", "e2-medium"}

allowed_azure_vm_sizes := {"Standard_B1ms", "Standard_B2s"}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "aws_instance"
	not allowed_aws_instance_types[rc.change.after.instance_type]
	msg := sprintf("%s: 허용되지 않은 EC2 instance_type(%s)입니다. 허용 목록: %v", [rc.address, rc.change.after.instance_type, allowed_aws_instance_types])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "google_compute_instance"
	not allowed_gcp_machine_types[rc.change.after.machine_type]
	msg := sprintf("%s: 허용되지 않은 GCE machine_type(%s)입니다. 허용 목록: %v", [rc.address, rc.change.after.machine_type, allowed_gcp_machine_types])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "azurerm_linux_virtual_machine"
	not allowed_azure_vm_sizes[rc.change.after.size]
	msg := sprintf("%s: 허용되지 않은 Azure VM size(%s)입니다. 허용 목록: %v", [rc.address, rc.change.after.size, allowed_azure_vm_sizes])
}
