## Simple PoC project that deploys the official Vault helm chart and configures the Vault server for usage in AWS EKS
-----

![Vault Logo](https://github.com/hashicorp/vault/raw/f22d202cde2018f9455dec755118a9b84586e082/Vault_PrimaryLogo_Black.png)


### What is it: 
  This project utilizes already existing EKS AWS cluster to deploy the official Vault Helm chart, setup AWS IRSA accounts for Vault AWS auth method, Vault AWS secrets engine and auto Seal/Unseal functionality. 
  In addition to above-mentioned setup, a consuming Pod named `consume-pod` is created, which can authenticate to the Vault server effortlessly simply via `vault login -method=aws` command.

### Simple diagram:
![Diagram](https://lucid.app/publicSegments/view/ebb116c7-90e4-4920-a344-ff3d584e8d1d/image.png)

### Prerequisites:
  - Having AWS account with preinstalled AWS EKS cluster
  - Terraform v1.8.2 or higher
  - A Terraform Github repository which resembles [this](https://github.com/martinhristov90/vault-aws-eks-irsa), containing Vault TF provider resources to be deployed on the Vault server. The mentioned repository can be used as boilerplate.

### Usage:
  - Clone the repository: `git clone https://github.com/martinhristov90/vault-aws-eks-irsa`.
  - Change into its directory: `cd vault-aws-eks-irsa`.
  - Create `terraform.tfvars` file, example of how it should look like can be found below. 
  - Make sure that you are already authenticated to the K8S cluster and you have the desired K8S context set as "current", you can do this with `kubectl config current-context` and `kubectl get pods`(example) commands.
  - Initialize Terraform providers: `terraform init`.
  - Execute Terraform plan and apply: `terraform plan` and `terraform apply`.
  - Terraform logs will be printed at `stdout` of `0`th Pod of Vault's StatefulSet.
  - For establishing sessions with the Vault server and `consume-pod`, `kubectl exec...` command can be utilized or 3rd party tools, such as [k9s](https://github.com/derailed/k9s).
### `terraform.tfvars` explanation and example:

  | Variable | Example | Meaning |
  | :--- | :---- | :--- |
  |k8s_cluster_name| k8s-training-martin|Name of EKS AWS kubernetes cluster, already deployed in AWS|
  |aws_region|eu-central-1|AWS region where the EKS cluster is deployed|
  |sa_name|vault-server|Name of K8S SA used by the Vault server Pods|
  |sa_namespace|vault|K8S namespace where the Vault server should be deployed, must be pre-existent|
  |consume_pod_namespace|default|K8S namespace where the consume Pod should be deployed, usually default|
  |vault_helm_chart_version|0.28.0|Version of the official Vault Helm chart to be used|
  |DEMOROLE_POLICY_ARN|arn:aws:iam::ACCOUNT_ID_HERE:policy/DemoUser|ARN of Policy used the Vault's AWS secrets engine to create demo IAM users, that policy usually preexists with all Doormat accounts. Specifies the [policy_arns](https://developer.hashicorp.com/vault/api-docs/secret/aws#policy_arns) parameter for `iam_user` type role|
  |DEMOROLE_ROLE_ARN|arn:aws:iam::ACCOUNT_ID_HERE:role/vault-assumed-role-credentials-demo|Name of the AWS IAM role used to create STS credentials by the Vault's AWS secrets engine. Specifies the [role_arns](https://developer.hashicorp.com/vault/api-docs/secret/aws#role_arns) parameter for `assumed_role` type role |
  |INFERRED_AWS_REGION|us-east-2|Specifies [inferred_aws_region](https://developer.hashicorp.com/vault/api-docs/auth/aws#inferred_aws_region) parameter of AWS auth method (EC2 type)|
  |BOUND_VPC_IDS|vpc-0575842261fba092a|Specifies the [bound_vpc_id](https://developer.hashicorp.com/vault/api-docs/auth/aws#bound_vpc_id) parameter for AWS auth method (EC2 type)|
  |git_repository|https://github.com/martinhristov90/terraform-aws-k8s-vault-setup|Git repository used containing Terraform configuration for provisioning the Vault server, AWS auth, AWS secrets, etc.|

#### Example `terraform.tfvars` file:
  ```
  k8s_cluster_name         = "k8s-training-martin"
  aws_region               = "eu-central-1"
  sa_name                  = "vault-server"
  sa_namespace             = "vault"
  consume_pod_namespace    = "default"
  vault_helm_chart_version = "0.28.0"
  DEMOROLE_POLICY_ARN      = "arn:aws:iam::1<SNIP>33:policy/DemoUser"
  DEMOROLE_ROLE_ARN        = "arn:aws:iam::1<SNIP>33:role/vault-assumed-role-credentials-demo"
  INFERRED_AWS_REGION      = "us-east-2"
  BOUND_VPC_IDS            = "vpc-057<SNIP>1fba092a"
  git_repository           = "https://github.com/martinhristov90/terraform-aws-k8s-vault-setup"
  ```

-----

### How to consume this environment (consume-pod side):
- After setting up correctly the `terraform.tfvars` file and executing `terraform apply` command, in the EKS are deployed three Vault server Pods (part of StatefulSet) as well as consuming Pod for Vault secrets named `consume-pod`.
- To verify the running Vault pods - `kubectl get pods -l component=server -n vault`:
```
kubectl get pods -l component=server -n vault
NAME                         READY   STATUS    RESTARTS   AGE
vault-server-joint-racer-0   1/1     Running   0          3h
vault-server-joint-racer-1   1/1     Running   0          3h
vault-server-joint-racer-2   1/1     Running   0          3h
```
- To verify the running `consume-pod` - `kubectl get pods consume-pod -n default`:
```
kubectl get pods consume-pod -n default
NAME          READY   STATUS    RESTARTS   AGE
consume-pod   1/1     Running   0          3h2m
```
- Execute a session on `consume-pod` Pod:
```
kubectl exec -it consume-pod -- /bin/sh
```
- Login to Vault server without providing any additional parameters to the `vault login -method=aws` command (VAULT_ADDR is preset):
``` kubectl exec -it consume-pod -- /bin/sh
/ # vault login -method=aws
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                      Value
---                      -----
token                    hvs.CAESIO7u1UPzAGfqBh3-A<SNIP>MG1XRzAzbFhyaEFqSWhiSzc
token_accessor           nE1eOun6WoHk89iSeh1td7At
token_duration           1m
token_renewable          true
token_policies           ["aws-secrets" "default"]
identity_policies        []
policies                 ["aws-secrets" "default"]
token_meta_account_id    123361688033
token_meta_auth_type     iam
token_meta_role_id       38bfc32a-4276-df35-a798-bd23336446e9
```
- Request a demo `iam_type` role via AWS secrets engine:
```
 vault read aws/creds/demo_aws_secrets_role
Key                Value
---                -----
lease_id           aws/creds/demo_aws_secrets_role/sxrZGgEWa<SNIP>9Cd5jw
lease_duration     768h
lease_renewable    true
access_key         AKIA<SNIP>
secret_key         Rou4j<SNIP>HRLvC
security_token     <nil>
```
- Request `assumed_role` role via AWS secrets engine:
```
 vault read aws/creds/demo_aws_secrets_role_assumed_role
Key                Value
---                -----
lease_id           aws/creds/demo_aws_secrets_role_assumed_role/rTRWSe<SNIP>ANhIAYm
lease_duration     15m
lease_renewable    false
access_key         ASI<SNIP>Z5P
arn                arn:aws:sts::12<SNIP>33:assumed-role/vault-assumed-role-credentials-demo/vault-aws-consume-pod-role-joint-racer_171439663-1714396688-yD6O
secret_key         56+jZZLtC<SNIP>i/f1N
security_token     IQoJb3J<SNIP>+wFU3ApNoTxVf6QmvfT6i6PGhwrTCQvL6xBjqeAdHYe1V/Sb8g+zbrw+KpKzmJuC+oLTfcZ+gTnZMaFR2mLDSN87swkxRNSH/EoB/6dB/srj0poG0XFNVX3ijjbxROIQicKzDUXgFnP46nniKKsDJJ1aUofR3onANOxSMDHlAZDNkSa5XLyMV+P9ECfl21PHRSrZjUrR+HFwBARzcTih1wPEfxk5M+UqQ8/RQXFlCqvD94H5ZjHnQZGFaR
```
### How to consume this environment (Vault server side):
- Vault root key and recovery keys are stored within the environment the `0` Pod of the Stateful set as well as K8S secret named `vault-root-creds` in the desired namespace. Can be sourced from either location.
- Fetching root key and unseal keys from the K8S secret:
```
base64 -d <<< $(kubectl get secret vault-root-creds -n vault -o json | jq -r .data.root_token)
base64 -d <<< $(kubectl get secret vault-root-creds -n vault -o json | jq -r .data.recovery_key)
```
- As already mentioned upon establishing a session to Pod `0`, Vault is already unsealed and `root` token is set to the environment and ready to be used:
    - Expected `vault status -format=json` output:
        ```json
        {
          "type": "awskms",
          "initialized": true,
          "sealed": false,
          "t": 1,
          "n": 1,
          "progress": 0,
          "nonce": "",
          "version": "1.15.4",
          "build_date": "2023-12-04T17:45:28Z",
          "migration": false,
          "cluster_name": "vault-cluster-6c15b226",
          "cluster_id": "56311cd5-0db2-3efb-230d-65bb083846ae",
          "recovery_seal": true,
          "recovery_seal_type": "shamir",
          "storage_type": "raft",
          "ha_enabled": true,
          "is_self": true,
          "active_time": "2024-04-29T10:10:43.050455939Z",
          "leader_address": "http://192.168.69.198:8200",
          "leader_cluster_address": "https://vault-server-joint-racer-0.vault-server-joint-racer-internal:8201",
          "raft_committed_index": 315,
          "raft_applied_index": 315
        }
        ```
    - Expected `vault token lookup -format=json` output:
        ```
        {
          "request_id": "c174d0d0-a69c-9dd1-8f28-ded0e7a8a378",
          "lease_id": "",
          "lease_duration": 0,
          "renewable": false,
          "data": {
            "accessor": "S9Cjq7nOslAvEdeedjiKLyuE",
            "creation_time": 1714385442,
            "creation_ttl": 0,
            "display_name": "root",
            "entity_id": "",
            "expire_time": null,
            "explicit_max_ttl": 0,
            "id": "hvs.sIbHXfxZ9ODrwColBynGNLZm",
            "meta": null,
            "num_uses": 0,
            "orphan": true,
            "path": "auth/token/root",
            "policies": [
              "root"
            ],
            "ttl": 0,
            "type": "service"
          },
          "warnings": null
        }
- Further configurations can be made to the Vault server utilizing the `root` token or subsequently issued child tokens.
-----
### TODO:
  - [ ] Configure optional Ingress resource + cert 
### License:
  - [MIT](https://choosealicense.com/licenses/mit/)