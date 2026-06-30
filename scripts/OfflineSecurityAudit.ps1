param(
    [string]$SolutionRoot = "."
)

Write-Host ""
Write-Host "========================================"
Write-Host " MyCompanyApp Offline Security Audit"
Write-Host "========================================"
Write-Host ""

$patterns = @(
"System.Net",
"System.Net.Http",
"System.Net.Sockets",
"HttpClient",
"HttpWebRequest",
"WebRequest",
"WebClient",
"Socket",
"TcpClient",
"UdpClient",
"Dns",
"FtpWebRequest",
"Grpc",
"SignalR"
)

$files = Get-ChildItem $SolutionRoot -Recurse -Include *.cs

$violations = @()

foreach ($file in $files)
{
    $content = Get-Content $file.FullName

    for($i=0;$i -lt $content.Length;$i++)
    {
        $line = $content[$i]

        foreach($p in $patterns)
        {
            if($line -match $p)
            {
                $violations += [PSCustomObject]@{
                    File = $file.FullName
                    Line = $i + 1
                    Pattern = $p
                    Code = $line.Trim()
                }
            }
        }
    }
}

if($violations.Count -gt 0)
{
    Write-Host ""
    Write-Host "INTERNET USAGE DETECTED" -ForegroundColor Red
    Write-Host ""

    $violations | ForEach-Object {
        Write-Host "File :" $_.File -ForegroundColor Yellow
        Write-Host "Line :" $_.Line
        Write-Host "API  :" $_.Pattern
        Write-Host "Code :" $_.Code
        Write-Host ""
    }

    Write-Host "Build blocked for security reasons." -ForegroundColor Red
    exit 1
}
else
{
    Write-Host "No internet APIs detected." -ForegroundColor Green
}
