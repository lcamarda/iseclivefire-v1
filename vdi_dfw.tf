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


resource "nsxt_policy_context_profile" "SSLTLSV10" {
  display_name = "SSL_TLS_V10"
  description  = "Terraform provisioned ContextProfile"
  app_id {
    description = "ssl tls v1.0"
    value       = ["SSL"]
    sub_attribute {
      tls_version = ["TLS_V10"]
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
    display_name       = "Allow AD Traffic to/from domain controlleri L7"
    destination_groups = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    source_groups      = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    action             = "ALLOW"
    logged             = true
    profiles           = [data.nsxt_policy_context_profile.ACTIVDIR.path,data.nsxt_policy_context_profile.LDAP.path]
    log_label          = "activdir_l7"
  }

  rule {
    display_name       = "Allow AD Traffic to/from domain controller L4"
    destination_groups = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    source_groups      = [nsxt_policy_group.VDI.path, data.nsxt_policy_group.mgmt.path]
    action             = "ALLOW"
    logged             = true
    services           = [data.nsxt_policy_service.activdir.path]
    log_label          = "activdir_l4"
  }

  rule {
    display_name       = "Block SSL TLS v1.0"
    source_groups      = [nsxt_policy_group.VDI.path]
    action             = "REJECT"
    logged             = true
    profiles           = [nsxt_policy_context_profile.SSLTLSV10.path]
    log_label          = "TLS10"
  }

  rule {
    display_name       = "Allow newer TLS versions"
    source_groups      = [nsxt_policy_group.VDI.path]
    action             = "ALLOW"
    logged             = true
    profiles           = [data.nsxt_policy_context_profile.SSL.path]
    log_label          = "TLS-NEW"
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
