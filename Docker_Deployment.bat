@ECHO off
Title "Docker Deployment"
cd D:\QA\ZIEWEB_Container_v1.0\Build\
set /p Build=Enter the Build Number : 
Set date=%DATE:~6,4%%DATE:~3,2%%DATE:~0,2%
set time=%TIME:~6,2%%TIME:~3,2%%TIME:~0,2%
set dateandtime=%date%_%time: =0%
mkdir %Build%_%dateandtime%
ECHO "%Build%_%dateandtime% File created"
CALL D:\QA\ZIEWEB_Container_v1.0\Build\Script\Config_Data.bat
CD %LocalLocation%
ECHO "Copy the Build from Build machine to local"
COPY %BuildLocation% %LocalLocation%

for %%i in (*.tar) do (
ECHO %%i
docker load --input %%i >> dockerimages.txt
)
docker images --format "{{.Repository}}:{{.Tag}}" >>Images.txt

docker network create %Build%_%dateandtime%
docker network ls >>network.txt

setlocal 
FOR /F %%G IN (Images.txt) DO (
set A=%%G
ECHO !A! | findstr "hcl_lm_img" > nul 2>&1
if not errorlevel 1 (
    docker run -d -it --network=%Build%_%dateandtime% -e securedConnection=%securedConnection% -p %LM_port_http% -p %LM_port_https% -v "%LM_Mount%" --name %LMNAME% !A!
	ECHO License Manager container created sucessfully
	)
ECHO !A! | findstr "hcl_rdr_img" > nul 2>&1
if not errorlevel 1 (
    docker run -d -it --network=%Build%_%dateandtime% -e ACCEPT_LICENSE=%ACCEPT_LICENSE% -p "%Redirector_Port%" -v "%Redirector_Cert%" --name %Redirector% !A!
	ECHO Redirector container created sucessfully
	)
ECHO !A! | findstr "hclziewebclient_ftp_img" > nul 2>&1
if not errorlevel 1 (
    docker run -d -it --network=%Build%_%dateandtime% -e ENVIRONMENT=%ENVIRONMENT% -p %FTP_Port% -v "%FTP_Mount%" -v "%VTFTP_Cert_Mount%" --name %FTPCONTAINERNAME% !A!
	ECHO zieftpserver container created sucessfully
	)
ECHO !A! | findstr "hclziewebclient_vt_img" > nul 2>&1
if not errorlevel 1 (
    docker run -d -it --network=%Build%_%dateandtime% -e ENVIRONMENT=%ENVIRONMENT% -p %VT_Port% -v "%VT_Mount%" -v "%VTFTP_Cert_Mount%" --name %VTCONTAINERNAME% !A!
	ECHO zievtserver container created sucessfully
	)
ECHO !A! | findstr "zie-webclient" > nul 2>&1
if not errorlevel 1 (
    docker run -d -it --network=%Build%_%dateandtime% -e ZIEWebServer=%ZIEWebServer% -e LMName=%LMNAME% -e securedConnection=%securedConnection% -e DEPENV=%DEPENV% -e FTPCONTAINERNAME=%FTPCONTAINERNAME% -e VTCONTAINERNAME=%VTCONTAINERNAME% -e HOSTFORDOCKER=%HOSTFORDOCKER% -e SOCKERPATH=%SOCKERPATH% -p %APP_Http_Port% -p %APP_Https_Port% -v %Client_Mount% --name %ziewebclient% !A!
	ECHO zieweb client container created sucessfully
	)
ECHO !A! | findstr "zie-webserver" > nul 2>&1
if not errorlevel 1 (
    docker run -d -it --network=%Build%_%dateandtime% -e ACCEPT_LICENSE=%ACCEPT_LICENSE% -e ZIEWebServer=%ZIEWebServer% -p %ZIEWEB_Http_Port% -p %ZIEWEB_Https_Port% -p %ZIEWEB_config_Port% -v "%Bin_Cert%" -v "%ZIEWEB_Cert%" -v "%Private_Mount%" -v "%DW_Mount%" -v "%Migration_Mount%" --name %ZIEWebServer% !A!
	ECHO zieweb server container created sucessfully
	)
	)
docker ps

docker images >> dockerimages.txt
docker ps -a >> dockerimages.txt

ECHO Please wait for 30 secs to generate logs and url launch
timeout /t 30 /nobreak

DEL Images.txt
mkdir logs
CD %logsLocation%
docker logs %FTPCONTAINERNAME% >> %FTPCONTAINERNAME%_logs.txt
docker logs %VTCONTAINERNAME% >> %VTCONTAINERNAME%_logs.txt
docker logs %ziewebclient% >> %ziewebclient%_logs.txt
docker logs %ZIEWebServer% >> %ZIEWebServer%_logs.txt
docker logs %LMNAME% >> %LMNAME%_logs.txt
docker logs %Redirector% >> %Redirector%_logs.txt

start http://localhost:9080/zieweb/adminconsole
start http://localhost:8080/zie/
start http://localhost:9088/LicenseManager/LicenseLogger

ECHO Terminal will exit in 10 Secs
timeout /t 10 /nobreak
EXIT
