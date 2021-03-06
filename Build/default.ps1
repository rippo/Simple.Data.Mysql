include ".\wget.ps1"

Properties {
    $BuildDirectory = Split-Path $psake.build_script_file
    $BinDir = "$BuildDirectory\..\Bin\mysql40"
    $BinDir55 = "$BuildDirectory\..\Bin\mysql55"
    $CodeDir = "$BuildDirectory\..\Src"
    $ToolsDirectory = "$BuildDirectory\..\Tools"
    $MysqlDirectory = "$ToolsDirectory\Mysql"
    $Mysql40Directory = "$MysqlDirectory\4.0"
    $Mysql55Directory = "$MysqlDirectory\5.5"  
    $DbinitializationScript = "$BuildDirectory\InitializeDatabase.sql"
    $DbinitializationScript55 = "$BuildDirectory\InitializeDatabaseFeatures.sql"
    $TestRunnerExecutable = "$CodeDir\packages\NUnit.2.5.9.10348\Tools\nunit-console-x86.exe"
}

FormatTaskName (("-"*25) + "[{0}]" + ("-"*25))

function UnzipFiles($zipfile, $targetDir) {
    $shell = new-object -com shell.application
    $zipFileObject = $shell.namespace($zipfile)
    $targetDirObject = $shell.namespace($targetDir)
    $targetDirObject.CopyHere($zipFileObject.items())
}

function StartMysql40() {
    Write-Host "Starting MySql 4.0"
    $path = GetExecutablePath $Mysql40Directory "mysqld-nt.exe"
    $basedir = GetFullPathAsString $Mysql40Directory
    Start-Process -FilePath $path "--no-defaults --basedir=`"$basedir`" --standalone"
    Write-Host "MySql 4.0 started"
}

function StopMysql40() {
    Write-Host "Stopping MySql 4.0"
    start-sleep -s 3
    Stop-Process -Name "mysqld-nt"
    Write-Host "MySql 4.0 stopped"
}

function StartMysql55() {
    Write-Host "Starting MySql 5.5"
    $path = GetExecutablePath $Mysql55Directory "mysqld.exe"
    $basedir = GetFullPathAsString $Mysql55Directory
    Start-Process -FilePath $path  "--no-defaults --basedir=`"$basedir`" --standalone"    
    Write-Host "MySql 5.5 started"
}

function StopMysql55() {
    Write-Host "Stopping MySql 5.5"
    start-sleep -s 3
    Stop-Process -Name "mysqld"
    Write-Host "MySql 5.5 stopped"
}

function GetFullPathAsString($path) {
    (resolve-path $path).Path
}

function GetShellExecutablePath($serverPath) {
    $directoryPathAsString = GetFullPathAsString $serverPath
    "$directoryPathAsString\bin\mysql.exe"
}

function GetExecutablePath($serverDirecory, $executableName) {
    $directoryPathAsString = GetFullPathAsString $serverDirecory
    "$directoryPathAsString\bin\$executableName"
}

Task Default -depends Test

Task InitializeTestDatabases -depends Initialize_mysql_40_database, Stop_mysql_40, Initialize_mysql_55_database, Stop_mysql_55 

Task Initialize_mysql_40_database -depends Start_mysql_40 {
    & (GetShellExecutablePath $Mysql40Directory)   -u root -e "`"source $DbinitializationScript`""
}

Task Initialize_mysql_55_database -depends Start_mysql_55 {
    & (GetShellExecutablePath $Mysql55Directory)  -u root -e "`"source $DbinitializationScript`""
    & (GetShellExecutablePath $Mysql55Directory)  -u root -e "`"source $DbinitializationScript55`""
}

Task Start_mysql_40 -depends Make_sure_Mysql40_is_available {
    StartMysql40
}

Task Stop_mysql_40 {
    StopMysql40
}

Task Start_mysql_55 -depends Make_sure_Mysql55_is_available {
    StartMysql55
}

Task Stop_mysql_55 {
    StopMysql55    
}

Task Make_sure_Mysql40_is_available -depends Make_sure_Mysql_directory_is_created {
    if(!(Test-Path $Mysql40Directory)) {
        if (!(Test-Path "$BuildDirectory\MySql4.0.zip")) {
            Get-WebFile "https://github.com/downloads/Vidarls/Simple.Data.Mysql/MySql4.0.zip"
        }
        
        $targetDir = Resolve-Path $MysqlDirectory
        UnzipFiles (Dir "$BuildDirectory\MySql4.0.zip").FullName $targetDir.Path
    }  
}

Task Make_sure_Mysql55_is_available -depends Make_sure_Mysql_directory_is_created {
    if(!(Test-Path $Mysql55Directory)) {
        if (!(Test-Path "$BuildDirectory\MySql5.5.zip")) {
            Get-WebFile "https://github.com/downloads/Vidarls/Simple.Data.Mysql/MySql5.5.zip"
        }
        
        $targetDir = Resolve-Path $MysqlDirectory
        UnzipFiles (Dir "$BuildDirectory\MySql5.5.zip").FullName $targetDir.Path
    }  
}

Task Make_sure_tools_directory_is_created {
    if (!(Test-Path $ToolsDirectory)) {
        mkdir $ToolsDirectory
    }
}

Task Make_sure_Mysql_directory_is_created -Depends Make_sure_tools_directory_is_created{
    if (!(Test-Path $MysqlDirectory)) {
        mkdir $MysqlDirectory
    }
}

Task Test -Depends Build, InitializeTestDatabases, Test_on_Mysql40, Stop_mysql_40, Test_on_Mysql55, Stop_mysql_55 

Task Test_on_Mysql40 {
    StartMysql40
    Exec { & $TestRunnerExecutable "`"$BinDir\Simple.Data.Mysql.Test.dll`"" /framework=4.0 } 
    StopMySql40
}

Task Test_on_Mysql55 {
    StartMySql55
    Exec { & $TestRunnerExecutable "`"$BinDir55\Simple.Data.Mysql5.Test.Features.dll`"" /framework=4.0} 
    Exec { & $TestRunnerExecutable "`"$BinDir55\Simple.Data.Mysql.Test.dll`"" /framework=4.0} 
    StopMySql55
}

Task Build -Depends Clean {
    Exec { msbuild "$CodeDir\Simple.Data.MySql.sln" /t:Build /p:Configuration=Release /p:Platform=x86 /v:quiet /p:OutDir=$BinDir/}
    Exec { msbuild "$CodeDir\Simple.Data.MySql.sln" /t:Build /p:Configuration=MySql55Tests /p:Platform=x86 /v:quiet /p:OutDir=$BinDir55/}
}

Task Clean {
    If (Test-Path $BinDir) {
        rd $BinDir -rec -force | out-null
    }
    mkdir $BinDir
    Exec { msbuild "$CodeDir\Simple.Data.MySql.sln" /t:Clean /p:Configuration=Release /p:Platform=x86 /v:quiet /p:OutDir=$BinDir/}     
}


