import SwiftUI
import Foundation
import VonageClientSDKSilentAuth

struct VerifyBody: Codable {
    let phoneNumber: String
}

struct VerifyResponse: Codable {
    let check_url: String
}

struct CheckResponse: Codable {
    let request_id: String
    let code: String
}

struct LogEvents {
    var startDate: Date?
    var getAuthURLDate: Date?
    var callURLDate: Date?
    var checkCodeDate: Date?
}


struct ContentView: View {
    @State var number = ""
    @State var verificationSuccess: Bool?
    @State var verifyLogs = LogEvents()
    @State var isLoading = false
    
    let url = "https://neru-1d66dbfe-neru-silent-auth-application-dev.euw1.runtime.vonage.cloud/silentAuthentication"
    let verifyCheckUrl = "https://neru-1d66dbfe-neru-silent-auth-application-dev.euw1.runtime.vonage.cloud/silentAuthenticationCheck"
    let client = VGSilentAuthClient()
    
    
    var body: some View {
        VStack {
            Image("vonage_V_1024")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150.0, height: 150.0, alignment: .topLeading)
            Text("Authenticate your users \n with Vonage Silent Auth").padding(20)
        }
        
        if isLoading {
            ProgressView()
        } else {
            VStack {
                Text("Please enter your number")
                TextField("Number", text: $number)
                    .frame(width: 200)
                    .textFieldStyle(.roundedBorder)
                
                Button("Verify") {
                    isLoading = true
                    Task {
                        do {
                            verifyLogs.startDate = Date()
                            let verifyResponse = try await getCheckURL()
                            
                            verifyLogs.getAuthURLDate = Date()
                            let checkResponse = try await getCheckCode(verifyResponse: verifyResponse)
                            
                            verifyLogs.callURLDate = Date()
                            verificationSuccess = await submitCheckCode(checkResponse: checkResponse)
                            
                            verifyLogs.checkCodeDate = Date()
                            isLoading = false
                        } catch {
                            print("Error")
                        }
                    }
                }
                
                if verificationSuccess != nil {
                    if verificationSuccess == true {
                        Text("Verification Successful")
                            .background(Color.green)
                    } else {
                        Text("Verification Failed")
                            .background(Color.red)
                        //Failover layout
                    }
                }
            }
        }
        
        Text("TimeStamps:").font(.system(size: 15, weight: .semibold)).padding(20)
        
        if verifyLogs.startDate != nil {
            Text("Start Time: \(returnDateMillisecString(inputDate: verifyLogs.startDate!))").font(.system(size: 10, weight: .semibold))
        }
        
        if verifyLogs.getAuthURLDate != nil {
            Text("getAuthURL Time: \(returnDateMillisecString(inputDate: verifyLogs.getAuthURLDate!))").font(.system(size: 10, weight: .semibold))
        }
        
        if verifyLogs.callURLDate != nil {
            Text("callURL Time: \(returnDateMillisecString(inputDate: verifyLogs.callURLDate!))").font(.system(size: 10, weight: .semibold))
        }
        
        if verifyLogs.checkCodeDate != nil {
            Text("callURL Time: \(returnDateMillisecString(inputDate: verifyLogs.checkCodeDate!))").font(.system(size: 10, weight: .semibold))
        }
    }
    
    
    func getCheckURL() async throws -> VerifyResponse {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let verifyBody = VerifyBody(phoneNumber: number)
        let body = try JSONEncoder().encode(verifyBody)
        let (data, _) = try await URLSession.shared.upload(for: request, from: body)
        print("debug",data)
        return try JSONDecoder().decode(VerifyResponse.self, from: data)
    }
    
    func getCheckCode(verifyResponse: VerifyResponse) async throws -> CheckResponse {
        return try await withCheckedThrowingContinuation { continuation in
            client.openWithDataCellular(url: URL(string: verifyResponse.check_url)!, debug: false) { response in
                if (response["error"]) == nil {
                    let status = response["http_status"] as! Int
                    if (status == 200) {
                        let jsonString = try! JSONSerialization.data(withJSONObject: response["response_body"]!)
                        let checkResponse = try! JSONDecoder().decode(CheckResponse.self, from: jsonString)
                        continuation.resume(returning: checkResponse)
                    }
                }
            }
        }
    }
    
    func submitCheckCode(checkResponse: CheckResponse) async -> Bool {
        var requestCheck = URLRequest(url: URL(string: verifyCheckUrl)!)
        
        requestCheck.httpMethod = "POST"
        requestCheck.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let checkBody = try! JSONEncoder().encode(checkResponse)
        let (_, response) = try! await URLSession.shared.upload(for: requestCheck, from: checkBody)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                return true
            }
        }
        
        return false
    }
    
    func returnDateMillisecString( inputDate: Date) -> String
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let dateString = formatter.string(from: inputDate)
        print("dateString")
        print(dateString)
        return dateString
    }
}
