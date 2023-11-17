$vmParams = Import-Csv -Path "VMs.csv"

foreach ($vm in $vmParams) {
    Invoke-Command -ComputerName $vm.'Parent Host Name' -ScriptBlock {
        param($vm)

        # Ident the switch name on the target host
        Write-Host -fore Yellow 'Identifying the switch name on the target host...'
        $SwitchName = Get-VMSwitch

        # Create a virtual machine
        Write-Host -fore Yellow 'Creating a virtual machine...'
        New-VM -Name $vm.'VM Name' -MemoryStartupBytes ([int]$vm.RAM * 1GB) -Generation 2 -Path "C:\Hyper-V\$($vm.'VM Name')" -SwitchName $SwitchName.Name # -VHDPath "C:\Hyper-V\$($vm.'VM Name')\$($vm.'VM Name').vhdx"

        # Assign the number of CPU cores
        Write-Host -fore Yellow 'Assigning the number of CPU cores...'
        Set-VMProcessor -VMName $vm.'VM Name' -Count $vm.CPU

        # Configure the network adapter and Vlan
        Write-Host -fore Yellow 'Configuring the network adapter and Vlan...'
        Set-VMNetworkAdapterVlan -VMName $vm.'VM Name' -VMNetworkAdapterName 'Network Adapter' -VlanId $vm.VLAN -Access

        # Add virtual disks
        Write-Host -fore Yellow 'Adding virtual disks...'
        1..$vm.'Number of Disks' | ForEach-Object {
            $diskName = "$($vm.'VM Name')_Disk$_"
            New-VHD -Path "C:\Hyper-V\$($vm.'VM Name')\$diskName.vhdx" -SizeBytes ([int]$vm.'Disk Size' * 1GB)
            Add-VMHardDiskDrive -VMName $vm.'VM Name' -Path "C:\Hyper-V\$($vm.'VM Name')\$diskName.vhdx"
        }

        # Disable Secure Boot
        Write-Host -fore Yellow 'Disabling Secure Boot'
        Set-VMFirmware -VMName $vm.'VM Name' -EnableSecureBoot Off

        # Setup boot from CD and map install image
        Write-Host -fore Yellow 'Setting boot from CD and mapping install image...'
        $isoPath = "C:\Install\OracleLinux-R8-U8-x86_64-dvd.iso"
        Add-VMDvdDrive -VMName $vm.'VM Name' -Path $isoPath
        Set-VMFirmware -VMName $vm.'VM Name' -FirstBootDevice (Get-VMDvdDrive -VMName $vm.'VM Name')
    } -ArgumentList $vm
}
