variable apigee_org_id {
  type = string
}

variable google_access_token {
  type = string
}

variable proxy_name {
  type = string
  default = "example"
}

variable base_path {
  type = string
  default = "example"
}

variable target_url {
  type = string
  default = "https://example.com"
}

variable environment_name {
  type = string
  default = "test-env"
}

variable sed_command {
  default = "sed"
}

terraform {
  required_providers {
    apigee = {
      source  = "scastria/apigee"
      version = "~> 0.1.0"
    }
  }
}

provider "apigee" {
  organization = var.apigee_org_id
  access_token = var.google_access_token
  server       = "apigee.googleapis.com"
}

resource "null_resource" "create_proxy_dir" {
  provisioner "local-exec" {  
    command = "rm -rf apiproxy_dir 2> /dev/null && cp -r ${path.module}/proxy_template ${path.module}/apiproxy_dir"
  }

  provisioner "local-exec" {
    command = "${var.sed_command} -i 's|{{base_path}}|${var.base_path}|g' ${path.module}/apiproxy_dir/apiproxy/proxies/default.xml"
  }

  provisioner "local-exec" {
    command = "${var.sed_command} -i 's|{{target_url}}|${var.target_url}|g' ${path.module}/apiproxy_dir/apiproxy/targets/default.xml"
  }

  provisioner "local-exec" {
    command = "${var.sed_command} -i 's|{{proxy_name}}|${var.proxy_name}|g' ${path.module}/apiproxy_dir/apiproxy/manifest.xml"
  }

  provisioner "local-exec" {
    command = "${var.sed_command} -i 's|{{base_path}}|${var.base_path}|g' ${path.module}/apiproxy_dir/apiproxy/manifest.xml"
  }
}

data "archive_file" "proxy_zip" {
  type        = "zip"
  source_dir = "${path.module}/apiproxy_dir"
  output_path = "${path.module}/proxy.zip"

  depends_on = [null_resource.create_proxy_dir]
}

resource "apigee_proxy" "example" {
  name = var.proxy_name
  bundle = data.archive_file.proxy_zip.output_path
  bundle_hash = filebase64sha256(data.archive_file.proxy_zip.output_path)
}

resource "apigee_proxy_deployment" "example" {
  proxy_name = apigee_proxy.example.name
  environment_name = var.environment_name
  revision = apigee_proxy.example.revision
}

output proxy_name {
  value       = apigee_proxy.example.name
}
