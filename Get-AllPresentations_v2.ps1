# scrape website for all links containing files
# and download them to the current directory
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$FileBrowser.Description = "Select a folder"
$FileBrowser.rootfolder = "MyComputer"
$FileBrowser.SelectedPath = $initialDirectory
if ($FileBrowser.ShowDialog() -eq "OK") {
    $folder = $FileBrowser.SelectedPath
} else {
    break
}
Read-Host "This will download all presentations to: $folder (press enter to continue)"

$schedCreds = Get-Credential -Message "Enter your sched username and password (or cancel for only publically available content)"
if ($null -eq $schedCreds.UserName) {
    $schedUserName = 'blank'
} else {
    $schedUserName = $schedCreds.UserName
    $schedPassword = $schedCreds.GetNetworkCredential().Password
}
if ($schedUserName -ne "blank") {
    
    ###Password is used to create a new web session variable that is used to download the files
    Invoke-WebRequest -UseBasicParsing -Uri "https://mms2022atmoa.sched.com/login" `
        -Method "POST" `
        -Headers @{
        "Accept"                    = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
        "Accept-Encoding"           = "gzip, deflate, br"
        "Accept-Language"           = "en-US,en;q=0.9"
        "Cache-Control"             = "max-age=0"
        "DNT"                       = "1"
        "Origin"                    = "https://mms2022atmoa.sched.com"
        "Referer"                   = "https://mms2022atmoa.sched.com/login"
        "Sec-Fetch-Dest"            = "document"
        "Sec-Fetch-Mode"            = "navigate"
        "Sec-Fetch-Site"            = "same-origin"
        "Sec-Fetch-User"            = "?1"
        "Upgrade-Insecure-Requests" = "1"
        "sec-ch-ua"                 = "`" Not A;Brand`";v=`"99`", `"Chromium`";v=`"100`", `"Microsoft Edge`";v=`"100`""
        "sec-ch-ua-mobile"          = "?0"
        "sec-ch-ua-platform"        = "`"Windows`""
    } `
        -ContentType "application/x-www-form-urlencoded" `
        -Body "landing_conf=https%3A%2F%2Fmms2022atmoa.sched.com&username=$schedUserName&password=$schedPassword&login=" `
        -SessionVariable newSession | Out-Null
}

$urls = @(
    'https://mms2022atmoa.sched.com/2022-05-01/list/descriptions',
    'https://mms2022atmoa.sched.com/2022-05-02/list/descriptions',
    'https://mms2022atmoa.sched.com/2022-05-03/list/descriptions',
    'https://mms2022atmoa.sched.com/2022-05-04/list/descriptions',
    'https://mms2022atmoa.sched.com/2022-05-05/list/descriptions'
)

$urls | ForEach-Object {
    $url = $_
    if ($newSession) {
        $res = Invoke-WebRequest -Uri $url -WebSession $newSession
    }
    else {
        $res = Invoke-WebRequest -Uri $url
    }

    $res.ParsedHtml.documentElement.getElementsByClassName('sched-container') | ForEach-Object {
        $result = $_
        if ($result.innerHTML -like "*sched-container-inner*" -and $result.innerHTML -like "*sched-file*") {
            $eventName = (($result.innerText).Split([Environment]::NewLine)[0]).Trim()
            [System.IO.Path]::GetInvalidFileNameChars() | ForEach-Object {
                if ($_.length -gt 0) {
                    $eventName = $eventName.Replace($_, '_')
                }
            }
            $files = ($result.getElementsByTagName('div') | Where-Object { $_.ClassName -match '\bsched-file\b' }).innerHTML
            $files | ForEach-Object {
                $file = $_
                $file = ($file.Split(" ") | Where-Object { $_ -match "href" }).replace("href=", "").replace('"', '')
                $fileName = $file.Split('/')
                $fileName = $fileName[$fileName.count - 1]
                #Fix URL encoding
                $fileName = [uri]::UnescapeDataString($fileName)
                $eventName
                $file
                $fileName
                [System.IO.Path]::GetInvalidFileNameChars() | ForEach-Object {
                    if ($_.length -gt 0) {
                        $fileName = $fileName.Replace($_, '_')
                    }
                }
                if (!(Test-Path "$folder\$eventName")) {
                    New-Item -Type Directory -Path "$folder\$eventName"
                }
                if (!(Test-Path "$folder\$eventName\$fileName")) {
                    if ($newSession) {
                        Invoke-WebRequest $file -OutFile "$folder\$eventName\$fileName" -Verbose -WebSession $newSession
                    }
                    else {
                        Invoke-WebRequest $file -OutFile "$folder\$eventName\$fileName" -Verbose
                    }
                }
            }
        }
    }
}