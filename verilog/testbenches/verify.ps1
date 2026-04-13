$modules = @("and_gate", "mux2", "half_adder", "full_adder", "dff", "counter4", "alu8")
$pass = 0
$fail = 0

# Work from the verilog/ directory so iverilog sees short relative paths
$verilogDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Push-Location $verilogDir

$deps = @{
    "full_adder" = @("half_adder.v")
}

foreach ($mod in $modules) {
    $src = "$mod.v"
    $tb  = "testbenches\testbench_$mod.v"
    $sim = Join-Path $env:TEMP "sim_$mod"

    if (-not (Test-Path $src)) {
        Write-Host "SKIP  $mod  ($mod.v not found)"
        continue
    }

    $extra = if ($deps.ContainsKey($mod)) { $deps[$mod] } else { @() }

    # Compile
    $argList = @("-o", $sim, $tb, $src) + $extra
    $compile = & iverilog @argList 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL  $mod  (compile error)"
        Write-Host $compile
        $fail++
        continue
    }

    # Simulate
    $output = & vvp $sim 2>&1
    if ($output -match "^PASS") {
        Write-Host "PASS  $mod"
        $pass++
    } else {
        Write-Host "FAIL  $mod"
        $output | Where-Object { $_ -ne "" } | ForEach-Object { Write-Host "      $_" }
        $fail++
    }
}

Pop-Location

Write-Host ""
Write-Host "Results: $pass passed, $fail failed"
if ($fail -gt 0) { exit 1 } else { exit 0 }
