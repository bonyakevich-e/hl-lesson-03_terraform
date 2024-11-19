# hl-lesson-03_terraform
OTUS High Load Lesson #03 | Subject: Практическое использование Terraform

Для связки Ansible и Terraform используем Ansible Provider (https://registry.terraform.io/providers/ansible/ansible/latest/docs). 
В Terraform подключаем данный provider:
```
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    ansible = {
      source = "ansible/ansible"
    }
  }
  required_version = ">= 0.13"
}
```
Для Ansible устанавливаем collection `cloud.terraform`:
```
$ ansible-galaxy collection install cloud.terraform
```
