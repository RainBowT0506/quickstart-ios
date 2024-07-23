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
        case .twitter :
            performOAuthLoginFlow(for: provider)
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
    
    private func configureNavigationBar() {
        navigationItem.title = "Firebase Auth"
        guard let navigationBar = navigationController?.navigationBar else { return }
        navigationBar.prefersLargeTitles = true
        navigationBar.titleTextAttributes = [.foregroundColor: UIColor.systemOrange]
        navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.systemOrange]
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

 
