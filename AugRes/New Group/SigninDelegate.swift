//
//  SigninDelegate.swift
//  internhacksauthappid
//
//  Created by Yotam Madem on 11/02/2018.
//  Copyright © 2018 Oded Betzalel. All rights reserved.
//

import UIKit
import BluemixAppID
import BMSCore


class SigninDelegate: AuthorizationDelegate {
    let navigationController: UINavigationController
    
    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    public func onAuthorizationSuccess(accessToken: AccessToken?,
                                       identityToken: IdentityToken?,
                                       refreshToken: RefreshToken?,
                                       response:Response?) {
        guard accessToken != nil || identityToken != nil else {
            return
        }
        let afterLoginView  = (UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "AfterLoginView") as? OfficeSelectViewController)!
        
        afterLoginView.accessToken = accessToken
        afterLoginView.idToken = identityToken
        
        if accessToken!.isAnonymous {
            TokenStorageManager.sharedInstance.storeToken(token: accessToken!.raw)
        } else {
            TokenStorageManager.sharedInstance.clearStoredTokens()
        }
        
        if (refreshToken != nil) {
            TokenStorageManager.sharedInstance.storeRefreshToken(token: refreshToken!.raw)
        }
        TokenStorageManager.sharedInstance.storeUserId(userId: accessToken!.subject)
        
        
        DispatchQueue.main.async {
            
            self.navigationController.pushViewController(afterLoginView, animated: false)
        }
    }
    
    public func onAuthorizationCanceled() {
        print("cancel")
    }
    
    public func onAuthorizationFailure(error: AuthorizationError) {
        print("Authorization failure: "+error.localizedDescription)
        SigninDelegate.navigateToLandingView(navigationController: self.navigationController)
    }

    static func navigateToLandingView(navigationController: UINavigationController?) {
        let viewCtrl  = (UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "LandingViewController") as? ViewController)!
        navigationController?.pushViewController(viewCtrl, animated: false)
    }
}
