# deploy-task.ps1
param()

$location = "uksouth"
$resourceGroupName = "mate-azure-task-12"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub"
$publicIpAddressName = "linuxboxpip"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$dnsLabel = "matetask$(Get-Random -Maximum 9999)"

# 1. Створення групи ресурсів
Write-Host "Step 1/8: Creating resource group..."
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force | Out-Null

# 2. Створення NSG
Write-Host "Step 2/8: Creating network security group..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 `
    -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 `
    -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName `
    -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP | Out-Null

# 3. Створення VNet та підмережі
Write-Host "Step 3/8: Creating virtual network..."
$nsg = Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $nsg
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName `
    -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet | Out-Null

# 4. Додавання SSH ключа
Write-Host "Step 4/8: Adding SSH key..."
New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey | Out-Null

# 5. Створення публічної IP
Write-Host "Step 5/8: Creating public IP..."
$publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName `
    -Location $location -Sku Basic -AllocationMethod Dynamic -DomainNameLabel $dnsLabel

# 6. Створення віртуальної машини
Write-Host "Step 6/8: Creating virtual machine..."
$vm = New-AzVm -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location $location `
    -Image $vmImage `
    -Size $vmSize `
    -SubnetName $subnetName `
    -VirtualNetworkName $virtualNetworkName `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName `
    -PublicIpAddressName $publicIpAddressName

# 7. Налаштування Custom Script Extension
Write-Host "Step 7/8: Configuring Custom Script Extension..."
# Очікуємо, поки VM буде готова
Start-Sleep -Seconds 30

$settings = @{
    "fileUris" = @("https://raw.githubusercontent.com/vhurna/azure_task_12_deploy_app_with_vm_extention/main/install-app.sh")
    "commandToExecute" = "bash install-app.sh"
}

# Видаляємо існуюче розширення, якщо воно є
$existing = Get-AzVMExtension -ResourceGroupName $resourceGroupName -VMName $vmName -Name "CustomScriptExtension" -ErrorAction SilentlyContinue
if ($existing) {
    Remove-AzVMExtension -ResourceGroupName $resourceGroupName -VMName $vmName -Name "CustomScriptExtension" -Force | Out-Null
    Start-Sleep -Seconds 20
}

# Встановлюємо розширення
Set-AzVMExtension -ResourceGroupName $resourceGroupName `
    -Location $location `
    -VMName $vmName `
    -Name "CustomScriptExtension" `
    -Publisher "Microsoft.Azure.Extensions" `
    -ExtensionType "CustomScript" `
    -TypeHandlerVersion "2.1" `
    -Settings $settings | Out-Null

# 8. Фінальний вивід
Write-Host "Step 8/8: Deployment complete!"
Write-Host "=============================================="
Write-Host "Web application URL: http://$($publicIp.DnsSettings.Fqdn):8080"
Write-Host "SSH access: ssh azureuser@$($publicIp.DnsSettings.Fqdn)"
Write-Host "=============================================="