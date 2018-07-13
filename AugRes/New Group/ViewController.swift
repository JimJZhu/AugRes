/* *     Copyright 2016, 2017 IBM Corp.
 *     Licensed under the Apache License, Version 2.0 (the "License");
 *     you may not use this file except in compliance with the License.
 *     You may obtain a copy of the License at
 *     http://www.apache.org/licenses/LICENSE-2.0
 *     Unless required by applicable law or agreed to in writing, software
 *     distributed under the License is distributed on an "AS IS" BASIS,
 *     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *     See the License for the specific language governing permissions and
 *     limitations under the License.
 */

import UIKit
import BluemixAppID
import BMSCore

class ViewController: UIViewController {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var hint: UILabel!
    
    @IBAction func log_in_anonymously(_ sender: Any) {
        let token = TokenStorageManager.sharedInstance.loadStoredToken()
        AppID.sharedInstance.signinAnonymously(accessTokenString: token, authorizationDelegate: SigninDelegate(navigationController: self.navigationController!))
        
    }
    
    @IBAction func log_in(_ sender: AnyObject) {
        let token = TokenStorageManager.sharedInstance.loadStoredToken()
        AppID.sharedInstance.loginWidget?.launch(accessTokenString: token, delegate: SigninDelegate(navigationController: self.navigationController!))
    }
}

