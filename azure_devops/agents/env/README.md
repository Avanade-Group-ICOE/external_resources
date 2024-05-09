# Automated Azure DevOps Environment Registration

This automation is convenient to register Virtual Machines as Azure DevOps Environment resources. Traditionally, Azure DevOps provides a specific registration inline script to copy and run directly in the machine manually. It takes you
through a series of prompts. With this automation, you can deploy the Virtual Machines and then execute a script remotely.
Currently, only Azure is supported in this method within this repo. See examples.

Using the Azure Virtual Machines Custom Script Extension, you can use Terraform to provision Virtual Machines and then execute a command to register the machine with Azure DevOps.

## Example Terraform method - Windows

You can use the Windows registration script version to download the PowerShell registration script from the raw usercontent.
Notice that once you download the content, there is a 'Start-Sleep' command to give time for the Terraform resource to fully provision the script extension.
Then, the script sets the Execution Policy to 'Unrestricted' on the Process scope for the script to run without issues.

```
resource "azurerm_virtual_machine_extension" "vm_devopsenv_ext" {
  name                 = "adoEXTENSIONNAME"
  virtual_machine_id   = azurerm_windows_virtual_machine.my_windows_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = <<PROTECTED_SETTINGS
    { 
      "fileUris": [
        "https://raw.githubusercontent.com/Avanade-Group-ICOE/external_resources/main/agents/env/adoagent_register_env.ps1"
        ],
      "commandToExecute": "powershell.exe -Command \"Start-Sleep -Seconds 90; Set-ExecutionPolicy Unrestricted -Scope Process; & './adoagent_register_env.ps1' -devops_env_win \\\"${var.devops_targetEnv}\\\" -admin_username \\\"${var.admin_username}\\\" -admin_password \\\"${random_password.vm_password.result}\\\" -ado_org_url \\\"${var.ado_org_url}\\\" -ado_project \\\"${var.ado_project}\\\" -ado_pat \\\"${var.ado_pat}\\\" -adoagent_latest_version \\\"${var.adoagent_latest_version}\\\" -env_tags \\\"${var.devops_env_resource_tag}\\\"\""
    }
  PROTECTED_SETTINGS
}
```

## Example Terraform method - Linux

You can also use the Linux registration script version to download the Bash registration script from the raw usercontent.
Notice that once you download the content, you will have to move the file to a location on the machine that is not temporary and then change ownership and permissions for the admin user to execute the script.
This is because internal processes of the agent will run as the user without 'sudo' but requires access to all of its directories.

```
resource "azurerm_virtual_machine_extension" "vm_devopsenv_ext" {
  name                 = "adoEXTENSIONNAME"
  virtual_machine_id   = azurerm_virtual_machine.my_linux_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  protected_settings = <<PROTECTED_SETTINGS
    { 
      "fileUris": [
        "https://raw.githubusercontent.com/Avanade-Group-ICOE/external_resources/main/agents/env/adoagent_register_env.sh"
        ],
      "commandToExecute": "mv adoagent_register_env.sh /home/${var.admin_username}/; chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/adoagent_register_env.sh; chmod +x /home/${var.admin_username}/adoagent_register_env.sh; sudo -u ${var.admin_username} bash -c \"cd /home/${var.admin_username} && ./adoagent_register_env.sh -devops_env \\\"${var.devops_env}\\\" -ado_org_url \\\"${var.ado_org_url}\\\" -ado_project \\\"${var.ado_project}\\\" -ado_pat \\\"${var.ado_pat}\\\" -adoagent_latest_version \\\"${var.adoagent_latest_version}\\\" -env_tags \\\"${var.devops_env_resource_tag}\\\"\"",
    }
  PROTECTED_SETTINGS
}
```

## Independent script execution

Although Terraform with the Azure VM Custom Script Extension is the most convenient way to run the registration scripts, you may have a case to run the script remotely. Since Terraform does the work of getting 
the actual script to the machine for you, the examples below show how to execute the scripts assuming the scripts exist in the current directory:

### Script example - PowerShell

```
$TARGET_ENV_NAME = <MyEnvName>
$TARGET_ENV_ADMIN_USER = <AdminUser>
$TARGET_ENV_ADMIN_PWRD = <AdminPwrd>
$ADO_ORG_URL = "https://dev.azure.com/<MyOrgName>"
$ADO_PROJECT = <MyProjectName>
$ADO_PAT = <AdminPAT>
$ADO_AGENT_LTS_VER = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest" | Select-Object -ExpandProperty tag_name -ErrorAction SilentlyContinue | ForEach-Object { $_ -replace "v", "" }

.\adoagent_register_env.ps1 `
    -devops_env_win "$TARGET_ENV_NAME" `
    -admin_username "$TARGET_ENV_ADMIN_USER" `
    -admin_password "$TARGET_ENV_ADMIN_PWRD" `
    -ado_org_url "$ADO_ORG_URL" `
    -ado_project "$ADO_PROJECT" `
    -ado_pat "$ADO_PAT" `
    -adoagent_latest_version \\\"${var.adoagent_latest_version}\\\" `
    -env_tags "$TAG1, $TAG2"
```

### Script example - Bash

```
TARGET_ENV_NAME=<MyEnvName>
ADO_ORG_URL="https://dev.azure.com/<MyOrgName>"
ADO_PROJECT=<MyProjectName>
ADO_PAT=<AdminPAT>
ADO_AGENT_LTS_VER=$(curl --silent "https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

./adoagent_register_env.sh -devops_env "$TARGET_ENV_NAME" \
    -ado_org_url "$ADO_ORG_URL" \
    -ado_project "$ADO_PROJECT" \
    -ado_pat "$ADO_PAT" \
    -adoagent_latest_version "$ADO_AGENT_LTS_VER" \
    -env_tags "$TAG1, $TAG2"
```
