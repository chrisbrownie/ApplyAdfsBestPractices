# This script generates the "updates.json" file required by the .\ApplyAdfsBestPractices.ps1 script
$UpdatesUri = "https://technet.microsoft.com/en-us/windows-server-docs/identity/ad-fs/operations/updates-for-active-directory-federation-services--ad-fs-"
$UpdateTableNumber = 2
$RequiredUpdatesFileName = "updates.json"

# http://www.leeholmes.com/blog/2015/01/05/extracting-tables-from-powershells-invoke-webrequest/
function Get-WebRequestTable {
param(
    [Parameter(Mandatory = $true)]
    [Microsoft.PowerShell.Commands.HtmlWebResponseObject] $WebRequest,

    [Parameter(Mandatory = $true)]
    [int] $TableNumber
    )

    ## Extract the tables out of the web request
    $tables = @($WebRequest.ParsedHtml.getElementsByTagName("TABLE"))
    $table = $tables[$TableNumber]
    $titles = @()
    $rows = @($table.Rows)

    ## Go through all of the rows in the table
    foreach($row in $rows) {

        $cells = @($row.Cells)

        ## If we’ve found a table header, remember its titles
        if($cells[0].tagName -eq "TH") {
            $titles = @($cells | % { ("" + $_.InnerText).Trim() })
            continue
        }

        ## If we haven’t found any table headers, make up names "P1", "P2", etc.
        if(-not $titles) {
            $titles = @(1..($cells.Count + 2) | % { "P$_" })
        }

        ## Now go through the cells in the the row. For each, try to find the
        ## title that represents that column and create a hashtable mapping those
        ## titles to content
        $resultObject = [Ordered] @{}

        for($counter = 0; $counter -lt $cells.Count; $counter++) {

            $title = $titles[$counter]
            if(-not $title) { continue }
            $resultObject[$title] = ("" + $cells[$counter].InnerText).Trim()

        }

        ## And finally cast that hashtable to a PSCustomObject
        [PSCustomObject] $resultObject
    }
}

$UpdatesUri = "https://technet.microsoft.com/en-us/windows-server-docs/identity/ad-fs/operations/updates-for-active-directory-federation-services--ad-fs-"

$page = Invoke-WebRequest $UpdatesUri

# We want the table after this line:
# <h2 id="updates-for-ad-fs-and-wap-in-windows-server-2016">

$updates = Get-WebRequestTable $page -TableNumber 2

$results = New-Object -TypeName PSObject -Property @{
    "TimeStamp" = Get-Date
    "Updates" = $updates
}

$results | ConvertTo-Json | Out-File $RequiredUpdatesFileName