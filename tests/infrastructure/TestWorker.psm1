Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-GodotExecutable {
    [CmdletBinding()]
    param([string]$GodotPath)

    if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
        if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
            throw "Godot executable does not exist: $GodotPath"
        }
        return (Resolve-Path -LiteralPath $GodotPath).Path
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_PATH) -and
        (Test-Path -LiteralPath $env:GODOT_PATH -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $env:GODOT_PATH).Path
    }

    $command = Get-Command `
        'Godot*_console.exe', 'godot*.exe', 'godot' `
        -CommandType Application `
        -ErrorAction SilentlyContinue |
        Sort-Object -Property @{ Expression = { if ($_.Name -like '*console*') { 0 } else { 1 } } }, Name |
        Select-Object -First 1
    if ($null -eq $command) {
        throw 'Godot executable was not found. Pass -GodotPath or set GODOT_PATH.'
    }
    return $command.Source
}

function ConvertTo-PowerShellLiteral {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    return "'$($Value.Replace("'", "''"))'"
}

function ConvertTo-ProcessArgument {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    if ($Value -notmatch '[\s"]') {
        return $Value
    }
    return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

function Get-TestOutputDiagnostics {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Output)

    $shutdownDiagnostics = [System.Collections.Generic.List[string]]::new()
    $runtimeErrors = [System.Collections.Generic.List[string]]::new()
    $inVerboseLeakDump = $false
    foreach ($line in @($Output -split '\r?\n')) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^(?:Leaked instance:|Orphan StringName:|StringName: \d+ unclaimed)') {
            $inVerboseLeakDump = $true
        }

        $isShutdownDiagnostic = $trimmed -match '(?i)(?:' +
            'ObjectDB instances (?:were )?leaked at exit|' +
            'RID allocations?.*leaked at exit|' +
            'allocations? of type .* leaked at exit|' +
            'resources? still in use at exit|' +
            'Pages in use exist at exit' +
            ')'
        $isVerboseLeakPathDiagnostic = $inVerboseLeakDump -and
            $trimmed -match '(?i)^ERROR:\s*Cannot get path of node as it is not in a scene tree\.?$'
        if ($isShutdownDiagnostic -or $isVerboseLeakPathDiagnostic) {
            $shutdownDiagnostics.Add($trimmed)
            continue
        }

        if ($trimmed -match '(?i)^(?:SCRIPT ERROR|ERROR):' -or
            $trimmed -match '(?i)(?:Failed loading resource|Failed to load)') {
            $runtimeErrors.Add($trimmed)
        }
    }

    return [pscustomobject]@{
        shutdown_diagnostics_present = $shutdownDiagnostics.Count -gt 0
        shutdown_diagnostic_count = $shutdownDiagnostics.Count
        shutdown_diagnostics = @($shutdownDiagnostics)
        runtime_error_count = $runtimeErrors.Count
        runtime_errors = @($runtimeErrors)
    }
}

function Get-TestOutcome {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Output,
        [Parameter(Mandatory)][bool]$TimedOut
    )

    $diagnostics = Get-TestOutputDiagnostics -Output $Output
    if ($TimedOut) {
        return [pscustomobject]@{
            status = 'ERROR'
            detail = 'timeout'
            shutdown_diagnostics_present = $diagnostics.shutdown_diagnostics_present
            shutdown_diagnostic_count = $diagnostics.shutdown_diagnostic_count
            shutdown_diagnostics = $diagnostics.shutdown_diagnostics
            runtime_error_count = $diagnostics.runtime_error_count
            runtime_errors = $diagnostics.runtime_errors
        }
    }
    if ($diagnostics.runtime_error_count -gt 0) {
        return [pscustomobject]@{
            status = 'ERROR'
            detail = 'runtime error marker'
            shutdown_diagnostics_present = $diagnostics.shutdown_diagnostics_present
            shutdown_diagnostic_count = $diagnostics.shutdown_diagnostic_count
            shutdown_diagnostics = $diagnostics.shutdown_diagnostics
            runtime_error_count = $diagnostics.runtime_error_count
            runtime_errors = $diagnostics.runtime_errors
        }
    }
    if ($Output -match '(?im)\bFAIL(?:ED|URE)?\b' -or $ExitCode -ne 0) {
        return [pscustomobject]@{
            status = 'FAIL'
            detail = if ($ExitCode -ne 0) { "exit code $ExitCode" } else { 'failure marker' }
            shutdown_diagnostics_present = $diagnostics.shutdown_diagnostics_present
            shutdown_diagnostic_count = $diagnostics.shutdown_diagnostic_count
            shutdown_diagnostics = $diagnostics.shutdown_diagnostics
            runtime_error_count = $diagnostics.runtime_error_count
            runtime_errors = $diagnostics.runtime_errors
        }
    }
    if ($Output -match '(?im)\bPASS(?:ED)?\b') {
        return [pscustomobject]@{
            status = 'PASS'
            detail = if ($diagnostics.shutdown_diagnostics_present) {
                "pass marker; shutdown diagnostics=$($diagnostics.shutdown_diagnostic_count)"
            } else {
                'pass marker'
            }
            shutdown_diagnostics_present = $diagnostics.shutdown_diagnostics_present
            shutdown_diagnostic_count = $diagnostics.shutdown_diagnostic_count
            shutdown_diagnostics = $diagnostics.shutdown_diagnostics
            runtime_error_count = $diagnostics.runtime_error_count
            runtime_errors = $diagnostics.runtime_errors
        }
    }
    return [pscustomobject]@{
        status = 'ERROR'
        detail = 'missing PASS/FAIL completion marker'
        shutdown_diagnostics_present = $diagnostics.shutdown_diagnostics_present
        shutdown_diagnostic_count = $diagnostics.shutdown_diagnostic_count
        shutdown_diagnostics = $diagnostics.shutdown_diagnostics
        runtime_error_count = $diagnostics.runtime_error_count
        runtime_errors = $diagnostics.runtime_errors
    }
}

function New-TestProcess {
    param(
        [Parameter(Mandatory)]$Test,
        [Parameter(Mandatory)][string]$GodotPath,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RunRoot,
        [Parameter(Mandatory)][int]$Ordinal
    )

    $safeId = ([string]$Test.id) -replace '[^A-Za-z0-9_.-]', '_'
    $workerRoot = Join-Path $RunRoot ('{0:D3}-{1}' -f $Ordinal, $safeId)
    $userDataRoot = Join-Path $workerRoot 'godot-user-home'
    $appDataRoot = Join-Path $workerRoot 'appdata'
    $localAppDataRoot = Join-Path $workerRoot 'localappdata'
    $stdoutPath = Join-Path $workerRoot 'stdout.log'
    $stderrPath = Join-Path $workerRoot 'stderr.log'
    New-Item -ItemType Directory -Path $userDataRoot, $appDataRoot, $localAppDataRoot -Force | Out-Null

    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add('--headless')
    $arguments.Add('--path')
    $arguments.Add($RepoRoot)
    if ([string]$Test.entry_type -eq 'script') {
        $arguments.Add('--script')
    }
    $arguments.Add([string]$Test.path)

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.WorkingDirectory = $RepoRoot
    $startInfo.Environment['GODOT_USER_HOME'] = $userDataRoot
    $startInfo.Environment['APPDATA'] = $appDataRoot
    $startInfo.Environment['LOCALAPPDATA'] = $localAppDataRoot
    if ($startInfo.PSObject.Properties.Name -contains 'ArgumentList') {
        foreach ($argument in $arguments) {
            $startInfo.ArgumentList.Add($argument)
        }
    } else {
        $startInfo.Arguments = (@($arguments) | ForEach-Object {
            ConvertTo-ProcessArgument -Value $_
        }) -join ' '
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Failed to start Godot for test '$($Test.id)'."
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    $quotedArguments = @($arguments | ForEach-Object { ConvertTo-PowerShellLiteral -Value $_ })
    $reproductionCommand = @(
        "`$env:GODOT_USER_HOME = $(ConvertTo-PowerShellLiteral -Value $userDataRoot)"
        "`$env:APPDATA = $(ConvertTo-PowerShellLiteral -Value $appDataRoot)"
        "`$env:LOCALAPPDATA = $(ConvertTo-PowerShellLiteral -Value $localAppDataRoot)"
        "& $(ConvertTo-PowerShellLiteral -Value $GodotPath) $($quotedArguments -join ' ')"
    ) -join '; '

    return [pscustomobject]@{
        test = $Test
        process = $process
        stdout_task = $stdoutTask
        stderr_task = $stderrTask
        stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        timeout_seconds = [int]$Test.timeout_seconds
        worker_root = $workerRoot
        user_data_dir = $userDataRoot
        app_data_dir = $appDataRoot
        local_app_data_dir = $localAppDataRoot
        stdout_path = $stdoutPath
        stderr_path = $stderrPath
        reproduction_command = $reproductionCommand
        execution_mode = if ([bool]$Test.parallel_safe -and -not [bool]$Test.writes_user_data) {
            'parallel'
        } else {
            'exclusive'
        }
    }
}

