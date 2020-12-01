provider "nsxt" {
  host                  = "192.168.110.15"
  username              = "admin"
  password              = "VMware1!VMware1!"
  allow_unverified_ssl  = true
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}

resource "nsxt_policy_group" "DEV" {
  nsx_id       = "DEV"
  display_name = "DEV"
  criteria {
    condition {
      member_type = "VirtualMachine"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "env|dev"
    }
  }
}

resource "nsxt_policy_group" "PRD" {
  nsx_id       = "PRD"
  display_name = "PRD"
  criteria {
    condition {
      member_type = "VirtualMachine"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "env|prod"
    }
  }
}


resource "nsxt_policy_vm_tags" "drupal-dev" {
  instance_id = data.nsxt_policy_vm.drupal-dev.instance_id

  tag {
    scope = "env"
    tag   = "dev"
  }

  tag {
    scope = "app"
    tag   = "drupal"
  }
}


data "nsxt_policy_vm" "drupal-dev" {
  display_name = "drupal-dev"
}


resource "nsxt_policy_vm_tags" "couchdb-dev" {
  instance_id = data.nsxt_policy_vm.couchdb-dev.instance_id

  tag {
    scope = "env"
    tag   = "dev"
  }

  tag {
    scope = "app"
    tag   = "couchdb"
  }
}

data "nsxt_policy_vm" "couchdb-dev" {
  display_name = "couchdb-dev"
}

resource "nsxt_policy_vm_tags" "couchdb-prd" {
  instance_id = data.nsxt_policy_vm.couchdb-prd.instance_id

  tag {
    scope = "env"
    tag   = "prod"
  }

  tag {
    scope = "app"
    tag   = "couchdb"
  }
}


data "nsxt_policy_vm" "couchdb-prd" {
  display_name = "couchdb-prd"
}
