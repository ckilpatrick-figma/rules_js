resource "google_compute_network" "workflows_network" {
  name                    = "workflows-network"
  project                 = local.project
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "workflows_subnet" {
  name          = "workflows-subnet"
  project       = local.project
  region        = local.region
  ip_cidr_range = "10.2.0.0/16"
  network       = google_compute_network.workflows_network.id
}

resource "google_compute_firewall" "ssh" {
  name        = "allow-ssh"
  project     = local.project
  description = "Enable SSHing into VM instances"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.workflows_network.id
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_router" "router" {
  name    = "router"
  project = local.project
  region  = local.region
  network = google_compute_network.workflows_network.id

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "router-nat"
  project                            = local.project
  region                             = local.region
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  # Allow the ports assigned to each VM scale up and down as needed
  # https://cloud.google.com/nat/docs/ports-and-addresses#dynamic-port
  enable_dynamic_port_allocation = true
  # Must be disabled when dynamic port allocation is enabled (default is true)
  enable_endpoint_independent_mapping = false
  # The min number of ports can be tuned by monitoring port usage:
  # https://cloud.google.com/nat/docs/tune-nat-configuration#choose-minimum
  min_ports_per_vm = 32
}
