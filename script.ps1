$vmParams = Import-Csv -Path "VMs.csv"
$credential = Get-Credential                                            # -Credential "domain\user"
$sharePath = '\\vd-adm-44\Install\OracleLinux-R8-U8-x86_64-dvd.iso'
$isoDestination = 'C:\Install'

foreach ($vm in $vmParams) {
    Invoke-Command -ComputerName $vm.'Parent Host Name' -ScriptBlock { #-Credential $credential 
        param($vm, $credential, $sharePath, $isoDestination)

        Write-Host "Deploying VM $vm.'VM Name' on the $vm.'Parent Host Name'"
        Write-Host "------------------------------------------------------------------------"

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
        
        # Atach network disc and copy iso
        $fileInfo = New-Object System.IO.FileInfo $sharePath
        $fileName = $fileInfo.Name
        $directoryPath = $fileInfo.DirectoryName
        $destinationPath = "$isoDestination\$fileName"

        if (Test-Path -Path $destinationPath) {
            Write-Host -fore Green "Checking for the presence of an iso file in $isoDestination."
            Write-Host -fore Yellow "The file already exists in the $destinationPath. Nothing to do."
        } else {
            Write-Host -fore Yellow "File not found in $destinationPath."
            Write-Host -fore Green "Starting to copy..."
            New-PSDrive -Name "W" -PSProvider "FileSystem" -Root "$directoryPath" -Credential $credential  #$Using:credential 
            $drive = Get-PSDrive W
            if ($drive) {
                Write-Host -fore Green "Created network drive at $directoryPath"
                Write-Host -fore Green "Copying the ISO file to $isoDestination..."
                Copy-Item -Path "$sharePath" -Destination "$isoDestination"
                remove-PSDrive -Name "W"
                if (Test-Path -Path $destinationPath) {
                    Write-Host -fore Green "ISO image successfully copied."
                } else {
                    Write-Host -fore Red "ISO image not copied."
                }
            } else {
                Write-Host -fore Red "Network drive does'n exist"
            }
        }        

        # Setup boot from CD and map install image
        Write-Host -fore Yellow 'Setting boot from CD and mapping install image...'
        $isoPath = "C:\Install\OracleLinux-R8-U8-x86_64-dvd.iso"
        Add-VMDvdDrive -VMName $vm.'VM Name' -Path $isoPath
        Set-VMFirmware -VMName $vm.'VM Name' -FirstBootDevice (Get-VMDvdDrive -VMName $vm.'VM Name')

        Write-Host "Deploying VM $vm.'VM Name' on the $vm.'Parent Host Name' completed."
        Write-Host "------------------------------------------------------------------------"

    } -ArgumentList $vm, $credential, $sharePath, $isoDestination
}

