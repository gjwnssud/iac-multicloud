package main

# tofu plan JSON(resource_changes)을 대상으로 SSH(22)를 0.0.0.0/0에 여는
# 보안 그룹/방화벽 규칙을 차단한다. allowed_ssh_cidrs 변수를 실수로
# 0.0.0.0/0으로 설정하는 경우를 PR 단계에서 잡아내기 위함.

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "aws_security_group"
	ingress := rc.change.after.ingress[_]
	ingress.from_port <= 22
	ingress.to_port >= 22
	cidr := ingress.cidr_blocks[_]
	cidr == "0.0.0.0/0"
	msg := sprintf("%s: SSH(22)를 0.0.0.0/0에 허용하는 AWS 보안 그룹 규칙이 있습니다", [rc.address])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "google_compute_firewall"
	rc.change.after.direction == "INGRESS"
	cidr := rc.change.after.source_ranges[_]
	cidr == "0.0.0.0/0"
	allow := rc.change.after.allow[_]
	port := allow.ports[_]
	port == "22"
	msg := sprintf("%s: SSH(22)를 0.0.0.0/0에 허용하는 GCP 방화벽 규칙이 있습니다", [rc.address])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "azurerm_network_security_group"
	rule := rc.change.after.security_rule[_]
	rule.direction == "Inbound"
	rule.access == "Allow"
	is_wide_open_source(rule)
	covers_ssh_port(rule)
	msg := sprintf("%s: SSH(22)를 전체 대역에 허용하는 NSG 규칙(%s)이 있습니다", [rc.address, rule.name])
}

is_wide_open_source(rule) if {
	rule.source_address_prefix == "*"
}

is_wide_open_source(rule) if {
	rule.source_address_prefix == "0.0.0.0/0"
}

is_wide_open_source(rule) if {
	some i
	rule.source_address_prefixes[i] == "0.0.0.0/0"
}

covers_ssh_port(rule) if {
	rule.destination_port_range == "22"
}

covers_ssh_port(rule) if {
	rule.destination_port_range == "*"
}

covers_ssh_port(rule) if {
	some i
	rule.destination_port_ranges[i] == "22"
}
