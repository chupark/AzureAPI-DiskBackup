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

### 2. Azure Storage Table과 OData Protocol
Azure Storage Table의 테이블 데이터 조회는 OData Protocol을 따른다.  
참고 링크 : https://www.odata.org/odata-services/