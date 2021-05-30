$LocalPackageSourceKey = 'Mimp.LocalPackageSource'
$SearchPathKey = 'Mimp.PackSearchPath'

$SearchPath = [Environment]::GetEnvironmentVariable($SearchPathKey, 'User');
if ([string]::IsNullOrWhiteSpace($SearchPath)) {
    $SearchPath = $PSScriptRoot
}
if (![string]::IsNullOrWhiteSpace($SearchPath)) {
    Write-Host "Default search path: $SearchPath"
}

do {
    $Input = Read-Host "Search path"
    if (![string]::IsNullOrWhiteSpace($Input)) {
        $SearchPath = $Input
        $Use = (Read-Host "Set as default [Y|N]").Trim().ToUpper()
        if ($Use -eq "Y" -or [string]::IsNullOrWhiteSpace($Use)) {
            [Environment]::SetEnvironmentVariable($SearchPathKey, $SearchPath, 'User')
        }
    }
} while ([string]::IsNullOrWhiteSpace($SearchPath))

$Output = [Environment]::GetEnvironmentVariable($LocalPackageSourceKey, 'User')
if (![string]::IsNullOrWhiteSpace($Output)) {
    Write-Host "Default output: $Output"
}
do {
    $Input = Read-Host "Output"
    if (![string]::IsNullOrWhiteSpace($Input)) {
        $Output = $Input
        $Use = (Read-Host "Set as default [Y|N]").Trim().ToUpper()
        if ($Use -eq "Y") {
            [Environment]::SetEnvironmentVariable($LocalPackageSourceKey, $Output, 'User')
        }
    }
} while ([string]::IsNullOrWhiteSpace($Output))

$Projects = @()
foreach($Project in (Get-ChildItem $SearchPath *.csproj -Recurse)) {
    if ((Select-Xml -Path $project.FullName -XPath "//OutputType[text()='Exe' or text()='WinExe']") `
        -or (Select-String -Path $project.FullName -Pattern "<OutputType>\s*(Exe|WinExe)\s*</OutputType>") `
        -or (Select-Xml -Path $project.FullName -XPath "//Project[@Sdk='Microsoft.NET.Sdk.Web']")) {
        Write-Debug "Skip $($project.BaseName) because it isn't a library"
        continue
    }
    Write-Host "[$($Projects.Count)]: $($Project.BaseName) - $($Project.FullName)"
    $Projects += $Project
}
Write-Host "[A]: All"


$Input = (Read-Host "Pack project(s)").Split(",")

$Packs = [System.Collections.Generic.HashSet[System.IO.FileInfo]]@()
foreach($o in $Input) {
    $x = $o.Trim().ToUpper()
    if ($x -eq "A" -or $x -eq "") {
        foreach ($p in $Projects) {
            $Packs += $p
        }
    } else {
        if($x -match '\s*\d+\s*-\s*\d+\s*') {
            $ps = $x -split '-'
            for ($i = [int]($ps[0].Trim()); $i -le [int]($ps[1].Trim()); $i++) {
                $Packs += $Projects[$i]
            }
        } else {
           $Packs += $Projects[[int]$x]
        }
    }
}

$Configuration = (Read-Host "[R]elease|[D]ebug").Trim().ToUpper()
if ($Configuration -eq "R" -or $Configuration -eq "") {
    $Configuration = "Release"
} else {
    $Configuration = "Debug"
}

$Successes = @()
$Failes = @()
foreach ($p in $Packs) {
    dotnet pack $p.FullName -o $Output
    if ($LastExitCode -ne 0) {
        Write-Error "Project `"$($p.BaseName)`" failed to pack"
        $Failes += $p
        continue
    }
    $Successes += $p
}

Write-Host
$Msg = "Publish $($Successes.Count) of $($Packs.Count) ($([string]::Join(", ", ($Successes | Select-Object -ExpandProperty BaseName))))"
if ($successes.Count -ne $Packs.Count) {
    Write-Warning "$Msg/($([string]::Join(", ", ($Failes | Select-Object -ExpandProperty BaseName))))"
} else {
    Write-Host $Msg -ForegroundColor Green
}
