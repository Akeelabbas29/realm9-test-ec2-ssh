# realm9-test-ec2-ssh

Terraform project for testing Realm9 end-to-end with **the trickiest output pattern**: a sensitive multi-line PEM private key. After Realm9 applies, you should be able to SSH into the EC2 instance using only the credentials Realm9 surfaces — no AWS console needed.

## What it provisions

- `tls_private_key` (RSA 4096) generated at apply time
- `aws_key_pair` registered with the public key
- `aws_security_group` allowing inbound 22 from `var.allowed_ssh_cidr`
- `aws_instance` t3.micro running latest Amazon Linux 2023 (AMI looked up via SSM parameter, so always current)
- Uses the **default VPC** — assumes one exists in the target account
- Encrypted gp3 root volume, IMDSv2 enforced

## Inputs

| Variable | Default | Notes |
|----------|---------|-------|
| `aws_region` | `us-east-1` | |
| `project_name` | `realm9-test-ec2` | Used as a name prefix |
| `instance_type` | `t3.micro` | Free-tier eligible |
| `allowed_ssh_cidr` | `0.0.0.0/0` | Open by default — restrict for non-throwaway use |

A random pet suffix is appended to all resource names so the project can be applied multiple times in the same account.

## Outputs

| Output | Sensitive | Description |
|--------|-----------|-------------|
| `instance_id` | no | EC2 instance ID |
| `public_ip` | no | Public IPv4 |
| `public_dns` | no | Public DNS |
| `ssh_username` | no | `ec2-user` |
| `region` | no | AWS region |
| `key_name` | no | Key-pair name |
| `private_key_pem` | **yes** | Multi-line RSA private key |
| `ssh_command` | no | Pre-formatted ssh command |

## CLI verification flow

After Realm9 applies, copy the outputs (use the eye-icon reveal for `private_key_pem`):

```sh
# 1. Save the PEM — preserve the newlines
cat > /tmp/realm9-test.pem <<'EOF'
-----BEGIN RSA PRIVATE KEY-----
... full multi-line PEM here ...
-----END RSA PRIVATE KEY-----
EOF
chmod 600 /tmp/realm9-test.pem

# 2. SSH in
ssh -i /tmp/realm9-test.pem -o StrictHostKeyChecking=no ec2-user@<public_ip>

# 3. Inside the instance, prove it's real
hostname
whoami
uname -a
cat /etc/os-release | head -3
exit
```

After Realm9 destroys the project, run the SSH command again — should fail with `No route to host` or similar (instance gone, public IP released).

## Cost

`t3.micro` is **~$0.0104/hr** (~$7.50/mo if left running). Free-tier eligible if you have unused free-tier hours; otherwise it's small but non-zero. **Destroy after testing.**

## Security notes

- Default `allowed_ssh_cidr = 0.0.0.0/0` means anyone on the internet can attempt SSH. The PEM is your only barrier — don't reuse this configuration for anything but a throwaway test.
- IMDSv2 is enforced (`http_tokens = "required"`) — prevents SSRF-style metadata theft.
- Root volume is encrypted by default.
- The PEM is the most critical output — once revealed in Realm9, treat it as exposed and rely on `terraform destroy` to invalidate it.
