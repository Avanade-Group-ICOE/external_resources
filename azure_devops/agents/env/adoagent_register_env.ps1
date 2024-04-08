param(
    [Parameter(Mandatory=$true)]
    [string]$devops_env_win,
    
    [Parameter(Mandatory=$true)]
    [string]$admin_username,

    [Parameter(Mandatory=$true)]
    [string]$admin_password,
    
    [Parameter(Mandatory=$true)]
    [string]$ado_org_url,
    
    [Parameter(Mandatory=$true)]
    [string]$ado_project,
    
    [Parameter(Mandatory=$true)]
    [string]$ado_pat,

    [Parameter(Mandatory=$true)]
    [string]$adoagent_latest_version,

    [Parameter(Mandatory=$true)]
    [string]$env_tags
)

function Check-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = ([Security.Principal.WindowsPrincipal]$currentUser).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-NOT $isAdmin) {
        throw "Run command in an administrator PowerShell prompt"
    }
}

function Check-PSVersion {
    if ($PSVersionTable.PSVersion -lt (New-Object System.Version("3.0"))) {
        throw "The minimum version of Windows PowerShell that is required by the script (3.0) does not match the currently running version of Windows PowerShell."
    }
}

function Create-AzAgentDirectory {
    $azAgentPath = Join-Path $env:SystemDrive "azagent"
    if (-NOT (Test-Path $azAgentPath)) {
        New-Item -ItemType Directory -Path $azAgentPath | Out-Null
    }
    Set-Location $azAgentPath

    for ($i = 1; $i -lt 100; $i++) {
        $destFolder = "A" + $i.ToString()
        if (-NOT (Test-Path $destFolder)) {
            New-Item -ItemType Directory -Path $destFolder | Out-Null
            Set-Location $destFolder
            break
        }
    }
}

function Download-Agent {
    $agentZip = Join-Path $PWD "agent.zip"
    $uri = "https://vstsagentpackage.azureedge.net/agent/$adoagent_latest_version/vsts-agent-win-x64-$adoagent_latest_version.zip"
    $webClient = New-Object Net.WebClient

    $defaultProxy = [System.Net.WebRequest]::DefaultWebProxy
    if ($defaultProxy -and (-not $defaultProxy.IsBypassed($uri))) {
        $webClient.Proxy = New-Object Net.WebProxy($defaultProxy.GetProxy($uri).OriginalString, $True)
    }

    $webClient.DownloadFile($uri, $agentZip)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($agentZip, "$PWD")
    Remove-Item $agentZip
}

function Configure-Agent {
    .\config.cmd --unattended --environment --environmentname "$devops_env_win" --agent "$env:COMPUTERNAME" --runasservice --windowsLogonAccount "$admin_username" --windowsLogonPassword "$admin_password" --serviceSidType unrestricted --work "_work" --url "$ado_org_url" --projectname "$ado_project" --auth PAT --token "$ado_pat" --addvirtualmachineresourcetags --virtualmachineresourcetags "$env_tags"
}

$ErrorActionPreference = "Stop"

Check-Admin
Check-PSVersion
Create-AzAgentDirectory
Download-Agent
Configure-Agent
