# El backend S3 vive en Floci (emulador). Las claves test/test no son
# credenciales reales de AWS. Cada ambiente usa un key distinto
# (ver infra/envs/*.backend.hcl).
terraform {
  backend "s3" {}
}
