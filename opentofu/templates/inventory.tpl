[k3s_servers]
%{ for ip in server_ips ~}
${ip} ansible_user=${ssh_username}${ssh_private_key_path != "" ? " ansible_ssh_private_key_file=${ssh_private_key_path}" : ""}
%{ endfor ~}

[k3s_agents]
%{ for ip in agent_ips ~}
${ip} ansible_user=${ssh_username}${ssh_private_key_path != "" ? " ansible_ssh_private_key_file=${ssh_private_key_path}" : ""}
%{ endfor ~}

[k3s_cluster:children]
k3s_servers
k3s_agents
