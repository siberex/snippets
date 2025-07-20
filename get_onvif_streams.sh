# https://superuser.com/a/1711576/1129367
# sudo apt install -y curl libxml2-utils

FRIGATE_RTSP_PASSWORD="admin"

curl -u "admin:${FRIGATE_RTSP_PASSWORD}" --anyauth -X POST "http://10.0.0.2:8000/onvif/device_service" \
 -H 'Content-Type: application/soap+xml; charset=utf-8'\
 -H 'SOAPAction: "http://www.onvif.org/ver10/media/wsdl/GetProfiles"'\
 -d '
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:wsdl="http://www.onvif.org/ver10/media/wsdl">
  <soap:Header/>
  <soap:Body>
    <wsdl:GetProfiles/>
   </soap:Body>
</soap:Envelope>
' | xmllint --format -

curl -u "admin:${FRIGATE_RTSP_PASSWORD}" --anyauth -X POST "http://10.0.0.2:8000/onvif/device_service" \
 -H 'Content-Type: application/soap+xml; charset=utf-8'\
 -H 'SOAPAction: "http://www.onvif.org/ver10/media/wsdl/GetStreamUri"'\
 -d '
<soap:Envelope
  xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
  xmlns:wsdl="http://www.onvif.org/ver10/media/wsdl"
>
  <soap:Header/>
  <soap:Body>
    <wsdl:GetStreamUri>
      <wsdl:ProfileToken>001</wsdl:ProfileToken>
    </wsdl:GetStreamUri>
  </soap:Body>
</soap:Envelope>
' | xmllint --format -