function Complete-TestProcess {
    param(
        [Parameter(Mandatory)]$Worker,
        [Parameter(Mandatory)][bool]$TimedOut
    )

    if ($TimedOut -and -not $Worker.process.HasExited) {
        try {
            $Worker.process.Kill($true)
        } catch {
            & taskkill.exe /PID $Worker.process.Id /T /F | Out-Null
        }
        if (-not $Worker.process.WaitForExit(5000) -and -not $Worker.process.HasExited) {
            & taskkill.exe /PID $Worker.process.Id /T /F | Out-Null
            [void]$Worker.process.WaitForExit(5000)
        }
    } else {
        $Worker.process.WaitForExit()
    }
    $Worker.stopwatch.Stop()
    $stdout = if ($Worker.stdout_task.Wait(5000)) {
        $Worker.stdout_task.GetAwaiter().GetResult()
    } else {
        ''
    }
    $stderr = if ($Worker.stderr_task.Wait(5000)) {
        $Worker.stderr_task.GetAwaiter().GetResult()
    } else {
        ''
    }
    Set-Content -LiteralPath $Worker.stdout_path -Value $stdout -NoNewline
    Set-Content -LiteralPath $Worker.stderr_path -Value $stderr -NoNewline
    $combined = if ([string]::IsNullOrEmpty($stderr)) { $stdout } else { "$stdout`n$stderr" }
    $exitCode = if ($Worker.process.HasExited) { $Worker.process.ExitCode } else { -1 }
    $outcome = Get-TestOutcome -ExitCode $exitCode -Output $combined -TimedOut $TimedOut

    $metadata = [ordered]@{
        id = [string]$Worker.test.id
        status = $outcome.status
        detail = $outcome.detail
        exit_code = $exitCode
        timed_out = $TimedOut
        shutdown_diagnostics_present = $outcome.shutdown_diagnostics_present
        shutdown_diagnostic_count = $outcome.shutdown_diagnostic_count
        shutdown_diagnostics = $outcome.shutdown_diagnostics
        runtime_error_count = $outcome.runtime_error_count
        runtime_errors = $outcome.runtime_errors
        duration_seconds = [Math]::Round($Worker.stopwatch.Elapsed.TotalSeconds, 3)
        execution_mode = $Worker.execution_mode
        parallel_safe = [bool]$Worker.test.parallel_safe
        writes_user_data = [bool]$Worker.test.writes_user_data
        timeout_seconds = [int]$Worker.test.timeout_seconds
        user_data_dir = $Worker.user_data_dir
        app_data_dir = $Worker.app_data_dir
        local_app_data_dir = $Worker.local_app_data_dir
        stdout_path = $Worker.stdout_path
        stderr_path = $Worker.stderr_path
        reproduction_command = $Worker.reproduction_command
    }
    $metadataPath = Join-Path $Worker.worker_root 'result.json'
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metadataPath
    $Worker.process.Dispose()

    return [pscustomobject]@{
        id = $metadata.id
        status = $metadata.status
        detail = $metadata.detail
        exit_code = $metadata.exit_code
        timed_out = $metadata.timed_out
        shutdown_diagnostics_present = $metadata.shutdown_diagnostics_present
        shutdown_diagnostic_count = $metadata.shutdown_diagnostic_count
        shutdown_diagnostics = $metadata.shutdown_diagnostics
        runtime_error_count = $metadata.runtime_error_count
        runtime_errors = $metadata.runtime_errors
        duration_seconds = $metadata.duration_seconds
        execution_mode = $metadata.execution_mode
        parallel_safe = $metadata.parallel_safe
        writes_user_data = $metadata.writes_user_data
        timeout_seconds = $metadata.timeout_seconds
        user_data_dir = $metadata.user_data_dir
        app_data_dir = $metadata.app_data_dir
        local_app_data_dir = $metadata.local_app_data_dir
        stdout_path = $metadata.stdout_path
        stderr_path = $metadata.stderr_path
        metadata_path = $metadataPath
        reproduction_command = $metadata.reproduction_command
        output = $combined
    }
}

