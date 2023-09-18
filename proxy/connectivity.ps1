# https://hub.docker.com/r/mitmproxy/mitmproxy

docker run --rm -it -v /temp/.mitmproxy:/home/mitmproxy/.mitmproxy -p 8080:8080 -p 8081:8081 mitmproxy/mitmproxy:10.0.0 mitmweb --web-host 0.0.0.0

Start-Process http://127.0.0.1:8081

# In PowerShell:
$url = "https://echo.jannemattila.com/api/echo"
$data = @{
    firstName = "John"
    lastName  = "Doe"
}
$body = ConvertTo-Json $data
Invoke-RestMethod -Body $body -ContentType "application/json" -Method "POST" -DisableKeepAlive -Uri $url -Proxy "http://localhost:8080" -SkipCertificateCheck

# Inside WSL:
http_proxy=http://localhost:8080/ curl http://echo.jannemattila.com/pages/echo
https_proxy=http://localhost:8080/ curl -k https://echo.jannemattila.com/pages/echo

# https://mitmproxy.org/downloads/#10.0.0/
mitmdump -r proxy.log --flow-detail 3 > proxy.txt
tail -f proxy.log | mitmproxy --rfile - -n