# this script automatically discovered the index value of monitors attachedt to a Win11 system
# once discovered, the index values are used to start a Remote Desktop session.

# this tool is useful because on Win11 systems with multiple monitors, the monitor index can
# change between restarts.

# this script is a modification of the script originally found here:
# https://superuser.com/questions/1695016/grabbing-the-output-of-windows-message-box-to-a-string
#

Add-Type -AssemblyName 'UIAutomationClient'

# Start mstsc.exe with the argument /l, retain a process reference in $mstscProc
#
$mstscProc = Start-Process -FilePath 'mstsc.exe' -ArgumentList '/l' -PassThru

try {

  $handle = $null

  # MainWindowHandle sometimes returns 0, this while loop is a workaround
  #
  while ((-not $mstscProc.HasExited) -and ($null -eq $handle))
  {
    Start-Sleep -Milliseconds 500
    $mstscProc.Refresh()
    if ($mstscProc.MainWindowHandle -ne 0)
    {
      $handle = $mstscProc.MainWindowHandle
    }
  }

  $cTrue = [System.Windows.Automation.PropertyCondition]::TrueCondition

  # Get the root element of the mstsc.exe process by handle
  #
  $root = [System.Windows.Automation.AutomationElement]::FromHandle($handle)

  # Use inspect.exe from the WinSDK to determine the AutomationId for the text element
  #
  $rawText = $root.FindAll("Children", $cTrue) | 
    Select-Object -ExpandProperty Current | 
    Where-Object AutomationId -ieq 'ContentText' | 
    Select-Object -ExpandProperty Name  
}
finally {
  $mstscProc | Stop-Process -Force  
}

# split the raw text one line at a time and store the ouput in the $monitors variable
#
$monitors = $rawText -split '\r?\n' | ForEach-Object {
  $parts = @()
  try {

    # Convert the line format "0: 1920 x 1080; (0, 0, 1919, 1079)" into numbers seperated by , then split
    #
    $parts = @($_.replace(':', ',').replace(' x ', ',').replace(';', ',').replace('(', '').replace(')', '').replace(' ', '').Trim() -split ',')    
  }
  catch {

    # if any exceptions occur we assume the line is malformed
    #
    $_ | Write-Verbose
  }
  
  if ($parts.Length -eq 7 -and [int]$parts[1] -eq 1440) {

    # a wellformed line should have 7 parts
    #
    $properties = [ordered]@{
      Index = [int]$parts[0]
      Width = [int]$parts[1]
      Height = [int]$parts[2]
      Left = [int]$parts[3]
      Top = [int]$parts[4]
      Right = [int]$parts[5]
      Bottom = [int]$parts[6]
    }

    New-Object -TypeName psobject -Property $properties | Write-Output
  }
}

#$firstMonitor = $monitors | ? { $_.Index -eq 2 }
#$secondMonitor = $monitors | ? { $_.Left -eq 1 }
#$thirdMonitor = $monitors | ? { $_.Left -eq 2 }

$firstMonitor = $monitors[0]
$secondMonitor = $monitors[1]
$thirdMonitor = $monitors[2]

$replaceString = "selectedmonitors:s:{0},{1},{2}" -f $firstMonitor.Index, $secondMonitor.Index, $thirdMonitor.Index

#$replaceString | Write-Output

# this template should be created in advance
#
$rdpTemplatePath = "C:\Users\okonkch\OneDrive - BECU\Desktop\w11.rdp"

$newRdpContent = (gc $rdpTemplatePath) -replace "selectedmonitors:s:0,1,2", $replaceString
$tempFile = Join-Path $env:TEMP "temp.rdp"
$newRdpContent > $tempFile
start $tempFile
