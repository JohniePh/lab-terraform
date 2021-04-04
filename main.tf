provider "google" {
  project = "TF_VAR_GOOGLE_CLOUD_PROJECT"
  zone    = "europe-west1-b"
}


resource "google_compute_network" "nat-example" {
  name = "nat-example"  
  project = "TF_VAR_GOOGLE_CLOUD_PROJECT"
  mtu  = 1460
  routing_mode = "REGIONAL"
  auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "some-subnet" {
  name          = "some-subnet"
  region        = "europe-west1"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.nat-example.id
}


resource "google_compute_firewall" "allow-internal-example" {
  name    = "allow-internal-example"
  network = google_compute_network.nat-example.name

  source_ranges = ["10.0.1.0/24"]
  priority = 65534

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }

}


resource "google_compute_firewall" "allow-ssh-iap" {
  name    = "allow-ssh-iap"
  network = google_compute_network.nat-example.name
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags = ["allow-ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

}


resource "google_compute_instance" "example-instance" {
  name         = "example-instance"
  machine_type = "f1-micro"
  zone         = "europe-west1-b"

  tags = ["no-ip", "allow-ssh"]

  boot_disk {
    initialize_params {
      image = "centos-7/centos-cloud"
    }
  }

  network_interface {
    subnetwork = "some-subnet"
  }
}


resource "google_compute_instance" "nat-gateway" {
  name         = "nat-gateway"
  machine_type = "f1-micro"
  zone         = "europe-west1-b"

  can_ip_forward  = true

  tags = ["nat", "allow-ssh"]

  boot_disk {
    initialize_params {
      image = "centos-7/centos-cloud"
    }
  }

  network_interface {
    subnetwork = "some-subnet"
    access_config {
    }
  }

  metadata = {
  	startup-script = "#! /bin/bash sudo sh -c \"echo 1 > /proc/sys/net/ipv4/ip_forward\" sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
  }
}


resource "google_compute_route" "no-ip-internet-route" {
  name        = "no-ip-internet-route"
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.nat-example.name
  
  next_hop_instance = "nat-gateway"
  next_hop_instance_zone = "europe-west1-b"

  tags = ["no-ip"]
  priority = 800
}
