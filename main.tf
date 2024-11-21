provider "yandex" {
  zone = "ru-central1-b"
}

resource "yandex_compute_disk" "boot-disk-1" {
  name = "boot-disk-1"
  type = "network-hdd"
  #  zone     = "ru-central1-b"
  size     = "20"
  image_id = "fd82odtq5h79jo7ffss3"
}

resource "yandex_vpc_network" "otus-network" {
  name = "otus-network"
}

resource "yandex_vpc_subnet" "otus-subnet" {
  name           = "otus-subnet"
  network_id     = yandex_vpc_network.otus-network.id
  v4_cidr_blocks = ["10.16.0.0/24"]
}

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

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.nginx.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.nginx.network_interface.0.nat_ip_address
}
