$user = read-host "Please enter your Elasticsearch Username"
$pass = read-host "Please enter your Elasticsearch Password" -AsSecureString
$creds = New-Object System.Management.Automation.PSCredential($user, $pass)
$url = read-host "Elasticsearch URL and port: e.g https://elastic-url:port"
$oname = read-host "Please enter index name to be re-indexed"
$sname = "${oname}-swing"
function reindex-OriginalToSwing {
$ReadTrue = @'
{
    "index" : {
        "blocks.read_only" : true
    }
}
'@
$ReadFalse = @'
{
    "index" : {
        "blocks.read_only" : false
    }
}
'@
$rindex1 = @"
{
    "source": {
      "index": "$OName"
    },
    "dest": {
      "index": "$SName"
    }
  }
"@
$rindex2 = @"
{
    "source": {
      "index": "$SName"
    },
    "dest": {
      "index": "$OName"
    }
  }
"@
write-host "re-indexing $oname"
  function Set-ReadCreate{
      Param(
         [parameter(Mandatory=$true)]
        [String]
        $IndexName
    ) 
    if ($IndexName -eq $oname){
        $oindex = $oname
        $sindex = $sname
    } else {
        $oindex = $sname
        $sindex = $oname
    }
$readset=Invoke-RestMethod -Uri "${URL}/${Oindex}/_settings" -Method Put -Body $ReadTrue -ContentType "application/json" -Credential $Creds
if( $readset -notmatch "acknowledged" )
  {
    write-host "read attribute error"
    exit 0
  }
  $createswing = Invoke-RestMethod -Uri "${URL}/${Sindex}" -Method Put -Credential $Creds
  $createswing
  if( $createswing -match '"index": "${SName}"' )
    { 
      write-host "re-index started"
    }
  }
  function Start-ReIndex {
    Param(
        [parameter(Mandatory=$true)]
       [String]
       $cycle
   ) 
   if ($cycle -eq "1"){
       $rindex = $rindex1
       $index = $oname
   } else {
       $rindex = $rindex2
       $index = $sname
   }
  Invoke-RestMethod -Uri "${URL}/_reindex" -Method Post -Body $rindex -ContentType "application/json" -Credential $Creds
  write-host "reindex started"
  
  $readremove = Invoke-RestMethod -Uri "${URL}/${index}/_settings" -Method Put -Body $ReadFalse -ContentType "application/json" -Credential $Creds
  if( $readremove -notmatch "acknowledged" )
  {
    write-host "read attribute error"
    exit 0
  }
  }

  Set-ReadCreate -IndexName $oname    
  Start-ReIndex -cycle 1

  do {
  $count1= invoke-webrequest -uri "${URL}/${OName}/_count" -Credential $creds
  [int32]$c1=($count1.content -split  '{"count":' -split "," | select-string -allmatches "[0-9]{5,20}").ToString(" ")

  $count2= invoke-webrequest -uri "${URL}/${SName}/_count" -Credential $creds
  [int32]$c2=($count2.content -split  '{"count":' -split "," | select-string -allmatches "[0-9]{5,20}").ToString(" ")
  
  $perc = $c2 / $c1 * 100
  $latest= [math]::floor($perc)
  Write-Progress -activity "reindex in progress" -Status "Progress:" -PercentComplete $latest
  start-sleep 3
    if ((Invoke-WebRequest -Uri "${URL}/_tasks?detailed=true&actions=*reindex" -Credential $Creds).content.length -lt 20)
     {
      write-host "Re-index failed"
      exit 0
    }
  }until($latest -eq 100)

  write-host "Please make sure the indexes $oname and $sname are matching before you continue"
  $confirmation1 = Read-Host "Are you sure the indexes match?: y/n"
  if ($confirmation1 -eq 'y'){
  write-host "Please delete index - $oname"
  $confirmation2 = Read-Host "Safe to continue?: y/n"
   if ($confirmation2 -eq 'y') {
    Set-ReadCreate -IndexName $sname    
    Start-ReIndex -cycle 2

    do {
        $count1= invoke-webrequest -uri "${URL}/${sName}/_count" -Credential $creds
        [int32]$c1=($count1.content -split  '{"count":' -split "," | select-string -allmatches "[0-9]{5,20}").ToString(" ")
      
        $count2= invoke-webrequest -uri "${URL}/${oName}/_count" -Credential $creds
        [int32]$c2=($count2.content -split  '{"count":' -split "," | select-string -allmatches "[0-9]{5,20}").ToString(" ")
        
        $perc = $c2 / $c1 * 100
        $latest= [math]::floor($perc)
        Write-Progress -activity "reindex in progress" -Status "Progress:" -PercentComplete $latest
        start-sleep 3
          if ((Invoke-WebRequest -Uri "${URL}/_tasks?detailed=true&actions=*reindex" -Credential $Creds).content.length -lt 20)
            {
             write-host "Re-index failed"
             exit 0
          }
        }until($latest -eq 100)
        write-host "Please delete index - $sname"   
  }
  else{
    exit 0
      }
    }
    else{
        exit 0
    }
  }

reindex-OriginalToSwing