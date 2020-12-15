terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
      version = "3.1.0"
    }
  }
}

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


data "nsxt_policy_tier1_gateway" "t1-internal" {
  display_name = "T1-INTERNAL"
}

data "nsxt_policy_group" "mgmt" {
  display_name = "MGMT"
}

resource "nsxt_policy_group" "dmz" {
  nsx_id       = "DMZ"
  display_name = "DMZ"
  criteria {
    condition {
      member_type = "Segment"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "zone|dmz"
    }
  }
}

resource "nsxt_policy_group" "internal" {
  nsx_id       = "INTERNAL"
  display_name = "INTERNAL"
  criteria {
    condition {
      member_type = "Segment"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "zone|internal"
    }
  }
}

resource "nsxt_policy_service" "couchdb" {
  display_name = "couchdb"

  l4_port_set_entry {
    display_name      = "TCP5984"
    description       = "TCP port 5984 entry"
    protocol          = "TCP"
    destination_ports = ["5984"]
  }
}

resource "nsxt_policy_gateway_policy" "InternalZone" {
  display_name    = "Macro Segmentation for Internal Zone"
  category        = "LocalGatewayRules"
  locked          = false
  sequence_number = 1
  stateful        = true
  tcp_strict      = true

  rule {
    display_name       = "Allow Management"
    source_groups      = [data.nsxt_policy_group.mgmt.path]
    action             = "ALLOW"
    logged             = true
    scope              = [data.nsxt_policy_tier1_gateway.t1-internal.path]
  }

  rule {
    display_name       = "Allow DMZ"
    source_groups      = [nsxt_policy_group.dmz.path]
    services           = [nsxt_policy_service.couchdb.path]
    action             = "ALLOW"
    logged             = true
    scope              = [data.nsxt_policy_tier1_gateway.t1-internal.path]
  }


  rule {
    display_name       = "Allow Outbound"
    source_groups      = [nsxt_policy_group.internal.path]
    action             = "ALLOW"
    logged             = true
    scope              = [data.nsxt_policy_tier1_gateway.t1-internal.path]
  }

 rule {
    display_name       = "Block the Rest Inbound"
    action             = "REJECT"
    logged             = true
    scope              = [data.nsxt_policy_tier1_gateway.t1-internal.path]
  }


}
