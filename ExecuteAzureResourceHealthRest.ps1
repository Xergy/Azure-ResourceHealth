
# .\AzureResourceHealthRest.ps1 -SubscriptionId '<Your Subscription ID>' -ResourceGroups @('LinuxAgent','DomainJoin') -StorageAccountResourceGroup "ResourceHealthTracker" -StorageAccountName "resourcehealthtracker"


.\AzureResourceHealthRest.ps1 -SubscriptionId 'ed347077-d367-4401-af11-a87b73bbae0e' -ResourceGroups @('Prod-Rg','F5-RG') -StorageAccountResourceGroup "Prod-Rg" -StorageAccountName "diagsa"