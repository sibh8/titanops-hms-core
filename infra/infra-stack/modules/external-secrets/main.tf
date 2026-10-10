# External Secrets Operator - installs ESO via Helm. Caller gates with count.
# Pairs with AWS Secrets Manager; uses IRSA for access.
resource "helm_release" "eso" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  dynamic "set" {
    for_each = var.service_account_role_arn == null ? [] : [1]
    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.service_account_role_arn
    }
  }
}
