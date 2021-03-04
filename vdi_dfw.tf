resource "nsxt_policy_group" "EXECS" {
  display_name = "EXECS"

  extended_criteria {
    identity_group {
      distinguished_name             = "CN=EXECS,CN=Users,DC=corp,DC=local"
      domain_base_distinguished_name = "dc=corp,dc=local"
    }
  }
}

resource "nsxt_policy_group" "IT" {
  display_name = "IT"

  extended_criteria {
    identity_group {
      distinguished_name             = "CN=IT,CN=Users,DC=corp,DC=local"
      domain_base_distinguished_name = "dc=corp,dc=local"
    }
  }
}

resource "nsxt_policy_group" "VDI" {
  nsx_id       = "VDI"
  display_name = "VDI"
  criteria {
    condition {
      member_type = "Segment"
      key         = "Tag"
      operator    = "EQUALS"
      value       = "zone|vdi"
    }
  }
  conjunction {
    operator = "OR"
  }
  criteria {
    condition {
      key         = "Name"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "win10-01a"
    }
  }
}

resource "nsxt_policy_service" "vdi_ssl" {
  description  = "L4 ports service provisioned by Terraform"
  display_name = "vdi_ssl_ports"

  l4_port_set_entry {
    display_name      = "browsing_via_ssl"
    protocol          = "TCP"
    destination_ports = ["443","1010","1011","1012"]
  }
}

data "nsxt_policy_context_profile" "ACTIVDIR" {
  display_name = "ACTIVDIR"
}

data "nsxt_policy_context_profile" "LDAP" {
  display_name = "LDAP"
}

data "nsxt_policy_context_profile" "DNS" {
  display_name = "DNS"
}

data "nsxt_policy_context_profile" "SSL" {
  display_name = "SSL"
}

data "nsxt_policy_context_profile" "DCERPC" {
  display_name = "DCERPC"
}

resource "nsxt_policy_context_profile" "SSLTLSV10V11" {
  display_name = "SSL_TLS_V10_V11"
  description  = "Terraform provisioned ContextProfile"
  app_id {
    description = "ssl tls v1.0, v1.1"
    value       = ["SSL"]
    sub_attribute {
      tls_version = ["TLS_V10","TLS_V11"]
    }
  }
}


data "nsxt_policy_service" "dns" {
  display_name = "DNS"
}


data "nsxt_policy_service" "activdir" {
  display_name = "Microsoft Active Directory V1"
}


data "nsxt_policy_service" "dns-udp" {
  display_name = "DNS-UDP"
}

data "nsxt_policy_service" "http" {
  display_name = "HTTP"
}

data "nsxt_policy_service" "https" {
  display_name = "HTTPS"
}

data "nsxt_policy_service" "ldap" {
  display_name = "LDAP"
}

data "nsxt_policy_service" "MS_RPC_TCP" {
  display_name = "MS_RPC_TCP"
}

data "nsxt_policy_service" "MS_RPC_UDP" {
  display_name = "MS_RPC_UDP"
}


resource "nsxt_policy_security_policy" "vdi" {
  display_name = "vdi policy"
  description  = "Control VDi traffic"
  category     = "Environment"
  locked       = false
  stateful     = true
  tcp_strict   = true
  scope        = [nsxt_policy_group.VDI.path]

   rule {
    display_name       = "DNS Inspection"
    source_groups      = [nsxt_policy_group.VDI.path]
    destination_groups = [data.nsxt_policy_group.mgmt.path]
    action             = "ALLOW"
    logged             = true
    services           = [data.nsxt_policy_service.dns-udp.path, data.nsxt_policy_service.dns.path]
    profiles           = [data.nsxt_policy_context_profile.DNS.path]
  }

  rule {
    display_name       = "Identity FW rule: Block EXEC to badssl.com (additional manual configuration is required)"
    source_groups      = [nsxt_policy_group.EXECS.path]
    action             = "REJECT"
    logged             = true
    log_label          = "exec"
  }

  rule {
    display_name       = "Allow MS_RPC Traffic to/from domain controller L7"
    destination_groups = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    source_groups      = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    action             = "ALLOW"
    logged             = true
    profiles           = [data.nsxt_policy_context_profile.DCERPC.path]
    services           = [data.nsxt_policy_service.MS_RPC_TCP.path, data.nsxt_policy_service.MS_RPC_UDP.path]
    log_label          = "msrpc_l7"
  }

  rule {
    display_name       = "Allow LDAP Traffic to/from domain controller L7"
    destination_groups = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    source_groups      = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    action             = "ALLOW"
    logged             = true
    profiles           = [data.nsxt_policy_context_profile.LDAP.path]
    services           = [data.nsxt_policy_service.ldap.path]
    log_label          = "ldap_l7"
  }

  rule {
    display_name       = "Allow AD Traffic to/from domain controlleri L7"
    destination_groups = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    source_groups      = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    action             = "ALLOW"
    logged             = true
    profiles           = [data.nsxt_policy_context_profile.ACTIVDIR.path]
    log_label          = "activdir_l7"
  }

  rule {
    display_name       = "Allow AD + LDAP Traffic to/from domain controller L4"
    destination_groups = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    source_groups      = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    action             = "ALLOW"
    logged             = true
    services           = [data.nsxt_policy_service.activdir.path]
    log_label          = "activdir_l4"
  }

  rule {
    display_name       = "Block SSL TLS v1.0 and v1.1"
    source_groups      = [nsxt_policy_group.VDI.path]
    action             = "REJECT"
    logged             = true
    profiles           = [nsxt_policy_context_profile.SSLTLSV10V11.path]
    log_label          = "TLS10_11"
    services           = [nsxt_policy_service.vdi_ssl.path]

  }

  rule {
    display_name       = "Allow newer TLS versions"
    source_groups      = [nsxt_policy_group.VDI.path]
    action             = "ALLOW"
    logged             = true
    profiles           = [data.nsxt_policy_context_profile.SSL.path]
    log_label          = "TLS-NEW"
    services           = [nsxt_policy_service.vdi_ssl.path]
  }

  rule {
    display_name       = "Allow Outbound HTTP"
    source_groups      = [nsxt_policy_group.VDI.path]
    action             = "ALLOW"
    logged             = true
    services           = [data.nsxt_policy_service.http.path]
  }

   rule {
    display_name       = "Block Unnecessary Connectivity"
    action             = "REJECT"
    logged             = true
  }
}

