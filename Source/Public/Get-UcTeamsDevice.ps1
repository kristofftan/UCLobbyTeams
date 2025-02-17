<#
.SYNOPSIS
Get Microsoft Teams Devices information

.DESCRIPTION
This function fetch Teams Devices provisioned in a M365 Tenant using MS Graph.
 

Contributors: David Paulino, Silvio Schanz, Gonçalo Sepulveda and Bryan Kendrick

Requirements:   Microsoft Graph PowerShell Module (Install-Module Microsoft.Graph)
                Microsoft Graph Scopes:
                        "TeamworkDevice.Read.All"
                        "User.Read.All"

.PARAMETER Filter
Specifies a filter, valid options:
    Phone - Teams Native Phones
    MTR - Microsoft Teams Rooms running Windows or Android
    MTRW - Microsoft Teams Room Running Windows
    MTRA - Microsoft Teams Room Running Android
    SurfaceHub - Surface Hub 
    Display - Microsoft Teams Displays 
    Panel - Microsoft Teams Panels

.PARAMETER DeviceId
Specifies the Teams Device ID

.PARAMETER Detailed
When present it will get detailed information from Teams Devices

.EXAMPLE 
PS> Get-UcTeamsDevice

.EXAMPLE 
PS> Get-UcTeamsDevice -Filter MTR

.EXAMPLE
PS> Get-UcTeamsDevice -DeviceId 00000000-0000-0000-0000-000000000000

.EXAMPLE
PS> Get-UcTeamsDevice -Detailed

#>

$GraphURI_BetaAPIBatch = "https://graph.microsoft.com/beta/`$batch"
$GraphURI_Users = "https://graph.microsoft.com/v1.0/users/"

