# Cleanup-Moc
A script used to remove the MOC from the ARC Resource Bridge safely - without removing VM's.


## Validation and testing
**If you are using this on a enviroment with AKS for HCI, will screw your whole AKS cluster, resulting in a re-install of AKS!!**
As mentioned i have validated this script for:
- Arc Resource Bridge on AzureStack HCI (No other programs or features installed.)


## Workflow
The script works with 2 Stages and then mutliple sub-steps:
1. Stage 0 - Grabbing configuration
   1. Load config as per registry `HKLM:\SOFTWARE\Microsoft\MocPS\psconfig`
2. Stage 1 - Cleanup of Services and Registry
   1. Stop service `wssdagent`
   2. Stop service `wssdcloudagent`
   3. Remove service `wssdagent`
   4. Remove service `wssdcloudagent`
   5. Remove registry `HKLM:\SOFTWARE\Microsoft\wssdcloudagent`
   6. Remove registry `HKLM:\SOFTWARE\Microsoft\wssdagent`
3. Stage 2 - Cleanup local files
   1. Remove file path `cloudConfigLocation`
   2. Remove file path `imageDir`
   3. Remove file path `nodeConfigLocation`
   4. Remove file path `workingDir`
4. Stage 3 - Remove clustered group and clusterd resources
   1. Remove all clustered resources from `ca-*`
   2. Remove clustered role `ca-*`
Done

## Usage and liability
This script is not an official workaround. Although i put in efforts to test this script in my lab multiple times, it is not excluded that this might cause harm / damage to your VM's - since removing such a key piece is a delicate process. You as the system administrator need to take care and perform these steps with your own judgement and knoweldge. Also it is important to mention: this script does not have guardrails.
Meaning, there is no further validation if you "Really" want to remove stuff.
Therfore, if you dont understand a single line in this script, you most likely do not want to use it.