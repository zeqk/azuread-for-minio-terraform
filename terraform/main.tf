data "azuread_client_config" "current" {}

data "azuread_group" "minio_users" {
  display_name = "MiniO-Users"
}

# https://learn.microsoft.com/en-us/azure/active-directory/hybrid/how-to-connect-fed-group-claims
# Add a new Azure AD App registration
resource "azuread_application" "minio" {
  display_name = "MiniO"
  web {
    redirect_uris = ["https://minio-console.mydomain.com/oauth_callback"]
    implicit_grant {
      access_token_issuance_enabled = true
    }
  }
  
  optional_claims {
    access_token {
      name                  = "groups"
      additional_properties = ["sam_account_name"]
      essential             = true
    }
    id_token {
      name                  = "groups"
      additional_properties = ["sam_account_name"]
      essential             = true
    }
    saml2_token {
      name                  = "groups"
      additional_properties = ["sam_account_name"]
      essential             = true
    }
  }

  group_membership_claims = ["ApplicationGroup"]

  owners = [data.azuread_client_config.current.object_id]
}

# Add Enterprise Application
resource "azuread_service_principal" "minio" {
  application_id               = azuread_application.minio.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

# Add credentials to Azure AD App registration
resource "azuread_application_password" "minio" {
  display_name          = "MiniO-SSO"
  application_object_id = azuread_application.minio.object_id
  end_date              = "2028-01-01T01:02:03Z"
}

resource "azuread_app_role_assignment" "minio_minio_users" {
  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = data.azuread_group.minio_users.object_id
  resource_object_id  = azuread_service_principal.minio.object_id
}

output "client_id" {
  value = azuread_application.minio.application_id
}

output "client_secret" {
  value = azuread_application_password.minio.value
  sensitive   = true
}
