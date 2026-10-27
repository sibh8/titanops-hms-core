#!/usr/bin/env python3
"""
TitanOps HMS - Dynamic Ansible Inventory Script for Terraform-provisioned Infrastructure
(TITANOPS-31 / TITANOPS-32 / TITANOPS-33)

This script parses Terraform outputs dynamically or falls back to environment variables
(BASTION_HOST, EC2_HOST, TARGET_ENV) to generate an Ansible-compliant inventory JSON.
"""

import sys
import os
import json
import subprocess
import argparse

def get_terraform_outputs(tf_dir):
    """Attempt to extract outputs from terraform working directory."""
    if not os.path.isdir(tf_dir):
        return {}
    try:
        cmd = ["terraform", "output", "-json"]
        out = subprocess.check_output(cmd, cwd=tf_dir, stderr=subprocess.DEVNULL)
        return json.loads(out.decode("utf-8"))
    except Exception:
        return {}

def build_inventory(tf_dir, target_env):
    tf_outputs = get_terraform_outputs(tf_dir)
    
    # Extract bastion / ec2 IP from Terraform output or env var
    bastion_ip = None
    if "bastion_private_ip" in tf_outputs and "value" in tf_outputs["bastion_private_ip"]:
        bastion_ip = tf_outputs["bastion_private_ip"]["value"]
    if not bastion_ip:
        bastion_ip = os.environ.get("BASTION_HOST", os.environ.get("EC2_HOST", "127.0.0.1"))

    # Extract EKS cluster name
    eks_cluster = "titanops-hms"
    if "eks_cluster_name" in tf_outputs and "value" in tf_outputs["eks_cluster_name"]:
        eks_cluster = tf_outputs["eks_cluster_name"]["value"]
    elif "EKS_CLUSTER_NAME" in os.environ:
        eks_cluster = os.environ["EKS_CLUSTER_NAME"]

    # Detect connection mode (local vs ssh)
    is_local = (bastion_ip in ["127.0.0.1", "localhost", ""])
    conn_type = "local" if is_local else "ssh"
    remote_user = os.environ.get("ANSIBLE_USER", "ec2-user" if "al2023" in os.environ.get("AMI_NAME", "al2023") else "ubuntu")
    ssh_key = os.environ.get("ANSIBLE_SSH_KEY_FILE", "~/.ssh/id_rsa")

    inventory = {
        "_meta": {
            "hostvars": {
                "localhost": {
                    "ansible_connection": "local",
                    "ansible_python_interpreter": "auto",
                    "target_environment": target_env,
                    "k8s_namespace": "hms",
                    "eks_cluster_name": eks_cluster
                },
                bastion_ip: {
                    "ansible_connection": conn_type,
                    "ansible_user": remote_user,
                    "ansible_ssh_private_key_file": ssh_key,
                    "ansible_ssh_common_args": "-o StrictHostKeyChecking=no",
                    "target_environment": target_env,
                    "k8s_namespace": "hms",
                    "eks_cluster_name": eks_cluster
                }
            }
        },
        "all": {
            "children": ["ec2", "bastion", "localhost_group"]
        },
        "ec2": {
            "hosts": [bastion_ip]
        },
        "bastion": {
            "hosts": [bastion_ip]
        },
        "localhost_group": {
            "hosts": ["localhost"]
        }
    }
    return inventory

def main():
    parser = argparse.ArgumentParser(description="TitanOps Dynamic Terraform-Ansible Inventory")
    parser.add_argument("--list", action="store_true", help="List active inventory in JSON")
    parser.add_argument("--host", help="Get host-specific variables")
    args = parser.parse_args()

    repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    tf_dir = os.path.join(repo_root, "terraform")
    target_env = os.environ.get("TARGET_ENV", "dev")

    inventory = build_inventory(tf_dir, target_env)

    if args.host:
        hostvars = inventory["_meta"]["hostvars"].get(args.host, {})
        print(json.dumps(hostvars, indent=2))
    else:
        print(json.dumps(inventory, indent=2))

if __name__ == "__main__":
    main()
