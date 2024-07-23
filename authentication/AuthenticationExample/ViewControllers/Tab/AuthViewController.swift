// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
// [START auth_import]
import FirebaseCore
import FirebaseAuth
// [END auth_import]

// For Sign in with Google
// [START google_import]
import GoogleSignIn
// [END google_import]

// For Sign in with Facebook
import FBSDKLoginKit

// For Sign in with Apple
import AuthenticationServices
import CryptoKit

private let kFacebookAppID = "ENTER APP ID HERE"

class AuthViewController: UIViewController, DataSourceProviderDelegate {
    var dataSourceProvider: DataSourceProvider<AuthProvider>!
    
    override func loadView() {
        view = UITableView(frame: .zero, style: .insetGrouped)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
         configureDataSourceProvider()
    }
    
    // MARK: - DataSourceProviderDelegate
    
    func didSelectRowAt(_ indexPath: IndexPath, on tableView: UITableView) {
        let item = dataSourceProvider.item(at: indexPath)
        
        let providerName = item.isEditable ? item.detailTitle! : item.title!
        
        guard let provider = AuthProvider(rawValue: providerName) else {
            // The row tapped has no affiliated action.
            return
        }
        
        switch provider {
        case .apple:
            performAppleSignInFlow()
        case .google:
            performGoogleSignInFlow()
        case .twitter :
            performOAuthLoginFlow(for: provider)
        }
    }
    
    // MARK: - Firebase 🔥
    
    private func performGoogleSignInFlow() {
        // [START headless_google_auth]
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        // Create Google Sign In configuration object.
        // [START_EXCLUDE silent]
        // TODO: Move configuration to Info.plist
        // [END_EXCLUDE]
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [unowned self] result, error in
            guard error == nil else {
                // [START_EXCLUDE]
                return displayError(error)
                // [END_EXCLUDE]
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString
            else {
                // [START_EXCLUDE]
                let error = NSError(
                    domain: "GIDSignInError",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Unexpected sign in result: required authentication data is missing.",
                    ]
                )
                return displayError(error)
                // [END_EXCLUDE]
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)
            
            // [START_EXCLUDE]
            signIn(with: credential)
            // [END_EXCLUDE]
        }
        // [END headless_google_auth]
    }
    
    func signIn(with credential: AuthCredential) {
        // [START signin_google_credential]
        Auth.auth().signIn(with: credential) { result, error in
            // [START_EXCLUDE silent]
            guard error == nil else { return self.displayError(error) }
            // [END_EXCLUDE]
            
            // At this point, our user is signed in
            // [START_EXCLUDE silent]
            // so we advance to the User View Controller
            self.transitionToUserViewController()
            // [END_EXCLUDE]
        }
        // [END signin_google_credential]
    }
    
    // For Sign in with Apple
    var currentNonce: String?
    
    private func performAppleSignInFlow() {
        do {
            let nonce = try CryptoUtils.randomNonceString()
            currentNonce = nonce
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = CryptoUtils.sha256(nonce)
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        } catch {
            // In the unlikely case that nonce generation fails, show error view.
            displayError(error)
        }
    }
    
    // Maintain a strong reference to an OAuthProvider for login
    private var oauthProvider: OAuthProvider!
    
    private func performOAuthLoginFlow(for provider: AuthProvider) {
        oauthProvider = OAuthProvider(providerID: provider.id)
        oauthProvider.getCredentialWith(nil) { credential, error in
            guard error == nil else { return self.displayError(error) }
            guard let credential = credential else { return }
            self.signin(with: credential)
        }
    }
    
    private func signin(with credential: AuthCredential) {
        Auth.auth().signIn(with: credential) { result, error in
            guard error == nil else { return self.displayError(error) }
            self.transitionToUserViewController()
        }
    }
    
    // MARK: - Private Helpers
    
    private func configureDataSourceProvider() {
        let tableView = view as! UITableView
        dataSourceProvider = DataSourceProvider(dataSource: AuthProvider.sections, tableView: tableView)
        dataSourceProvider.delegate = self
    }
    
    private func transitionToUserViewController() {
        // UserViewController is at index 1 in the tabBarController.viewControllers array
        tabBarController?.transitionToViewController(atIndex: 1)
    }
}

// MARK: - LoginDelegate

extension AuthViewController: LoginDelegate {
    public func loginDidOccur() {
        transitionToUserViewController()
    }
}

// MARK: - Implementing Sign in with Apple with Firebase

extension AuthViewController: ASAuthorizationControllerDelegate,
                              ASAuthorizationControllerPresentationContextProviding {
    // MARK: ASAuthorizationControllerDelegate
    
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential
        else {
            print("Unable to retrieve AppleIDCredential")
            return
        }
        
        guard let nonce = currentNonce else {
            fatalError("Invalid state: A login callback was received, but no login request was sent.")
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            print("Unable to fetch identity token")
            return
        }
        guard let appleAuthCode = appleIDCredential.authorizationCode else {
            print("Unable to fetch authorization code")
            return
        }
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
            return
        }
        
        guard let _ = String(data: appleAuthCode, encoding: .utf8) else {
            print("Unable to serialize auth code string from data: \(appleAuthCode.debugDescription)")
            return
        }
        
        // use this call to create the authentication credential and set the user's full name
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                       rawNonce: nonce,
                                                       fullName: appleIDCredential.fullName)
        
        Auth.auth().signIn(with: credential) { result, error in
            // Error. If error.code == .MissingOrInvalidNonce, make sure
            // you're sending the SHA256-hashed nonce as a hex string with
            // your request to Apple.
            guard error == nil else { return self.displayError(error) }
            
            // At this point, our user is signed in
            // so we advance to the User View Controller
            self.transitionToUserViewController()
        }
    }
    
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        // Ensure that you have:
        //  - enabled `Sign in with Apple` on the Firebase console
        //  - added the `Sign in with Apple` capability for this project
        print("Sign in with Apple failed: \(error)")
    }
    
    // MARK: ASAuthorizationControllerPresentationContextProviding
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}
