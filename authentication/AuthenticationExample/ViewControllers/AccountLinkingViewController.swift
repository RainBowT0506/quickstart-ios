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
import FirebaseCore
import FirebaseAuth

// For Account Linking with Sign in with Google.
import GoogleSignIn

// For Account Linking with Sign in with Facebook.
import FBSDKLoginKit

// For Account Linking with Sign in with Apple.
import AuthenticationServices
import CryptoKit

class AccountLinkingViewController: UIViewController, DataSourceProviderDelegate {
  var dataSourceProvider: DataSourceProvider<AuthProvider>!

  var tableView: UITableView { view as! UITableView }

  override func loadView() {
    view = UITableView(frame: .zero, style: .insetGrouped)
  }

  let user: User

  /// Designated initializer requires a valid, non-nil Firebase user.
  /// - Parameter user: An instance of a Firebase `User`.
  init(for user: User) {
    self.user = user
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureNavigationBar()
    configureDataSourceProvider()
   }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    navigationController?.setTitleColor(.systemOrange)
  }

  // MARK: - DataSourceProviderDelegate

  func didSelectRowAt(_ indexPath: IndexPath, on tableView: UITableView) {
    let item = dataSourceProvider.item(at: indexPath)

    let providerName = item.title!

    guard let provider = AuthProvider(rawValue: providerName) else {
      // The row tapped has no affiliated action.
      return
    }

    // If the item's affiliated provider is currently linked with the user,
    // unlink the provider from the user's account.
    if item.isChecked {
      unlinkFromProvider(provider.id)
      return
    }

    switch provider {
 
    case .twitter :
      performOAuthAccountLink(for: provider)
 
    default:
      break
    }
  }

  // MARK: Firebase 🔥

  /// Wrapper method that uses Firebase's `link(with:)` API to link a user to another auth provider.
  /// Used when linking a user to each of the following auth providers.
  /// This method will update the UI upon the linking's completion.
  /// - Parameter authCredential: The credential used to link the user with the auth provider.
  private func linkAccount(authCredential: AuthCredential) {
    user.link(with: authCredential) { result, error in
      guard error == nil else { return self.displayError(error) }
      self.updateUI()
    }
  }

  /// Wrapper method that uses Firebase's `unlink(fromProvider:)` API to unlink a user from an auth provider.
  /// This method will update the UI upon the unlinking's completion.
  /// - Parameter providerID: The string id of the auth provider.
  private func unlinkFromProvider(_ providerID: String) {
    user.unlink(fromProvider: providerID) { user, error in
      guard error == nil else { return self.displayError(error) }
      print("Unlinked user from auth provider: \(providerID)")
      self.updateUI()
    }
  }

 
 

  // MARK: - Twitter, Microsoft, GitHub, Yahoo Account Linking 🔥

  // Maintain a strong reference to an OAuthProvider for login
  private var oauthProvider: OAuthProvider!

  private func performOAuthAccountLink(for provider: AuthProvider) {
    oauthProvider = OAuthProvider(providerID: provider.id)
    oauthProvider.getCredentialWith(nil) { [weak self] credential, error in
      guard let strongSelf = self else { return }
      guard error == nil else { return strongSelf.displayError(error) }
      guard let credential = credential else { return }
      strongSelf.linkAccount(authCredential: credential)
    }
  }
 

  // MARK: - UI Configuration

  private func configureNavigationBar() {
    navigationItem.title = "Account Linking"
    navigationItem.backBarButtonItem?.tintColor = .systemYellow
    navigationController?.navigationBar.prefersLargeTitles = true
  }

 
  // MARK: - TableView Configuration & Refresh

  private func configureDataSourceProvider() {
    dataSourceProvider = DataSourceProvider(
      dataSource: sections,
      tableView: tableView
    )
    dataSourceProvider.delegate = self
  }

  private func updateUI() {
    configureDataSourceProvider()
    animateUpdates(for: tableView)
  }

  private func animateUpdates(for tableView: UITableView) {
    UIView.transition(with: tableView, duration: 0.05,
                      options: .transitionCrossDissolve,
                      animations: { tableView.reloadData() })
  }
}

// MARK: DataSourceProvidable

extension AccountLinkingViewController: DataSourceProvidable {
  var sections: [Section] { buildSections() }

  private func buildSections() -> [Section] {
    var section = AuthProvider.authLinkSections.first!
    section.items = section.items.compactMap { item -> Item? in
      var item = item
      item.hasNestedContent = false
      item.isChecked = userProviderDataContains(item: item)
      return ["Anonymous Authentication", "Custom Auth System"].contains(item.title) ? nil : item
    }
    return [section]
  }

  private func userProviderDataContains(item: Item) -> Bool {
    guard let authProvider = AuthProvider(rawValue: item.title ?? "") else { return false }
    return user.providerData.map { $0.providerID }.contains(authProvider.id)
  }
}
 
