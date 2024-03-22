<#
.SYNOPSIS
  Script to cleanup MOC configurations from AzureStackHCI 22H2 systems
.DESCRIPTION
  This script will clear out and remove any information left behind from the MOC without removing any of the VM's etc.
.NOTES
  Version:        2.0
  Author:         Justin Grah
  Creation Date:  22nd March 2024
  Purpose/Change: Initial script development
.EXAMPLE
  .\Cleanup-Moc.ps1
#>

<#
  ┌──────────────────────────────────────────────────────────────────────────┐
  │ Constants                                                                │
  └──────────────────────────────────────────────────────────────────────────┘
 #>
 $mocConfigReg               = 'HKLM:\SOFTWARE\Microsoft\MocPS'

 $mocWssdNodeAgentReg        = 'HKLM:\SOFTWARE\Microsoft\wssdagent'
 $mocWssdNodeAgentSvcReg     = 'HKLM:\SYSTEM\CurrentControlSet\Services\wssdagent'

 $mocWssdCloudAgentReg       = 'HKLM:\SOFTWARE\Microsoft\wssdcloudagent'
 $mocWssdCloudAgentSvcReg    = 'HKLM:\SYSTEM\CurrentControlSet\Services\wssdcloudagent'

 $mocCleanupBackupFolderName = 'MOC_REMOVAL_BACKUP'

 <#
   ┌──────────────────────────────────────────────────────────────────────────┐
   │ Load information from Cluster and MOC                                    │
   └──────────────────────────────────────────────────────────────────────────┘
  #>

 $clusterNodes = Get-ClusterNode
 $mocConfig = (Get-ItemProperty -Path $mocConfigReg).psconfig + "\psconfig.json"
 $mocConfig = Get-Content $mocConfig | ConvertFrom-Json

 $imageDir = $mocConfig.imageDir
 $workingDir = $mocConfig.workingDir
 $cloudConfig = $mocConfig.cloudConfigLocation
 $cloudAgentRole = $mocConfig.clusterRoleName
 $mocWssdNodeAgentPath = $mocConfig.nodeConfigLocation

 <#
   ┌──────────────────────────────────────────────────────────────────────────┐
   │ Actual cleanup steps                                                     │
   └──────────────────────────────────────────────────────────────────────────┘
  #>
 # Stop CloudAgent and remove Group
 Write-Host "Stopping ClusterGroup and removing it"
 $mocClusterGroup = Get-ClusterGroup -Name $cloudAgentRole -ErrorAction SilentlyContinue
 if($null -ne $mocClusterGroup) {
     $mocClusterGroup | Stop-ClusterGroup
     $mocClusterGroup | Remove-ClusterGroup -RemoveResources -Force
 }

 # Stop NodeAgents and remove service
 Invoke-Command -ComputerName $clusterNodes -ScriptBlock {
     param(
         $mocWssdNodeAgentReg,
         $mocWssdNodeAgentSvcReg,
         $mocWssdNodeAgentPath,
         $mocWssdCloudAgentReg,
         $mocWssdCloudAgentSvcReg,
         $mocCleanupBackupFolderName
     )

     try{
         Write-Host ("Cleaning up node: {0}" -f $env:COMPUTERNAME)
         $backupFolder = New-Item -Path "C:\" -Name $mocCleanupBackupFolderName -ItemType:Directory -ErrorAction Stop
     } catch {
         Write-Host "Not able to create backup folder! Operation UNSAFE!"
     }

     Write-Host "Stopping WssdAgent Service"
     $wssdAgentService = Get-Service -Name "wssdagent" -ErrorAction SilentlyContinue
     if($null -ne $wssdAgentService) {
         $wssdAgentService | Stop-Service -Force
     }

     Write-Host "Stopping WssdCloudAgent Service"
     $wssdCloudAgent = Get-Service -Name "wssdcloudagent" -ErrorAction SilentlyContinue
     if($null -ne $wssdCloudAgent) {
         $wssdCloudAgent | Stop-Service -Force
     }

     # Delete services
     Write-Host "Deleting Services"
     @('wssdcloudagent','wssdagent') | ForEach-Object {
         $Service = Get-WmiObject -Class Win32_Service -Filter ("Name='" + $_ + "'")
         $Service.delete()
     }

     # Delete directories and registry.
     Write-Host "Removing Registry"
     try {
         if($null -ne $backupFolder) {
             $regBackup = New-Item -Path $backupFolder.FullName -Name "wssdNodeAgentRegistry" -ItemType:Directory
             REG EXPORT ($mocWssdNodeAgentReg.Replace(":","")) ($regBackup.FullName + "\wssdagent_data.reg")
             $mocWssdNodeAgentReg | Get-ChildItem | Remove-Item -Recurse -Force
         }
     } catch {  }

     Write-Host "Removing cloud registry"
     try {
         if($null -ne $backupFolder) {
             $regBackup = New-Item -Path $backupFolder.FullName -Name "wssdCloudAgentRegistry" -ItemType:Directory
             REG EXPORT ($mocWssdCloudAgentReg.Replace(":","")) ($regBackup.FullName + "\wssdcloudagent_data.reg")
             $mocWssdCloudAgentReg | Get-ChildItem | Remove-Item -Recurse -Force
         }
     } catch {  }

     Write-Host "Removing wssdagent data"
     try {
         if($null -ne $backupFolder) {
             $dirBackup = New-Item -Path $backupFolder.FullName -Name "wssdNodeAgentDir" -ItemType:Directory
             Copy-Item -Path $mocWssdNodeAgentPath -Destination $dirBackup.FullName
             Remove-Item -Path $mocWssdNodeAgentPath -Recurse -Force
         }
     } catch {  }

 } -ArgumentList $mocWssdNodeAgentReg,$mocWssdNodeAgentSvcReg,$mocWssdNodeAgentPath,$mocWssdCloudAgentReg,$mocWssdCloudAgentSvcReg,$mocCleanupBackupFolderName

Write-Host (@"
 We have cleaned up your environment.
 You may want to consider removing the following directories manually:
 - {0}
 - {1}
 - {2}
 Please note: These folders may contain VM related workload data. Please check BEFORE removing!

 Should you need data that we have removed, you can find them in the C:\{3} folder on each of the clustered node.
"@ -f $imageDir, $workingDir, $cloudConfig, $mocCleanupBackupFolderName)