function Invoke-TestWorkers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Test,
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$GodotPath,
        [ValidateRange(1, 32)][int]$Jobs = 2,
        [string]$OutputRoot
    )

    $resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    $resolvedGodotPath = Resolve-GodotExecutable -GodotPath $GodotPath
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        $runId = '{0:yyyyMMdd-HHmmss-fff}-{1}' -f (Get-Date), ([guid]::NewGuid().ToString('N').Substring(0, 8))
        $OutputRoot = Join-Path ([System.IO.Path]::GetTempPath()) "project_mag-test-worker\$runId"
    }
    $resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
    New-Item -ItemType Directory -Path $resolvedOutputRoot -Force | Out-Null

    $pending = [System.Collections.Generic.Queue[object]]::new()
    foreach ($entry in @($Test)) {
        $pending.Enqueue($entry)
    }
    $running = [System.Collections.Generic.List[object]]::new()
    $results = [System.Collections.Generic.List[object]]::new()
    $ordinal = 0

    while ($pending.Count -gt 0 -or $running.Count -gt 0) {
        for ($index = $running.Count - 1; $index -ge 0; $index--) {
            $worker = $running[$index]
            $hasExited = $worker.process.HasExited
            $timedOut = -not $hasExited -and
                $worker.stopwatch.Elapsed.TotalSeconds -ge $worker.timeout_seconds
            if ($hasExited -or $timedOut) {
                $results.Add((Complete-TestProcess -Worker $worker -TimedOut $timedOut))
                $running.RemoveAt($index)
            }
        }

        $exclusiveRunning = @($running | Where-Object { $_.execution_mode -eq 'exclusive' }).Count -gt 0
        while (-not $exclusiveRunning -and $pending.Count -gt 0 -and $running.Count -lt $Jobs) {
            $next = $pending.Peek()
            $nextIsExclusive = -not [bool]$next.parallel_safe -or [bool]$next.writes_user_data
            if ($nextIsExclusive -and $running.Count -gt 0) {
                break
            }
            $next = $pending.Dequeue()
            $ordinal++
            $worker = New-TestProcess `
                -Test $next `
                -GodotPath $resolvedGodotPath `
                -RepoRoot $resolvedRepoRoot `
                -RunRoot $resolvedOutputRoot `
                -Ordinal $ordinal
            $running.Add($worker)
            if ($worker.execution_mode -eq 'exclusive') {
                $exclusiveRunning = $true
                break
            }
        }

        if ($running.Count -gt 0) {
            Start-Sleep -Milliseconds 25
        }
    }

    $orderedResults = @($results | Sort-Object { [array]::IndexOf(@($Test.id), $_.id) })
    $summary = [pscustomobject]@{
        run_root = $resolvedOutputRoot
        jobs = $Jobs
        godot_path = $resolvedGodotPath
        total = $orderedResults.Count
        passed = @($orderedResults | Where-Object status -eq 'PASS').Count
        failed = @($orderedResults | Where-Object status -eq 'FAIL').Count
        errors = @($orderedResults | Where-Object status -eq 'ERROR').Count
        shutdown_diagnostic_tests = @(
            $orderedResults | Where-Object shutdown_diagnostics_present
        ).Count
        shutdown_diagnostic_count = (
            $orderedResults.shutdown_diagnostic_count | Measure-Object -Sum
        ).Sum
        runtime_error_count = (
            $orderedResults.runtime_error_count | Measure-Object -Sum
        ).Sum
        results = $orderedResults
    }
    $summary |
        Select-Object -Property * -ExcludeProperty results |
        Add-Member -NotePropertyName results -NotePropertyValue @(
            $orderedResults | Select-Object -Property * -ExcludeProperty output
        ) -PassThru |
        ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath (Join-Path $resolvedOutputRoot 'summary.json')
    return $summary
}

Export-ModuleMember -Function Get-TestOutcome, Get-TestOutputDiagnostics, Invoke-TestWorkers, Resolve-GodotExecutable
