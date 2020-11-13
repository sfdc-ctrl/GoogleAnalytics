/*
	Generic Controller to Integrate with Google Analytics
	Setp 1 - Get Authorization Code
	Step 2 - Get Access Token Refresh Token 
	Step 3 - Use Access Token To Fetch Result (Analytics Data)
*/
Public class GenericConnectorController {
    
    public list<Google_Credentials__mdt>  googleCred {get;set;}
    public string AuthScope {get;set;}
    public string code  {get;set;}
    public string pageName {get;set;}
    public string Result {get;set;}
    public string gaorganicSearches {get;set;}
    public string gapageviews{get;set;}
    
    public GenericConnectorController(){
        Result = '' ;
        authScope = 'https://www.googleapis.com/auth/analytics https://www.googleapis.com/auth/analytics.readonly' ;
        code = apexPages.CurrentPage().getParameters().get('code');
        pageName = 'analytics';
        if(googleCred == null){
            
            googleCred =[SELECT OAuth_EndPoint__c, Access_Type__c, prompt__c, Client_Key__c , Redirect_URI__c , Client_Secret__c , grant_type__c ,Token_Endpoint__c from  Google_Credentials__mdt];
            
        }
        system.debug('CODE>>>>>>>'+code);
    }
    
    public pageReference doGetAuthorizationCode(){
        system.debug('doGetAuthorizationCode>>>>>>>');
        string requestBody = '';
        if(googleCred != null && googleCred.size()>0){
            
            requestBody = googleCred[0].OAuth_EndPoint__c+'?scope='+authScope+'&';
            requestBody += 'client_id='+googleCred[0].Client_Key__c+'&redirect_uri='+googleCred[0].Redirect_URI__c;
            requestBody += '&access_type='+googleCred[0].Access_Type__c+'&state=875858522';
            requestBody += '&include_granted_scopes=true';
            requestBody += '&prompt='+googleCred[0].prompt__c+'&response_type=code';            
        }
        PageReference pageRef = new PageReference(requestBody);
        pageRef.setRedirect(true);
        return pageRef ;
    }
    
    public pageReference doGetAccessToken(){
        system.debug('doGetAccessToken>>>>>>>>');
        HttpRequest httpReq = new HttpRequest();
        HttpResponse httpRes = new HttpResponse();
        
        String errorMessage = '';
        
        if((googleCred != null && googleCred.size()>0 && code != null)||test.isrunningTest()){
            
            httpReq.setMethod('POST');
            httpReq.setEndpoint(googleCred[0].Token_Endpoint__c);
            httpReq.setHeader('Host' , 'www.googleapis.com');
            httpReq.setHeader('Content-Type' , 'application/x-www-form-urlencoded');
            httpReq.setTimeout(12000);
            
            string requestBody = 'code='+code+'&client_id='+googleCred[0].Client_Key__c+'&redirect_uri='+googleCred[0].Redirect_URI__c;
            requestBody += '&client_secret='+googleCred[0].Client_Secret__c+'&grant_type='+googleCred[0].grant_type__c;
            
            httpReq.setBody(requestBody);
            
            httpRes = (new http()).send(httpReq);
            
            if(httpRes.getStatusCode() == 200){
                
                string response = httpRes.getBody();
                Map<String,object> responseMap = (Map<String,object>)JSON.deserializeUntyped(response);
                list<Google_Token__c> tokenList = new list<Google_Token__c>();
                tokenList =[SELECT ID, Name, Access_Token__c, Refresh_Token__c, Expires_In_Seconds__c, Expires_In__c from Google_Token__c where name = 'Google Product'];
                
                if(tokenList!= null && tokenList.size() > 0)
                {
                    //Updating and Creating Refresh Token
                    tokenList[0].Access_Token__c = (String)responseMap.get('access_token');
                    tokenList[0].Refresh_Token__c = (String)responseMap.get('refresh_token');
                    tokenList[0].Expires_In_Seconds__c = (Integer)responseMap.get('expires_in');
                    DateTime dtTime = system.now().addSeconds(Integer.valueOf(tokenList[0].Expires_In_Seconds__c));
                    tokenList[0].Expires_In__c = dtTime;
                }
                else{
                    //Creating New Access Token
                    Google_Token__c token = new Google_Token__c();
                    token.Name = 'Google Product';
                    token.Access_Token__c = (String)responseMap.get('access_token');
                    token.Refresh_Token__c = (String)responseMap.get('refresh_token');
                    token.Expires_In_Seconds__c = (Integer)responseMap.get('expires_in');
                    DateTime dtTime = system.now().addSeconds(Integer.valueOf(token.Expires_In_Seconds__c));
                    token.Expires_In__c = dtTime;
                    tokenList.add(token);
                    
                }
                //Updating Access Token or Refresh Token 
                if(tokenList <> null && tokenList.size()>0){
                    system.debug('tokenList>>>>>'+tokenList);
                    upsert tokenList;
                }
                
            }
            else{
                errorMessage = string.valueof(httpRes.getStatusCode());
                system.debug('errorMessage>>>>'+errorMessage);
            }
        }
        
        return null ;
    }
    
    public void doListAnalyticsData(){
        list<Google_Token__c> googleSettingInfoList = [SELECT id , Access_Token__c From Google_Token__c] ;
        String accessToken = googleSettingInfoList[0].Access_Token__c;
        //String endPoint = 'https://www.googleapis.com/analytics/v3/management/accounts/';
        String endPoint = 'https://www.googleapis.com/analytics/v3/data/ga?ids=ga%3A61259411&start-date=30daysAgo&end-date=yesterday&metrics=ga%3AorganicSearches%2Cga%3Apageviews';
        

        Http http = new Http();
        HttpRequest httpReq = new HttpRequest();
        HttpResponse HttpRes = new HttpResponse();
        
        httpReq.setEndpoint(endpoint);
        httpReq.setMethod('GET');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setHeader('Authorization','Bearer '+accessToken);

        HttpRes = http.send(httpReq);
        if(httpRes.getStatusCode() == 200){
        
            Result = string.ValueOf(HttpRes.getBody());
            parsingResult(HttpRes);
            System.debug('#### HtteRes '+HttpRes.getBody());
            
        }else{
           system.debug('ERROR>>>>>>>>>>>>>'+HttpRes.getstatus());
           System.debug('#### HtteRes '+HttpRes.getbody());
        }
        
    }
    
    Public void parsingResult(HttpResponse jsonStringResponse){
        
        JSON2Apex wrapperObj = new JSON2Apex (System.JSON.createParser(jsonStringResponse.getBody()));
        system.debug('gaorganicSearches>>>>>'+wrapperObj.TotalsForAllResults.gaorganicSearches);
        system.debug('gapageviews>>>>>'+wrapperObj.TotalsForAllResults.gapageviews);
        
        gapageviews = wrapperObj.TotalsForAllResults.gapageviews ;
        
        gaorganicSearches = wrapperObj.TotalsForAllResults.gaorganicSearches ;
        
    }
}
