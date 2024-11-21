### OTUS High Load Lesson #03 | Subject: Практическое использование Terraform
--------------

#### ЦЕЛЬ: Создать первый terrafom-скрипт

-----------
#### НЕОБХОДИМО:
1. Реализовать терраформ для разворачивания одной виртуальной машины в Yandex-cloud
2. Установить Nginx с помощью Ansible
   
-----------
#### КРИТЕРИИ ОЦЕНКИ: 
Преподаватель с помощью terraform apply должен получить развернутый стенд

----------
#### ВЫПОЛНЕНИЕ

Регистрируемся на Yandex Cloud и настраиваем окружение по [инструкции](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-quickstart)

Для связки Ansible и Terraform используем [Ansible Provider](https://registry.terraform.io/providers/ansible/ansible/latest/docs). 
В Terraform подключаем данный provider в файле `provider.tf`:
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

Описываем параметры ресурсов в файле `main.tf`. 

Указываем зону по умолчанию:
```
provider "yandex" {
  zone = "ru-central1-b"
}
```
Создаем диск для нашей виртуальной машины:
```
resource "yandex_compute_disk" "boot-disk-1" {
  name = "boot-disk-1"
  type = "network-hdd"
  #  zone     = "ru-central1-b"
  size     = "20"
  image_id = "fd82odtq5h79jo7ffss3"
}
```
Создаем подсеть для нашей виртуальной машины:
```
resource "yandex_vpc_network" "otus-network" {
  name = "otus-network"
}

resource "yandex_vpc_subnet" "otus-subnet" {
  name           = "otus-subnet"
  network_id     = yandex_vpc_network.otus-network.id
  v4_cidr_blocks = ["10.16.0.0/24"]
}
```
Создаем виртуальную машину:
```
resource "yandex_compute_instance" "nginx" {
  name = "nginx"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.otus-subnet.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}
```
Здесь, в metadata указан пользователь, для которого нужно загрузить публичный ключ. По умолчанию, в яндексе для образов Ubuntu создается пользователь __ubuntu__.

Описываем ресурс для выполения ansible плейбука:
```
resource "ansible_playbook" "webserver_provision" {
  playbook = "playbook.yml"

  #inventory configuration
  name   = yandex_compute_instance.nginx.name
  groups = ["webservers"]

  # Limit this playbook to run only in the host named "nginx"
  limit = [yandex_compute_instance.nginx.name]

  extra_vars = {
    ansible_host                 = yandex_compute_instance.nginx.network_interface.0.nat_ip_address,
    ansible_user                 = "ubuntu",
    ansible_ssh_private_key_file = "~/.ssh/id_ed25519",
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
  }

  replayable = true
  verbosity  = 3 # set the verbosity level of the debug output for this playbook
}
```
Ссылки на примеры использования Ansible Provider - [раз](https://github.com/ansible/terraform-provider-ansible), [два](https://github.com/ansible/terraform-provider-ansible/blob/main/examples/ansible_playbook/end-to-end.tf). 

Выводим внутренний и внешний ip нашей виртуальной машины: 
```
output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.nginx.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.nginx.network_interface.0.nat_ip_address
}
```
Описываем playbook, который будет автоматически выполняться после создания виртуальной машины:
```
---

- name: Configure webserver 
  hosts: nginx
  gather_facts: no
  become: yes

  tasks:

  - name: Wait for system to become reachable
    ansible.builtin.wait_for_connection:

  - name: Gather facts manually
    ansible.builtin.setup:

  - name: Set a hostname
    ansible.builtin.hostname:
      name: nginx

  - name: Install nginx
    ansible.builtin.apt:
      name: nginx
      state: present
      update_cache: yes
```
Terraform пытается сразу запустить playbook после создания ресурса. Но так как сама машина еще не испевает подняться, то Ansible будет выкидывать ошибку соединения. Поэтому мы создаем таск `wait_for_connection`, который будет ждать пока машина поднимется. Для этих же целей мы в начале отключаем сбор фактов и запускаем ручной сбор уже после того как машина стала доступна.

---------------
#### РЕЗУЛЬТАТ
Для развёртывания стенда выполняем:
```
terraform apply
```
Terraform создаст нужные ресурсы и запустит ansible playbook для настройки виртуальной машины
