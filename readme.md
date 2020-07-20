## 정리

### 1. Azure API 의 long running job
VM 생성, 디스크 스냅샷 생성 등 실행이 오래 걸리는 작업은 HTTP Status [202 Created]로 return된다.   
따라서 API의 20x로 들어온 Response의 Header.'Azure-AsyncOperation'[0]을 항상 체크하여 작업 상태를 모니터링 해야한다.   
![Alt text](https://github.com/chupark/AzureAPI-DiskBackup/raw/master/img/1.%20azure%20api/1.SnapshotSAS_202%20created.png)    
Azure-AsyncOperation의 데이터는 작업의 상태를 조회할 수 있는 URL이 들어있으므로 해당 URL에 Request를 보내 HTTP Status [200 OK]가 return되는지 확인한다.   
Disk Snapshot의 SAS URL생성 요청의 경우 최초 응답이 [202 Created]로 return 되고, SAS URL이 응답에 포함되지 않아 당황할 수 있는데 이때는 Azure-AsyncOperation의 URL에 다시 요청을 하면, SAS URL을 받을 수 있다.   
 Status Code가 200이 될 때 까지 반복적으로 요청해야 한다.   
![Alt text](https://raw.githubusercontent.com/chupark/AzureAPI-DiskBackup/master/img/1.%20azure%20api/2.SnapshotSAS_200%20ok.png)    
<br>

### 2. Azure Storage의 서명 문자열
Azure Storage Account의 API인증은 Azure AD가 아닌 Storage Account의 공유 Key를 사용하여 서명 문자열을 암호화 하여 토큰으로 사용한다.
요청 헤더를 UTF-8로 인코딩 하고 -> Storage Account의 Shared Key를 사용하여 HMAC-SHA256으로 암호화 한 뒤 -> Base64로 다시 인코딩 하면 된다.
이 과정에서 CanonicalizedHeaders와 CanonicalizedResource라는게 나타난다. -_-...  
CanonicalizedHeaders 는 x-ms로 시작하는 헤더들을 나타내며 헤더를 추가할 때 마다 개행문자를 삽입해야 한다.  
CanonicalizedResource 는 호출할 URL이다. 기본 폼은 /myStorageAccount/myStorageService/로 시작하며 그 뒤는 컨테이너, Blob 등 호출할 대상마다 다르다.
myStorageAccount는 말 그대로 저장소 계정, myStorageService는 Blob 서비스의 컨테이너 혹은 개별 Blob, Table 저장소의 Table이름 등이 된다.  
아래 링크를 참조하면 어떻게 작성하는지 알 수 있다.  
참고 링크 : https://docs.microsoft.com/ko-kr/rest/api/storageservices/authorize-with-shared-key#shared-key-format-for-2009-09-19-and-later

### 3. Azure Storage Table과 OData Protocol
Azure Storage Table의 테이블 데이터 조회는 OData Protocol을 따른다.  
참고 링크 : https://www.odata.org/odata-services/

### 4. Azure Storage Blob과 Header
Azure Managed Snapshot SAS URI원본을 (Page Blob) Azure Blob으로 복사하는 방법이 필요하여 Azure REST API공식 문서를 참조하여 시도해봤지만 인증 오류가 발생하며 복사가 안되는 어이없는 상황이 발생했다.  
공식 문서 : https://docs.microsoft.com/ko-kr/rest/api/storageservices/put-page-from-url  
공식 문서에서 Required라고 나와있는 일부 Header은 실제로 넣었을 경우 인증 오류가 발생하여 하루종일 삽질하여 겨우 성공했다.  
내가 사용한 헤더는 아래와 같으며 SharedKeyLite 인증 토큰을 사용했다.  
````
$header = @{
    "x-ms-copy-source"=<my-Access-SAS-URI>
    "x-ms-date"=$date
    "x-ms-version"="2018-11-09"
    "Authorization"="SharedKeyLite pcwstoragetable:" + $signedSignature
}
````

### 5. Blob의 복제 상테 모니터링
Blob 복제도 시간이 오래 걸리는 Long running job이다. 하지만 Snapshot과 조금 다르다. 스냅샷은 Header에 상태 정보를 확인할 수 있는 URL을 줬지만 Copy ID를 헤더로 던져준다.
따라서 Blob의 상태를 모니터링 하려면 대상 Blob에 HTTP HEAD Request를 해야한다.   
사진을 살펴보면 x-ms-copy-id가 서로 일치함을 확인할 수 있으며 Blob Copy상태와 progress를 확인할 수 있다.   
![Alt text](https://raw.githubusercontent.com/chupark/AzureAPI-DiskBackup/master/img/2.%20blob%20status/1.%20copy%20start.png)    
<br><br>

x-ms-copy-status가 success가 될 때 까지 주기적으로 모니터링을 해야 할 필요가 있으며 Copy가 끝나면 다음과 같은 결과를 얻을 수 있다.
![Alt text](https://github.com/chupark/AzureAPI-DiskBackup/blob/master/img/2.%20blob%20status/2.%20copy%20end.png)    