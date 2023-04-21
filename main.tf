variable apigee_org_id {
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

variable gcp_credentials_b64 {
  type = string
}

terraform {
  required_providers {
    apigee = {
      source  = "scastria/apigee"
      version = "~> 0.1.0"
    }
  }
}

provider "google" {
  credentials = base64decode(var.gcp_credentials_b64)
}

data "google_client_config" "default" {
  provider = google
}

provider "apigee" {
  organization = var.apigee_org_id
  access_token = data.google_client_config.default.access_token
  server       = "apigee.googleapis.com"
}

resource "null_resource" "create_proxy_dir" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {  
    command = "touch /tmp/hello.txt && rm -rf /tmp/apiproxy_dir 2> /dev/null && cp -r ${path.module}/proxy_template /tmp/apiproxy_dir"
  }

  provisioner "local-exec" {
    command = "${var.sed_command} -i 's|{{base_path}}|${var.base_path}|g' /tmp/apiproxy_dir/apiproxy/proxies/default.xml"
  }

  provisioner "local-exec" {
    command = "${var.sed_command} -i 's|{{target_url}}|${var.target_url}|g' /tmp/apiproxy_dir/apiproxy/targets/default.xml"
  }

  provisioner "local-exec" {
    command = "${var.sed_command} -i 's|{{proxy_name}}|${var.proxy_name}|g' /tmp/apiproxy_dir/apiproxy/manifest.xml"
  }

  provisioner "local-exec" {
    command = "${var.sed_command} -i 's|{{base_path}}|${var.base_path}|g' /tmp/apiproxy_dir/apiproxy/manifest.xml"
  }
}

data "archive_file" "proxy_zip" {
  type        = "zip"
  source_dir = data.null_data_source.wait_for_zip.outputs.source_dir
  output_path = "/tmp/proxy.zip"

  depends_on = [null_resource.create_proxy_dir]
}

data "null_data_source" "wait_for_zip" {
  inputs = {
    # This ensures that this data resource will not be evaluated until
    # after the null_resource has been created.
    templater_id = "${null_resource.create_proxy_dir.id}"

    # This value gives us something to implicitly depend on
    # in the archive_file below.
    output_path = "/tmp/proxy.zip"
    source_dir = "/tmp/apiproxy_dir"
  }
}

resource "apigee_proxy" "example" {
  name = var.proxy_name
  bundle = data.archive_file.proxy_zip.output_path
  bundle_hash = filebase64sha256(data.null_data_source.wait_for_zip.outputs.output_path)
}

resource "apigee_proxy_deployment" "example" {
  proxy_name = apigee_proxy.example.name
  environment_name = var.environment_name
  revision = apigee_proxy.example.revision
}

output proxy_name {
  value       = apigee_proxy.example.name
}
