rm -Recurse -Force "$PsScriptRoot\publish" -ErrorAction Continue
rm -Force "$PSScriptRoot\deploy.zip"
mkdir "$PsScriptRoot\publish"
mkdir "$PsScriptRoot\publish\YOURAPPNAME"
cp "$PsScriptRoot\aws-windows-deployment-manifest.json" "$PsScriptRoot\publish\"
& dotnet publish "$PsScriptRoot\..\YOURAPPNAME" -c Release -f net461 -o "$PsScriptRoot\publish\YOURAPPNAME"

Add-Type -Assembly "System.IO.Compression.FileSystem"
[System.IO.Compression.ZipFile]::CreateFromDirectory("$PsScriptRoot\publish", "$PSScriptRoot\deploy.zip")

# https://github.com/rsgfernandes/ebclideploy/blob/master/ebclideploy.ps1
$date = Get-Date -format "yyyyMMd-HHmmss"
$region = "YOURREGION"
$accesskey = "YOURACCESSKEY"
$secretkey = Get-Content "$PSScriptRoot\key.txt" -Raw
$appname = "YOURAPPNAME"
$envname = "YOURAPPNAME-Dev"
$versionlabel = 'Deploy-'+$date
$s3bucket = "YOURS3BUCKETNAME"
$s3key = "YOURAPPNAME-$date.zip"

Set-AWSCredentials -AccessKey $accesskey -SecretKey $secretkey
Initialize-AWSDefaults -Region $region
Write-S3Object -BucketName $s3bucket -File "$PSScriptRoot\deploy.zip" -Key $s3key
New-EBApplicationVersion -ApplicationName $appname -VersionLabel $versionlabel -Description "'Deploy number' + $date" -SourceBundle_S3Bucket $s3bucket -SourceBundle_S3Key $s3key
Update-EBEnvironment -EnvironmentName $envname -VersionLabel $versionlabel

Write-Output "Deploying $versionLabel..."
$env = Get-EBEnvironment -EnvironmentName $envname
while ($env.Status -eq "Updating") {
    Write-Output "$(Get-Date -format "yyyy-MM-dd HH:mm:ss") $($env.Status)"
    Start-Sleep -Seconds 3
    $env = Get-EBEnvironment -EnvironmentName $envname
}

if ($env.Status -ne "Ready") {
    throw $env
} else {
    Write-Output "Successfully deployed"
    $env
}
