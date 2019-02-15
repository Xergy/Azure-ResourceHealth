<#
    .SYNOPSIS
        Get information regarding Azure resource health and write it to an Azure storage table

    .PARAMETER SubscriptionId
        The subscription Id for the subscription to be monitored

    .PARAMETER ResourceGroups
        Array of resource groups to be monitored

    .PARAMETER StorageAccountResourceGroup
        Resource group of storage account to write health data to

    .PARAMETER storageAccountName
        Name of storage account to write health data to

    .PARAMETER TableName
        Name of table to write health data to

    .PARAMETER ManagementUri
        Management Uri of Azure Env to connect to

        List all Management URIs with command (Get-AzureRmEnvironment).ResourceManagerUrl

    .EXAMPLE
        AzureResourceHealthRest `
            -SubscriptionId '<Your Subscription ID>' `
            -ResourceGroups @(
                'LinuxAgent'
                'DomainJoin'
            ) `
            -StorageAccountResourceGroup "ResourceHealthTracker" `
            -StorageAccountName "resourcehealthtracker"
#>   
function Set-AzureResourceHealth {
 
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory)]
        $SubscriptionId,
    
        [parameter(Mandatory)]
        $ResourceGroups,
    
        [parameter(Mandatory)]
        $StorageAccountResourceGroup,
    
        [parameter(Mandatory)]
        $StorageAccountName,
    
        $TableName = "resourcehealthtracker",
    
        $ManagementUri = 'https://management.usgovcloudapi.net'
    )

    process {

        Import-Module AzureRmStorageTable

        # setup table to write to
        $storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $StorageAccountResourceGroup -Name $storageAccountName
        
        $healthTable = Get-AzureStorageTable -Name $TableName -Context $storageAccount.Context -ErrorAction SilentlyContinue
        
        if(-not $healthTable)
        {
            Write-Output "Creating table $TableName"
        
            $healthTable = New-AzureStorageTable –Name $TableName –Context $storageAccount.Context
        }
        
        # check resource health
        # $rmAccount = Add-AzureRmAccount -SubscriptionId $subscriptionId -Environment "AzureUSGovernment"
        $rmAccount = Get-AzureRmContext
        Write-Output "Get-AzureRmContext"
        Get-AzureRmContext

        Write-Output "Get-AzureRmSubscription"
        Get-AzureRmSubscription

        $tenantId = (Get-AzureRmSubscription -SubscriptionId $subscriptionId).TenantId
        Write-Output "tenantId"
        $tenantId

        $tokenCache = $rmAccount.TokenCache
        Write-Output "tokenCache"
        $tokenCache 

        Write-Output "tokenCache gm"        
        $tokenCache | gm

        Write-Output "tokenCache.ReadItems"  
        $tokenCache.ReadItems()

        #$cachedTokens = $tokenCache.ReadItems() `
        #        | where { $_.TenantId -eq $tenantId } `
        #        | Sort-Object -Property ExpiresOn -Descending
        
        $cachedTokens = $tokenCache.ReadItems() | Sort-Object -Property ExpiresOn -Descending

        Write-Output "cachedTokens"
        $cachedTokens 

        $accessToken = $cachedTokens[0].AccessToken
        Write-Output "accessToken"
        $accessToken  
        
        #while($true)
        #{
            foreach($resourceGroup in $ResourceGroups)
            {
                $provider = 'providers/Microsoft.ResourceHealth/availabilityStatuses?api-version=2015-01-01'
                $uri = "$ManagementUri/subscriptions/$SubscriptionId/resourceGroups/$resourceGroup/$provider"
        
                $responce = Invoke-RestMethod `
                    -Method Get `
                    -Uri $uri `
                    -Headers @{ "Authorization" = "Bearer " + $accessToken }
        
                $responce = $responce.value | Where-Object {$_.id -like "*Microsoft.Compute/virtualMachines*" }
        
                foreach($resource in $responce )
                {
                    $resource.id
        
                    if($resource.properties.availabilityState -ne "Available")
                    {
                        Write-Warning $resource.properties.availabilityState
                        Write-Output $resource.properties
                    }
                    else
                    {
                        Write-Output $resource.properties.availabilityState
                        Write-Output $resource.properties
                    }
                    ""
        
                    $partitionKey = "ResourceId"
                    $addTableParams = @{
                        Table = $healthTable
                        PartitionKey = $partitionKey
                        RowKey = ([guid]::NewGuid().tostring())
                        Property = @{
                            $partitionKey = $resource.id
                            AvailabilityState = $resource.properties.availabilityState
                            Summary = $resource.properties.summary
                            DetailedStatus = $resource.properties.detailedStatus
                            ReasonType = $resource.properties.reasonType
                            OccuredTime = $resource.properties.occuredTime
                            ReasonChronicity = $resource.properties.reasonChronicity
                            ReportedTime = $resource.properties.reportedTime
                        }
                    }
                    Add-StorageTableRow @addTableParams
                }
            }
        
        #    Start-Sleep -Seconds 60
        #}
    } #process
} #fuction


#$conn = Get-AutomationConnection -Name AzureRunAsConnection
#Add-AzureRMAccount -ServicePrincipal -Tenant $conn.TenantID -ApplicationID $conn.ApplicationID -CertificateThumbprint $conn.CertificateThumbprint -EnvironmentName AzureUSGovernment

Set-AzureResourceHealth -SubscriptionId 'ed347077-d367-4401-af11-a87b73bbae0e' -ResourceGroups @('Prod-Rg','F5-RG') -StorageAccountResourceGroup "Prod-Rg" -StorageAccountName "diagsa"

