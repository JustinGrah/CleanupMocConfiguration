<#
.SYNOPSIS
  Script to cleanup MOC configurations from AzureStackHCI systems
.DESCRIPTION
  This script will clear out and remove any information left behind from the MOC without removing any of the VM's etc.
.NOTES
  Version:        1.0
  Author:         Justin Grah
  Creation Date:  28th October 2022
  Purpose/Change: Initial script development
.EXAMPLE
  .\Cleanup-Moc.ps1
#>


# Import Configuration using offline mode
$MocConfig = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\MocPS').psconfig + "\psconfig.json" 
$MocConfig = Get-Content $MocConfig | ConvertFrom-Json

# Setting up some static locations / options that will not change
$CloudAgentRegistry = 'HKLM:\SOFTWARE\Microsoft\wssdcloudagent'
$NodeAgentRegistry = 'HKLM:\SOFTWARE\Microsoft\wssdagent'
$MocRegistry = 'HKLM:\SOFTWARE\Microsoft\MocPS\psconfig'
$PathsToRemove = @('cloudConfigLocation','imageDir','nodeConfigLocation','workingDir')

$Nodes = Get-ClusterNode

foreach ($Node in $Nodes) {
    Write-Host ('Removing MOC on node: ' + $Node.Name)
    
    Write-Host "Stage 1/3 - Clearing services and registry"
    Invoke-Command -ScriptBlock {
        param(
            [string] $CloudAgentRegistry,
            [string] $NodeAgentRegistry,
            [string] $MocRegistry
        )
        # Stop Services when they are running
        $CloudAgentService = Get-Service -Name 'wssdcloudagent' -ErrorAction SilentlyContinue
        $NodeAgentService = Get-Service -Name 'wssdagent' -ErrorAction SilentlyContinue

        if($CloudAgentService.Status -eq "Running") {$CloudAgentService | Stop-Service -Force}
        if($NodeAgentService.Status -eq "Running") {$NodeAgentService | Stop-Service -Force}

        Write-Host "Deleting Service ..."
        @('wssdcloudagent','wssdagent') | ForEach-Object {
            $Service = Get-WmiObject -Class Win32_Service -Filter ("Name='" + $_ + "'") 
            $Service.delete()
        }

        Write-Host "Removing Registry ..."
        # we mute these errors, since these do not exist on every node!
        Remove-Item -Path $CloudAgentRegistry -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $MocRegistry -Force -ErrorAction SilentlyContinue
        
        # This one however, should be removed from every node
        Remove-Item -Path $NodeAgentRegistry -Force

    } -ArgumentList $CloudAgentRegistry,$NodeAgentRegistry,$MocRegistry  -ComputerName $Node.Name

    Write-Host "Stage 2/3 Removing local files"
    foreach($Path in $PathsToRemove) {
        $FilePath = $MocConfig.($Path)

        if($null -ne $FilePath) {
            Invoke-Command -ScriptBlock {
                param(
                    [string] $FilePath
                )
                # We mute this one since we are also deleting CSV paths.
                Remove-Item -Path $FilePath -Recurse -Force -ErrorAction SilentlyContinue
            } -ArgumentList $FilePath -ComputerName $Node.Name
        }
    }
}

Write-Host "Stage 3/3 - Removing cloud agent cluster group"
$ClusterService = Get-ClusterGroup -Name "ca-*"| Where-Object {($_.GroupType -eq "GenericService") -and (($_.State -eq "Failed") -or ($_.State -eq "Offline"))}

if($null -ne $ClusterService) {
    try {
        $ClusterService | Get-ClusterResource | Remove-ClusterResource
        $ClusterService | Remove-ClusterGroup
    } catch {
        Write-Host "An error happend while removing the clustered service " + $
    }
} else {
    Write-Host "Clustered Service was not found. Did you manually delete it?"
}