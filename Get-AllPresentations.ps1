# scrape website for all links containing files
# and download them to the current directory
Read-Host "This will download all presentations to the current directory... (press any key to continue)"

$urls = @(
    'https://mms2022atmoa.sched.com/2022-05-01/list/descriptions',
    'https://mms2022atmoa.sched.com/2022-05-02/list/descriptions',
    'https://mms2022atmoa.sched.com/2022-05-03/list/descriptions',
    'https://mms2022atmoa.sched.com/2022-05-04/list/descriptions',
    'https://mms2022atmoa.sched.com/2022-05-05/list/descriptions'
)

$urls | ForEach-Object {
    $url = $_
    $res = Invoke-WebRequest -Uri $url

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
                if (!(Test-Path $eventName)) {
                    New-Item -Type Directory -Path $eventName
                }
                Invoke-WebRequest $file -OutFile "$eventName\$fileName" -Verbose
            }
        }
    }
}