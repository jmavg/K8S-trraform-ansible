resource "oci_identity_compartment" "tf-K8S" {
    compartment_id = var.tenancy_ocid
    description = "Compartment for Terraform created K8S ressources."
    name = "tf-K8S"
}


module "vcn" {
  source  = "oracle-terraform-modules/vcn/oci"
  version = "3.5.3"
  
  compartment_id = oci_identity_compartment.tf-K8S.id

  create_internet_gateway = true
  internet_gateway_display_name = "tf-K8S-Gateway"
  vcn_cidrs = ["10.202.0.0/16"]
  vcn_name = "tf-K8S-VCN"
  region = var.region_identifier
}

resource "oci_core_security_list" "tf-K8S-sl"{
  compartment_id = oci_identity_compartment.tf-K8S.id
  vcn_id = module.vcn.vcn_id
  display_name = "tf-K8S-sl"
  egress_security_rules {
      stateless = false
      destination = "0.0.0.0/0"
      destination_type = "CIDR_BLOCK"
      protocol = "all" 
  }

  ingress_security_rules { 
      stateless = false
      source = "0.0.0.0/0"
      source_type = "CIDR_BLOCK"
      protocol = "6"
      tcp_options { 
          min = 22
          max = 22
      }
    }
}

resource "oci_core_subnet" "tf-K8S"{
  compartment_id = oci_identity_compartment.tf-K8S.id
  vcn_id = module.vcn.vcn_id
  cidr_block = "10.202.1.0/24"
  route_table_id = module.vcn.ig_route_id
  security_list_ids = [oci_core_security_list.tf-K8S-sl.id]
  display_name = "tf-K8S-public-subnet"
}


resource "oci_core_instance" "tf-K8S" {
    availability_domain = "TbYp:MX-QUERETARO-1-AD-1"
    compartment_id = oci_identity_compartment.tf-K8S.id
    shape = "VM.Standard.E2.1.Micro"
    source_details {
        source_id = "ocid1.image.oc1.mx-queretaro-1.aaaaaaaaeh6eyfnoegpnmmzbbt5ftgzrlkb7olhajeyxtx5gaaiy3a4yzeva"
        source_type = "image"
    }

    display_name = "tf-K8S-instance"
    create_vnic_details {
        assign_public_ip = true
        subnet_id = oci_core_subnet.tf-K8S.id
    }
    metadata = {
        ssh_authorized_keys = file(var.public_key_path)
    } 
    preserve_boot_volume = false
}
