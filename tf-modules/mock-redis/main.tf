# This simulates spinning up a GCP Redis resource based on platform logic
resource "local_file" "redis_simulation" {
  filename = "${var.output_dir}/${var.name}_config.txt"

  content = <<-EOF
    Infrastructure Deployed Successfully!
    -------------------------------------
    Resource Name: ${var.name}-prod
    Engine: REDIS_${var.version}
    Instance Tier: ${
  var.node_type == "small" ? "cache.t3.micro" :
  var.node_type == "medium" ? "cache.m5.large" :
  "cache.r5.xlarge"
}
    Private IP Only: TRUE (Enforced by Platform)
    Encryption At Rest: TRUE (Enforced by Platform v1.1.0)
  EOF
}
