# This simulates spinning up a GCP resource based on platform logic
resource "local_file" "database_simulation" {
  filename = "${var.output_dir}/${var.db_name}_config.txt"

  content = <<-EOF
    Infrastructure Deployed Successfully!
    -------------------------------------
    Resource Name: ${var.db_name}-prod
    Engine: POSTGRES_${var.pg_version}
    Instance Tier: ${
  var.size == "small" ? "db-f1-micro" :
  var.size == "medium" ? "db-custom-2-7680" :
  "db-custom-4-15360"
}
    Private IP Only: TRUE (Enforced by Platform)
    Encryption At Rest: TRUE (Enforced by Platform v1.1.0)
  EOF
}