Function Get-UcTeamsDevice {
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Phone","MTR","MTRA","MTRW","SurfaceHub","Display","Panel","SIPPhone")]
        [string]$Filter,
        [Parameter(Mandatory = $false)]
        [string]$DeviceId,
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )    
    $outTeamsDevices = [System.Collections.ArrayList]::new()
    
    #Checking if we have the required scopes.
    $scopes = (Get-MgContext).Scopes
    if (!($scopes) -or !(( "TeamworkDevice.Read.All" -in $scopes ) -and ("User.Read.All" -in $scopes))) {
        Connect-MgGraph -Scopes "TeamworkDevice.Read.All", "User.Read.All"
    }

    if($DeviceId){

        $graphRequests =  [System.Collections.ArrayList]::new()
        $gRequestTmp = New-Object -TypeName PSObject -Property @{
            id = "device"
            method = "GET"
            url = "/teamwork/devices/"+$DeviceId
        }
        $graphRequests.Add($gRequestTmp) | Out-Null
        $gRequestTmp = New-Object -TypeName PSObject -Property @{
            id = "activity"
            method = "GET"
            url = "/teamwork/devices/"+$DeviceId+"/activity"
        }
        $graphRequests.Add($gRequestTmp) | Out-Null
        $gRequestTmp = New-Object -TypeName PSObject -Property @{
            id = "configuration"
            method = "GET"
            url = "/teamwork/devices/"+$DeviceId+"/configuration"
        }
        $graphRequests.Add($gRequestTmp) | Out-Null
        $gRequestTmp = New-Object -TypeName PSObject -Property @{
            id = "health"
            method = "GET"
            url = "/teamwork/devices/"+$DeviceId+"/health"
        }
        $graphRequests.Add($gRequestTmp) | Out-Null
        $gRequestTmp = New-Object -TypeName PSObject -Property @{
            id = "operations"
            method = "GET"
            url = "/teamwork/devices/"+$DeviceId+"/operations"
        }
        $graphRequests.Add($gRequestTmp) | Out-Null
        $graphBody = ' { "requests": '+ ($graphRequests | ConvertTo-Json) + ' }' 
        $graphResponses = (Invoke-MgGraphRequest -Method Post -Uri $GraphURI_BetaAPIBatch -Body $graphBody).responses

        $TeamsDevice = ($graphResponses | Where-Object{$_.id -eq "device"}).body
        $TeamsDeviceActivity = ($graphResponses | Where-Object{$_.id -eq "activity"}).body
        $TeamsDeviceConfiguration = ($graphResponses | Where-Object{$_.id -eq "configuration"}).body
        $TeamsDeviceHealth = ($graphResponses | Where-Object{$_.id -eq "health"}).body
        $TeamsDeviceOperations = ($graphResponses | Where-Object{$_.id -eq "operations"}).body.value

        if($TeamsDeviceOperations.count -gt 0){
            $LastHistoryAction = $TeamsDeviceOperations[0].operationType
            $LastHistoryStatus = $TeamsDeviceOperations[0].status
            $LastHistoryInitiatedBy = $TeamsDeviceOperations[0].createdBy.user.displayName
            $LastHistoryModifiedDate = $TeamsDeviceOperations[0].lastActionDateTime
            $LastHistoryErrorCode = $TeamsDeviceOperations[0].error.code
            $LastHistoryErrorMessage = $TeamsDeviceOperations[0].error.message
        } else {
            $LastHistoryAction = ""
            $LastHistoryStatus = ""
            $LastHistoryInitiatedBy = ""
            $LastHistoryModifiedDate = ""
            $LastHistoryErrorCode = ""
            $LastHistoryErrorMessage = ""
        }

        if ($TeamsDevice.currentuser.id) {
            $userUPN = (Invoke-MgGraphRequest -Uri ($GraphURI_Users + $TeamsDevice.currentuser.id ) -Method GET).userPrincipalName
        }
        else {
            $userUPN = ""
        }

        $outTDObj = New-Object -TypeName PSObject -Property @{
            UserDisplayName = $TeamsDevice.currentuser.displayName
            UserUPN         = $userUPN 
    
            DeviceType      = Convert-UcTeamsDeviceType $TeamsDevice.deviceType
            DeviceID        = $DeviceId
            Notes           = $TeamsDevice.notes
            CompanyAssetTag = $TeamsDevice.companyAssetTag

            Manufacturer    = $TeamsDevice.hardwaredetail.manufacturer
            Model           = $TeamsDevice.hardwaredetail.model
            SerialNumber    = $TeamsDevice.hardwaredetail.serialNumber 
            MacAddresses    = $TeamsDevice.hardwaredetail.macAddresses
                        
            DeviceHealth    = $TeamsDevice.healthStatus
            WhenCreated = $TeamsDevice.createdDateTime
            WhenChanged = $TeamsDevice.lastModifiedDateTime
            ChangedByUser = $TeamsDevice.lastModifiedBy.user.displayName

            #Activity
            ActivePeripherals = $TeamsDeviceActivity.activePeripherals

            #Configuration
            LastUpdate = $TeamsDeviceConfiguration.createdDateTime

            DisplayConfiguration = $TeamsDeviceConfiguration.displayConfiguration
            CameraConfiguration = $TeamsDeviceConfiguration.cameraConfiguration
            SpeakerConfiguration = $TeamsDeviceConfiguration.speakerConfiguration
            MicrophoneConfiguration = $TeamsDeviceConfiguration.microphoneConfiguration
            TeamsClientConfiguration = $TeamsDeviceConfiguration.teamsClientConfiguration
            HardwareConfiguration = $TeamsDeviceConfiguration.hardwareConfiguration
            SystemConfiguration = $TeamsDeviceConfiguration.systemConfiguration

            #Health
            TeamsAdminAgentVersion = $TeamsDeviceHealth.softwareUpdateHealth.adminAgentSoftwareUpdateStatus.currentVersion
            FirmwareVersion = $TeamsDeviceHealth.softwareUpdateHealth.firmwareSoftwareUpdateStatus.currentVersion
            CompanyPortalVersion = $TeamsDeviceHealth.softwareUpdateHealth.companyPortalSoftwareUpdateStatus.currentVersion
            OEMAgentAppVersion = $TeamsDeviceHealth.softwareUpdateHealth.partnerAgentSoftwareUpdateStatus.currentVersion
            TeamsAppVersion = $TeamsDeviceHealth.softwareUpdateHealth.teamsClientSoftwareUpdateStatus.currentVersion
            
            #LastOperation
            LastHistoryAction = $LastHistoryAction
            LastHistoryStatus = $LastHistoryStatus
            LastHistoryInitiatedBy = $LastHistoryInitiatedBy
            LastHistoryModifiedDate = $LastHistoryModifiedDate
            LastHistoryErrorCode = $LastHistoryErrorCode
            LastHistoryErrorMessage = $LastHistoryErrorMessage 
        }
        $outTDObj.PSObject.TypeNAmes.Insert(0, 'TeamsDevice')
        return $outTDObj
    }
    else{
        $graphRequests =  [System.Collections.ArrayList]::new()
        switch ($filter) {
            "Phone" { 
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "ipPhone"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'ipPhone'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "lowCostPhone"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'lowCostPhone'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
            }
            "MTR" {
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "teamsRoom"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'teamsRoom'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "collaborationBar"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'collaborationBar'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "touchConsole"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'touchConsole'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
            }
            "MTRW"{
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "teamsRoom"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'teamsRoom'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
            }
            "MTRA"{            
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "collaborationBar"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'collaborationBar'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "touchConsole"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'touchConsole'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
            }
            "SurfaceHub" {
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "surfaceHub"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'surfaceHub'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
            }
            "Display"{
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "teamsDisplay"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'teamsDisplay'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
            }
            "Panel" {
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "teamsPanel"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'teamsPanel'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
            }
            "SIPPhone" {
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = "sip"
                    method = "GET"
                    url = "/teamwork/devices/?`$filter=deviceType eq 'sip'"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
            }
            Default {
                $gRequestTmp = New-Object -TypeName PSObject -Property @{
                    id = 1
                    method = "GET"
                    url = "/teamwork/devices/"
                }
                $graphRequests.Add($gRequestTmp) | Out-Null
            }
        }
        
        #TO DO: Look for alternatives instead of doing this.
        if($graphRequests.Count -gt 1){
            $graphBody = ' { "requests":  '+ ($graphRequests | ConvertTo-Json) + ' }' 
        } else {
            $graphBody = ' { "requests": ['+ ($graphRequests | ConvertTo-Json) + '] }' 
        }
        $graphResponses = (Invoke-MgGraphRequest -Method Post -Uri $GraphURI_BetaAPIBatch -Body $graphBody).responses
        
        #For performance is better to get all users in one graph request
        $graphResponseExtra =  [System.Collections.ArrayList]::new()
        for($j=0;$j -lt $graphResponses.length; $j++){
            $graphRequestsExtra =  [System.Collections.ArrayList]::new()

            $TeamsDeviceList = $graphResponses[$j].body.value
            $i = 1
            foreach($TeamsDevice in $TeamsDeviceList){
                $batchCount = [int](($TeamsDeviceList.length * 5)/20)+1
                Write-Progress -Activity "Teams Device List" -Status "Running batch $i of $batchCount"  -PercentComplete (($i / $batchCount) * 100)

                if(($graphRequestsExtra.id -notcontains $TeamsDevice.currentuser.id) -and ($null -ne $TeamsDevice.currentuser.id) -and ($graphResponseExtra.id -notcontains $TeamsDevice.currentuser.id)) {
                    $gRequestTmp = New-Object -TypeName PSObject -Property @{
                        id =  $TeamsDevice.currentuser.id
                        method = "GET"
                        url = "/users/"+ $TeamsDevice.currentuser.id
                    }
                    $graphRequestsExtra.Add($gRequestTmp) | Out-Null
                }
                if($Detailed){
                    $gRequestTmp = New-Object -TypeName PSObject -Property @{
                        id = $TeamsDevice.id+"-activity"
                        method = "GET"
                        url = "/teamwork/devices/"+$TeamsDevice.id+"/activity"
                    }
                    $graphRequestsExtra.Add($gRequestTmp) | Out-Null
                    $gRequestTmp = New-Object -TypeName PSObject -Property @{
                        id = $TeamsDevice.id+"-configuration"
                        method = "GET"
                        url = "/teamwork/devices/"+$TeamsDevice.id+"/configuration"
                    }
                    $graphRequestsExtra.Add($gRequestTmp) | Out-Null
                    $gRequestTmp = New-Object -TypeName PSObject -Property @{
                        id =$TeamsDevice.id+"-health"
                        method = "GET"
                        url = "/teamwork/devices/"+$TeamsDevice.id+"/health"
                    }
                    $graphRequestsExtra.Add($gRequestTmp) | Out-Null
                    $gRequestTmp = New-Object -TypeName PSObject -Property @{
                        id = $TeamsDevice.id+"-operations"
                        method = "GET"
                        url = "/teamwork/devices/"+$TeamsDevice.id+"/operations"
                    }
                    $graphRequestsExtra.Add($gRequestTmp) | Out-Null
                } 

                #MS Graph is limited to 20 requests per batch, each device has 5 requests unless we already know the User UPN.
                if($graphRequestsExtra.Count -gt 15)  {
                    $i++
                    $graphBodyExtra = ' { "requests":  '+ ($graphRequestsExtra  | ConvertTo-Json) + ' }' 
                    $graphResponseExtra += (Invoke-MgGraphRequest -Method Post -Uri $GraphURI_BetaAPIBatch -Body $graphBodyExtra).responses
                    $graphRequestsExtra =  [System.Collections.ArrayList]::new()
                }
            }
            #Checking if we have requests pending
            if ($graphRequestsExtra.Count -gt 0){
                Write-Progress -Activity "Teams Device List" -Status "Running batch $i of $batchCount"  -PercentComplete (($i / $batchCount) * 100)
                if($graphRequestsExtra.Count -gt 1){
                    $graphBodyExtra = ' { "requests":  '+ ($graphRequestsExtra | ConvertTo-Json) + ' }' 
                } else {
                    $graphBodyExtra = ' { "requests": ['+ ($graphRequestsExtra | ConvertTo-Json) + '] }' 
                }
                $graphResponseExtra += (Invoke-MgGraphRequest -Method Post -Uri $GraphURI_BetaAPIBatch -Body $graphBodyExtra).responses
            }
        }
        for($j=0;$j -lt $graphResponses.length; $j++){
            if($graphResponses[$j].status -eq 200){
                $TeamsDeviceList = $graphResponses[$j].body.value
                
                foreach($TeamsDevice in $TeamsDeviceList){
                    $userUPN = ($graphResponseExtra | Where-Object{$_.id -eq $TeamsDevice.currentuser.id}).body.userPrincipalName

                    if($Detailed){
                        $TeamsDeviceActivity = ($graphResponseExtra | Where-Object{$_.id -eq ($TeamsDevice.id+"-activity")}).body
                        $TeamsDeviceConfiguration = ($graphResponseExtra | Where-Object{$_.id -eq ($TeamsDevice.id+"-configuration")}).body
                        $TeamsDeviceHealth = ($graphResponseExtra | Where-Object{$_.id -eq ($TeamsDevice.id+"-health")}).body
                        $TeamsDeviceOperations = ($graphResponseExtra | Where-Object{$_.id -eq ($TeamsDevice.id+"-operations")}).body.value

                        if($TeamsDeviceOperations.count -gt 0){
                            $LastHistoryAction = $TeamsDeviceOperations[0].operationType
                            $LastHistoryStatus = $TeamsDeviceOperations[0].status
                            $LastHistoryInitiatedBy = $TeamsDeviceOperations[0].createdBy.user.displayName
                            $LastHistoryModifiedDate = $TeamsDeviceOperations[0].lastActionDateTime
                            $LastHistoryErrorCode = $TeamsDeviceOperations[0].error.code
                            $LastHistoryErrorMessage = $TeamsDeviceOperations[0].error.message
                        } else {
                            $LastHistoryAction = ""
                            $LastHistoryStatus = ""
                            $LastHistoryInitiatedBy = ""
                            $LastHistoryModifiedDate = ""
                            $LastHistoryErrorCode = ""
                            $LastHistoryErrorMessage = ""
                        }
               
                        $TDObj = New-Object -TypeName PSObject -Property @{
                            UserDisplayName = $TeamsDevice.currentuser.displayName
                            UserUPN         = $userUPN 
                    
                            DeviceType      = Convert-UcTeamsDeviceType $TeamsDevice.deviceType
                            DeviceID        = $TeamsDevice.id
                            Notes           = $TeamsDevice.notes
                            CompanyAssetTag = $TeamsDevice.companyAssetTag
                
                            Manufacturer    = $TeamsDevice.hardwaredetail.manufacturer
                            Model           = $TeamsDevice.hardwaredetail.model
                            SerialNumber    = $TeamsDevice.hardwaredetail.serialNumber 
                            MacAddresses    = $TeamsDevice.hardwaredetail.macAddresses
                                        
                            DeviceHealth    = $TeamsDevice.healthStatus
                            WhenCreated = $TeamsDevice.createdDateTime
                            WhenChanged = $TeamsDevice.lastModifiedDateTime
                            ChangedByUser = $TeamsDevice.lastModifiedBy.user.displayName
                
                            #Activity
                            ActivePeripherals = $TeamsDeviceActivity.activePeripherals
                
                            #Configuration
                            LastUpdate = $TeamsDeviceConfiguration.createdDateTime
                
                            DisplayConfiguration = $TeamsDeviceConfiguration.displayConfiguration
                            CameraConfiguration = $TeamsDeviceConfiguration.cameraConfiguration
                            SpeakerConfiguration = $TeamsDeviceConfiguration.speakerConfiguration
                            MicrophoneConfiguration = $TeamsDeviceConfiguration.microphoneConfiguration
                            TeamsClientConfiguration = $TeamsDeviceConfiguration.teamsClientConfiguration
                            HardwareConfiguration = $TeamsDeviceConfiguration.hardwareConfiguration
                            SystemConfiguration = $TeamsDeviceConfiguration.systemConfiguration
                
                            #Health
                            TeamsAdminAgentVersion = $TeamsDeviceHealth.softwareUpdateHealth.adminAgentSoftwareUpdateStatus.currentVersion
                            FirmwareVersion = $TeamsDeviceHealth.softwareUpdateHealth.firmwareSoftwareUpdateStatus.currentVersion
                            CompanyPortalVersion = $TeamsDeviceHealth.softwareUpdateHealth.companyPortalSoftwareUpdateStatus.currentVersion
                            OEMAgentAppVersion = $TeamsDeviceHealth.softwareUpdateHealth.partnerAgentSoftwareUpdateStatus.currentVersion
                            TeamsAppVersion = $TeamsDeviceHealth.softwareUpdateHealth.teamsClientSoftwareUpdateStatus.currentVersion
                            
                            #LastOperation
                            LastHistoryAction = $LastHistoryAction
                            LastHistoryStatus = $LastHistoryStatus
                            LastHistoryInitiatedBy = $LastHistoryInitiatedBy
                            LastHistoryModifiedDate = $LastHistoryModifiedDate
                            LastHistoryErrorCode = $LastHistoryErrorCode
                            LastHistoryErrorMessage = $LastHistoryErrorMessage 
                        }
                        $TDObj.PSObject.TypeNAmes.Insert(0, 'TeamsDevice')
                
                    } else {
                        $TDObj = New-Object -TypeName PSObject -Property @{
                            UserDisplayName = $TeamsDevice.currentuser.displayName
                            UserUPN         = $userUPN 
                    
                            DeviceType      = Convert-UcTeamsDeviceType $TeamsDevice.deviceType
                            DeviceID        = $TeamsDevice.id

                            Manufacturer    = $TeamsDevice.hardwaredetail.manufacturer
                            Model           = $TeamsDevice.hardwaredetail.model
                            SerialNumber    = $TeamsDevice.hardwaredetail.serialNumber 
                            MacAddresses    = $TeamsDevice.hardwaredetail.macAddresses
                                        
                            DeviceHealth    = $TeamsDevice.healthStatus
                        }
                        $TDObj.PSObject.TypeNAmes.Insert(0, 'TeamsDeviceList')
                    }
                    $outTeamsDevices.Add($TDObj) | Out-Null
                }
            }
        }
        $outTeamsDevices | Sort-Object DeviceType,Manufacturer,Model
    }
}