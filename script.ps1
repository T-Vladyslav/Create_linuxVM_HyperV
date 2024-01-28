$vmParams = Import-Csv -Path "VMs.csv"
$credential = Get-Credential  # "domain\user"
$copyIso = $False
$clusterVm = $True
$sharePath = '\\vd-adm-44\Install\OracleLinux-R8-U8-x86_64-dvd.iso'
$isoDestination = 'C:\Install'

foreach ($vm in $vmParams) {
    Invoke-Command -ComputerName $vm.'Parent Host Name' -Credential $credential -ScriptBlock {
        param($vm, $credential, $sharePath, $isoDestination, $copyIso, $clusterVm)

        # Write-Host "------------------------------------------------------------------------"
        # Write-Host "Deploying VM $($vm.'VM Name') on the $($vm.'Parent Host Name')"
        # Write-Host "------------------------------------------------------------------------"

        # # Retrieving the list of switches on the target host
        # Write-Host -fore Yellow 'Identifying the switch name on the target host...'
        # $switches = Get-VMSwitch
        # $switchCount = $switches.Count

        # # Check the number of switches
        # $SwitchName = $null
        # if ($switchCount -gt 1) {
        #     Write-Host -fore Cyan "Multiple virtual switches detected on the host $($vm.'Parent Host Name'). Please select one from the $($vm.'VM Name'):"
        #     for ($i = 0; $i -lt $switchCount; $i++) {
        #         Write-Host "$i. $($switches[$i].Name)"
        #     }
        #     $selectedSwitchIndex = Read-Host "Enter the number of the switch you want to use (0-$($switchCount-1))"
        #     $SwitchName = $switches[$selectedSwitchIndex].Name
        # } elseif ($switchCount -eq 1) {
        #     $SwitchName = $switches[0].Name
        # } else {
        #     Write-Host -fore Red "No virtual switches found on the host."
        #     return
        # }

        # # Create a virtual machine
        # Write-Host -fore Yellow 'Creating the virtual machine...'
        # New-VM -Name $vm.'VM Name' -MemoryStartupBytes ([int]$vm.RAM * 1GB) -Generation 2 -Path "$($vm.'PATH')$($vm.'VM Name')" -SwitchName $SwitchName   # .Name
        
        # # Assign the number of CPU cores
        # Write-Host -fore Yellow 'Assigning the number of CPU cores...'
        # Set-VMProcessor -VMName $vm.'VM Name' -Count $vm.CPU
        
        # # Configure the network adapter and Vlan
        # Write-Host -fore Yellow 'Configuring the network adapter and Vlan...'
        # Set-VMNetworkAdapterVlan -VMName $vm.'VM Name' -VMNetworkAdapterName 'Network Adapter' -VlanId $vm.VLAN -Access

        # # Add virtual disks
        # Write-Host -fore Yellow 'Adding virtual disks...'
        # 1..$vm.'Number of Disks' | ForEach-Object {
        #     $diskName = "$($vm.'VM Name')_Disk$_"
        #     New-VHD -Path "$($vm.'PATH')$($vm.'VM Name')\$diskName.vhdx" -SizeBytes ([int]$vm.'Disk Size' * 1GB)
        #     Add-VMHardDiskDrive -VMName $vm.'VM Name' -Path "$($vm.'PATH')$($vm.'VM Name')\$diskName.vhdx"
        # }

        # # Disable Secure Boot
        # Write-Host -fore Yellow 'Disabling Secure Boot'
        # Set-VMFirmware -VMName $vm.'VM Name' -EnableSecureBoot Off
        
        # # Atach network disc and copy iso
        # if ($copyIso) {
        #     $fileInfo = New-Object System.IO.FileInfo $sharePath
        #     $fileName = $fileInfo.Name
        #     $directoryPath = $fileInfo.DirectoryName
        #     $destinationPath = "$isoDestination\$fileName"

        #     if (Test-Path -Path $destinationPath) {
        #         Write-Host -fore Green "Checking for the presence of an iso file in $isoDestination."
        #         Write-Host -fore Yellow "The file already exists in the $destinationPath. Nothing to do."
        #     } else {
        #         Write-Host -fore Yellow "File not found in $destinationPath."
        #         Write-Host -fore Green "Starting to copy..."
        #         New-PSDrive -Name "W" -PSProvider "FileSystem" -Root "$directoryPath" -Credential $credential  #$Using:credential 
        #         $drive = Get-PSDrive W
        #         if ($drive) {
        #             Write-Host -fore Green "Created network drive at $directoryPath"
        #             Write-Host -fore Green "Copying the ISO file to $isoDestination..."
        #             Copy-Item -Path "$sharePath" -Destination "$isoDestination"
        #             remove-PSDrive -Name "W"
        #             if (Test-Path -Path $destinationPath) {
        #                 Write-Host -fore Green "ISO image successfully copied."
        #             } else {
        #                 Write-Host -fore Red "ISO image not copied."
        #             }
        #         } else {
        #             Write-Host -fore Red "Network drive does'n exist"
        #         }
        #     }
        # } else {
        #     Write-Host -fore Green 'Copying of the iso image has been disabled by the user.'
        # }       

        # # Setup boot from CD and map install image
        # Write-Host -fore Yellow 'Setting boot from CD and mapping install image...'
        # $isoPath = "C:\Install\OracleLinux-R8-U8-x86_64-dvd.iso"
        # Add-VMDvdDrive -VMName $vm.'VM Name' -Path $isoPath
        # Set-VMFirmware -VMName $vm.'VM Name' -FirstBootDevice (Get-VMDvdDrive -VMName $vm.'VM Name')

        # Adding virtual machines to the cluster using the task scheduler 
        if ($clusterVm) {

            Write-Host -fore Yellow 'Adding VM to the cluster...'
            ## Retrieving the credentials
            $username = $credential.UserName
        
            ## Retrieving the password in plain text
            $pinpt = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential.Password)
            $password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($pinpt) 
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pinpt)
            
            
            ## Creating task to the task scheduler
            $taskName = "Add_VM_to_cluster"
            $taskEnd = 10 # time of task life in seconds
            
            $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -WindowStyle Hidden -Command "& {$currentTime = Get-Date; $timeAgo = $currentTime.AddHours(-2); $recentVMs = Get-VM | Where-Object { $_.CreationTime -gt $timeAgo }; foreach ($vm in $recentVMs) { Add-ClusterVirtualMachineRole -VMName $vm.Name}}"'
            $taskSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Seconds $taskEnd)
            Register-ScheduledTask -TaskName $taskName -Action $taskAction -Settings $taskSettings -User $username -Password $password -RunLevel Highest -Force
            
            ## Deleting open password
            $password = $null

            ## Run task and delete
            Start-ScheduledTask -TaskName $taskName
            $taskLife = $taskEnd + 5
            Start-Sleep -Seconds $taskLife
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        # Write-Host "------------------------------------------------------------------------"
        # Write-Host "Deploying VM $($vm.'VM Name') on the $($vm.'Parent Host Name') completed."
        # Write-Host "------------------------------------------------------------------------"

    } -ArgumentList $vm, $credential, $sharePath, $isoDestination, $copyIso, $clusterVm
}

